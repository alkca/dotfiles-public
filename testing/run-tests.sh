#!/bin/bash

# Wrapper script to run chezmoi tests on both Ubuntu and Arch Linux containers
# This script builds the Docker images and runs the tests

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_TYPE="${INSTALL_TYPE:-lite}"
TEST_TIMEOUT="${TEST_TIMEOUT:-300}"
CLEANUP="${CLEANUP:-true}"
PARALLEL="${PARALLEL:-false}"
DOTFILES_REPO="${DOTFILES_REPO:-$DOTFILES_DIR}"

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

log_header() {
    echo -e "${CYAN}=================================="
    echo -e "$1"
    echo -e "==================================${NC}"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Run chezmoi dotfiles tests on Ubuntu and Arch Linux containers.

OPTIONS:
    -t, --install-type TYPE    Install type to test (lite, full, gui) [default: lite]
    -r, --repo SOURCE         Local directory or public HTTPS URL [default: repository root]
        --timeout SECONDS     Per-container chezmoi timeout [default: 300]
    -p, --parallel            Run tests in parallel
    -n, --no-cleanup          Don't remove containers after testing
    -h, --help                Show this help message

ENVIRONMENT VARIABLES:
    INSTALL_TYPE              Install type to test (lite, full, gui)
    DOTFILES_REPO             Local directory or public HTTPS URL
    TEST_TIMEOUT              Per-container chezmoi timeout in seconds
    CLEANUP                   Whether to cleanup containers (true/false)
    PARALLEL                  Whether to run tests in parallel (true/false)

EXAMPLES:
    $0                        # Run tests with default settings
    $0 -t full               # Test full installation
    $0 -p                    # Run tests in parallel
    $0 -r /local/path        # Test with local dotfiles directory
    $0 -r https://github.com/user/dotfiles.git

Private repositories must be cloned securely on the host first and supplied as
a local directory. Credentials in URLs, command-line arguments, and environment
variables are intentionally unsupported.

EOF
}

# Function to parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--install-type)
                INSTALL_TYPE="$2"
                shift 2
                ;;
            -r|--repo)
                DOTFILES_REPO="$2"
                shift 2
                ;;
            --timeout)
                TEST_TIMEOUT="$2"
                shift 2
                ;;
            -p|--parallel)
                PARALLEL="true"
                shift
                ;;
            -n|--no-cleanup)
                CLEANUP="false"
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Function to validate non-secret test inputs
validate_inputs() {
    case "$INSTALL_TYPE" in
        lite|full|gui) ;;
        *)
            log_error "Invalid install type: $INSTALL_TYPE"
            exit 1
            ;;
    esac

    if [[ ! "$TEST_TIMEOUT" =~ ^[1-9][0-9]*$ ]]; then
        log_error "Timeout must be a positive integer: $TEST_TIMEOUT"
        exit 1
    fi

    case "$DOTFILES_REPO" in
        https://*)
            local authority="${DOTFILES_REPO#*://}"
            authority="${authority%%/*}"
            if [[ "$authority" == *"@"* ]]; then
                log_error "Repository URLs containing credentials or user info are not supported"
                exit 1
            fi
            if [[ "$DOTFILES_REPO" == *"?"* || "$DOTFILES_REPO" == *"#"* ]]; then
                log_error "Repository URLs containing query strings or fragments are not supported"
                exit 1
            fi
            ;;
        *)
            if [[ ! -d "$DOTFILES_REPO" ]]; then
                log_error "Local dotfiles directory not found: $DOTFILES_REPO"
                exit 1
            fi
            DOTFILES_REPO="$(cd "$DOTFILES_REPO" && pwd)"
            ;;
    esac
}

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if Docker is installed and running
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi

    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running"
        exit 1
    fi

    # Check if dotfiles directory exists
    if [[ ! -d "$DOTFILES_DIR" ]]; then
        log_error "Dotfiles directory not found: $DOTFILES_DIR"
        exit 1
    fi

    # Check if required files exist
    local required_files=(
        "$SCRIPT_DIR/test-chezmoi.sh"
        "$SCRIPT_DIR/ubuntu/Dockerfile"
        "$SCRIPT_DIR/arch/Dockerfile"
    )

    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Required file not found: $file"
            exit 1
        fi
    done

    log_success "All prerequisites met"
}

# Function to build Docker image
build_image() {
    local os="$1"
    local image_name="chezmoi-test-$os"

    log_info "Building Docker image for $os..."

    # Use testing/ as a minimal, allowlisted build context. No credentials or
    # host key material are copied into the image.
    if docker build \
        -f "$SCRIPT_DIR/$os/Dockerfile" \
        -t "$image_name" \
        "$SCRIPT_DIR" >/dev/null 2>&1; then
        log_success "Built Docker image: $image_name"
        return 0
    else
        log_error "Failed to build Docker image for $os"
        return 1
    fi
}

# Function to run test on a specific OS
run_test() {
    local os="$1"
    local image_name="chezmoi-test-$os"
    local container_name="chezmoi-test-$os-$(date +%s)"

    log_header "TESTING ON $os"

    # Run the container with appropriate configuration
    log_info "Starting container: $container_name"

    local container_repo="$DOTFILES_REPO"
    local docker_cmd=(
        docker run
        --name "$container_name"
    )

    if [[ "$CLEANUP" == "true" ]]; then
        docker_cmd+=(--rm)
    fi

    # Mount local dotfiles directory if using local path
    if [[ ! "$DOTFILES_REPO" =~ ^https?:// ]]; then
        docker_cmd+=(--mount "type=bind,src=$DOTFILES_REPO,dst=/dotfiles,readonly")
        container_repo="/dotfiles"
    fi

    docker_cmd+=(
        -e "DOTFILES_REPO=$container_repo"
        -e "INSTALL_TYPE=$INSTALL_TYPE"
        -e "TEST_TIMEOUT=$TEST_TIMEOUT"
    )
    docker_cmd+=("$image_name")

    local exit_code=0
    if "${docker_cmd[@]}"; then
        log_success "Test completed successfully on $os"
    else
        exit_code=$?
        log_error "Test failed on $os (exit code: $exit_code)"
    fi

    return $exit_code
}

# Function to run tests in parallel
run_tests_parallel() {
    log_info "Running tests in parallel..."

    local pids=()
    local results=()
    local result_dir
    result_dir="$(mktemp -d "${TMPDIR:-/tmp}/chezmoi-tests.XXXXXX")"

    # Start tests in background
    for os in ubuntu arch; do
        (
            local exit_code=0
            run_test "$os" || exit_code=$?
            echo "$exit_code" > "$result_dir/$os.result"
        ) &
        pids+=($!)
    done

    # Wait for all tests to complete
    for pid in "${pids[@]}"; do
        wait "$pid" || true
    done

    # Collect results
    local overall_exit_code=0
    for os in ubuntu arch; do
        local result_file="$result_dir/$os.result"
        if [[ -f "$result_file" ]]; then
            local exit_code=$(cat "$result_file")
            results+=("$os:$exit_code")
            if [[ $exit_code -ne 0 ]]; then
                overall_exit_code=1
            fi
            rm -f "$result_file"
        else
            results+=("$os:unknown")
            overall_exit_code=1
        fi
    done
    rmdir "$result_dir"

    # Report results
    log_header "PARALLEL TEST RESULTS"
    for result in "${results[@]}"; do
        local os="${result%:*}"
        local code="${result#*:}"
        if [[ "$code" == "0" ]]; then
            log_success "$os: PASSED"
        else
            log_error "$os: FAILED (exit code: $code)"
        fi
    done

    return $overall_exit_code
}

# Function to run tests sequentially
run_tests_sequential() {
    log_info "Running tests sequentially..."

    local overall_exit_code=0

    for os in ubuntu arch; do
        if ! run_test "$os"; then
            overall_exit_code=1
        fi
        echo ""  # Add spacing between tests
    done

    return $overall_exit_code
}

# Function to cleanup Docker images
cleanup_images() {
    if [[ "$CLEANUP" == "true" ]]; then
        log_info "Cleaning up Docker images..."

        for os in ubuntu arch; do
            local image_name="chezmoi-test-$os"
            if docker image inspect "$image_name" >/dev/null 2>&1; then
                docker rmi "$image_name" >/dev/null 2>&1 || true
                log_info "Removed image: $image_name"
            fi
        done
    fi
}

# Main function
main() {
    log_header "CHEZMOI DOTFILES TESTING"
    log_info "Install type: $INSTALL_TYPE"
    log_info "Dotfiles repository: $DOTFILES_REPO"
    log_info "Test timeout: ${TEST_TIMEOUT}s"
    log_info "Parallel execution: $PARALLEL"
    log_info "Cleanup after tests: $CLEANUP"
    echo ""

    # Check prerequisites
    check_prerequisites

    # Build Docker images
    local build_failed=false
    for os in ubuntu arch; do
        if ! build_image "$os"; then
            build_failed=true
        fi
    done

    if [[ "$build_failed" == "true" ]]; then
        log_error "Failed to build one or more Docker images"
        exit 1
    fi

    # Run tests
    local test_exit_code=0
    if [[ "$PARALLEL" == "true" ]]; then
        run_tests_parallel || test_exit_code=$?
    else
        run_tests_sequential || test_exit_code=$?
    fi

    # Cleanup
    cleanup_images

    # Final report
    echo ""
    log_header "FINAL RESULTS"
    if [[ $test_exit_code -eq 0 ]]; then
        log_success "All tests passed successfully!"
    else
        log_error "Some tests failed. Check the output above for details."
    fi

    exit $test_exit_code
}

# Parse arguments and run main function
parse_args "$@"
validate_inputs
main
