#!/bin/bash

# Test script for chezmoi dotfiles initialization
# This script tests the chezmoi setup process in a clean environment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Test configuration
DOTFILES_REPO="${DOTFILES_REPO:-/dotfiles}"
INSTALL_TYPE="${INSTALL_TYPE:-lite}"
TEST_TIMEOUT="${TEST_TIMEOUT:-300}"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

# Function to test chezmoi installation
test_chezmoi_installation() {
    log_info "Testing chezmoi installation..."

    if command_exists chezmoi; then
        local version=$(chezmoi --version)
        log_success "chezmoi is installed: $version"
        return 0
    else
        log_error "chezmoi is not installed or not in PATH"
        return 1
    fi
}

# Function to test OS detection
test_os_detection() {
    log_info "Testing OS detection..."

    local detected_os=$(detect_os)
    log_info "Detected OS: $detected_os"

    case "$detected_os" in
        ubuntu|arch)
            log_success "OS detection successful: $detected_os"
            return 0
            ;;
        *)
            log_warning "Unexpected OS detected: $detected_os"
            return 1
            ;;
    esac
}

# Function to initialize chezmoi with dotfiles
test_chezmoi_init() {
    log_info "Testing chezmoi initialization..."

    case "$DOTFILES_REPO" in
        https://*)
            local authority="${DOTFILES_REPO#*://}"
            authority="${authority%%/*}"
            if [[ "$authority" == *"@"* ]]; then
                log_error "Repository URLs containing credentials or user info are not supported"
                return 1
            fi
            if [[ "$DOTFILES_REPO" == *"?"* || "$DOTFILES_REPO" == *"#"* ]]; then
                log_error "Repository URLs containing query strings or fragments are not supported"
                return 1
            fi
            ;;
        *)
            if [[ ! -d "$DOTFILES_REPO" ]]; then
                log_error "Dotfiles repository not found at $DOTFILES_REPO"
                return 1
            fi

            # The host checkout is mounted read-only and may have a different
            # numeric owner inside the container. Trust only this explicitly
            # supplied test source so Git can clone it without weakening the
            # container's global ownership checks for other repositories.
            git config --global --add safe.directory "$DOTFILES_REPO"
            if [[ -d "$DOTFILES_REPO/.git" ]]; then
                git config --global --add safe.directory "$DOTFILES_REPO/.git"
            fi
            ;;
    esac

    log_info "Initializing chezmoi from the configured source"

    # Pass the install choice over stdin without constructing an intermediate
    # shell command. Repository sources must never contain credentials.
    if ! printf '%s\n' "$INSTALL_TYPE" |
        timeout "$TEST_TIMEOUT" chezmoi init --apply "$DOTFILES_REPO"; then
        log_error "chezmoi init timed out or failed"
        return 1
    fi

    # Check if chezmoi source directory was created
    if [[ -d ~/.local/share/chezmoi ]]; then
        log_success "chezmoi source directory created"
    else
        log_error "chezmoi source directory not found"
        return 1
    fi

    return 0
}

# Function to test configuration files
test_config_files() {
    log_info "Testing configuration file creation..."

    local config_files=(
        "~/.config/chezmoi/chezmoi.toml"
        "~/.bashrc"
    )

    local success_count=0
    local total_count=${#config_files[@]}

    for config_file in "${config_files[@]}"; do
        # Expand tilde
        local expanded_file="${config_file/#\~/$HOME}"

        if [[ -f "$expanded_file" ]]; then
            log_success "Configuration file exists: $config_file"
            ((success_count += 1))
        else
            log_warning "Configuration file missing: $config_file"
        fi
    done

    log_info "Configuration files: $success_count/$total_count created"

    # Return success if at least some files were created
    [[ $success_count -gt 0 ]]
}

# Function to test chezmoi commands
test_chezmoi_commands() {
    log_info "Testing basic chezmoi commands..."

    # Test chezmoi status
    if chezmoi status >/dev/null 2>&1; then
        log_success "chezmoi status command works"
    else
        log_warning "chezmoi status command failed"
    fi

    # Test chezmoi diff
    if chezmoi diff >/dev/null 2>&1; then
        log_success "chezmoi diff command works"
    else
        log_warning "chezmoi diff command failed"
    fi

    # Test chezmoi managed
    local managed_files=$(chezmoi managed 2>/dev/null | wc -l)
    if [[ $managed_files -gt 0 ]]; then
        log_success "chezmoi is managing $managed_files files"
    else
        log_warning "chezmoi is not managing any files"
    fi
}

# Function to test package installation
test_package_installation() {
    log_info "Testing package installation..."

    local detected_os=$(detect_os)
    local package_manager=""

    case "$detected_os" in
        ubuntu)
            package_manager="apt"
            ;;
        arch)
            package_manager="pacman"
            ;;
        *)
            log_warning "Unknown OS, skipping package installation test"
            return 0
            ;;
    esac

    log_info "Expected package manager: $package_manager"

    # Check if Homebrew was installed (this might take time)
    if command_exists brew; then
        log_success "Homebrew is installed"

        # Test a few expected packages from lite install
        local expected_packages=("git" "curl" "neovim")
        local installed_count=0

        for package in "${expected_packages[@]}"; do
            if command_exists "$package"; then
                log_success "Package available: $package"
                ((installed_count += 1))
            else
                log_warning "Package not available: $package"
            fi
        done

        log_info "Available packages: $installed_count/${#expected_packages[@]}"
    else
        log_warning "Homebrew not installed (this is expected for quick tests)"
    fi
}

# Function to generate test report
generate_report() {
    log_info "Generating test report..."

    echo "=================================="
    echo "CHEZMOI TEST REPORT"
    echo "=================================="
    echo "Date: $(date)"
    echo "OS: $(detect_os)"
    echo "Architecture: $(uname -m)"
    echo "Install Type: $INSTALL_TYPE"
    echo "Dotfiles Repo: $DOTFILES_REPO"
    echo "=================================="

    # System information
    echo "System Information:"
    echo "- Kernel: $(uname -r)"
    echo "- Shell: $SHELL"
    echo "- User: $(whoami)"
    echo "- Home: $HOME"
    echo ""

    # chezmoi information
    if command_exists chezmoi; then
        echo "chezmoi Information:"
        echo "- Version: $(chezmoi --version)"
        echo "- Source Path: $(chezmoi source-path 2>/dev/null || echo 'Not initialized')"
        echo "- Managed Files: $(chezmoi managed 2>/dev/null | wc -l)"
        echo ""
    fi

    # File system check
    echo "Key Directories:"
    echo "- ~/.local/share/chezmoi: $(test -d ~/.local/share/chezmoi && echo 'EXISTS' || echo 'MISSING')"
    echo "- ~/.config: $(test -d ~/.config && echo 'EXISTS' || echo 'MISSING')"
    echo "- ~/.config/chezmoi: $(test -d ~/.config/chezmoi && echo 'EXISTS' || echo 'MISSING')"
    echo ""

    echo "=================================="
}

# Main test execution
main() {
    log_info "Starting chezmoi dotfiles test..."
    log_info "Test environment: $(detect_os) on $(uname -m)"

    local exit_code=0

    # Run all tests
    test_chezmoi_installation || exit_code=1
    test_os_detection || exit_code=1
    test_chezmoi_init || exit_code=1
    test_config_files || exit_code=1
    test_chezmoi_commands || exit_code=1
    test_package_installation || exit_code=1

    # Generate final report
    generate_report

    if [[ $exit_code -eq 0 ]]; then
        log_success "All tests completed successfully!"
    else
        log_warning "Some tests failed or had warnings. Check the output above."
    fi

    exit $exit_code
}

# Run main function
main "$@"
