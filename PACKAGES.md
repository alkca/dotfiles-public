# Package Management

This dotfiles setup uses a declarative approach to package management with OS-specific package lists and automatic installation via `run_onchange` scripts.

## How It Works

The package management system follows the [chezmoi declarative package installation guide](https://www.chezmoi.io/user-guide/advanced/install-packages-declaratively/) and automatically installs packages when:

1. You first run `chezmoi apply`
2. You modify any of the OS-specific package files
3. The install script detects changes in package definitions

## Package Files

### OS-Specific Package Definitions

- [`packages_darwin.yaml`](packages_darwin.yaml) - macOS packages
- [`packages_ubuntu.yaml`](packages_ubuntu.yaml) - Ubuntu packages
- [`packages_pios.yaml`](packages_pios.yaml) - Raspberry Pi OS packages
- [`packages_arch.yaml`](packages_arch.yaml) - Arch Linux packages

### Package Categories

Each OS file contains packages split by:

- **Native packages**: Installed via the OS's native package manager (apt, pacman, etc.)
- **Homebrew packages**: Installed via Homebrew (primary development tools)

And by install type:

- **lite**: Essential command-line tools
- **full**: Additional development tools and utilities
- **gui**: GUI applications and desktop tools

## Package Structure

```yaml
# Native package manager (apt, pacman, etc.)
native:
  lite:
    - essential-package-1
    - essential-package-2
  full:
    - dev-tool-1
    - dev-tool-2
  gui:
    - gui-app-1

# Homebrew packages
homebrew:
  taps:
    - homebrew/core
    - custom/tap

  lite:
    - cross-platform-tool-1
    - cross-platform-tool-2
  full:
    - advanced-dev-tool-1
  gui:
    - cross-platform-gui-app
```

## Install Types

Configure your install type in [`.chezmoi.yaml.tmpl`](.chezmoi.yaml.tmpl):

- **lite**: Essential command-line tools only
- **full**: Lite + additional development tools
- **gui**: Full + GUI applications

## Installation Scripts

The package installation is handled by OS-specific scripts that automatically run only on the matching OS:

- [`scripts/run_onchange_install-packages-darwin.sh.tmpl`](scripts/run_onchange_install-packages-darwin.sh.tmpl) - macOS installation
- [`scripts/run_onchange_install-packages-ubuntu.sh.tmpl`](scripts/run_onchange_install-packages-ubuntu.sh.tmpl) - Ubuntu installation
- [`scripts/run_onchange_install-packages-pios.sh.tmpl`](scripts/run_onchange_install-packages-pios.sh.tmpl) - Raspberry Pi OS installation
- [`scripts/run_onchange_install-packages-arch.sh.tmpl`](scripts/run_onchange_install-packages-arch.sh.tmpl) - Arch Linux installation

Each script:

1. Uses chezmoi OS detection (`.chezmoi.os` and `.chezmoi.osRelease.id`) to run only on the correct OS
2. Installs native packages first using the OS package manager (apt, pacman, or Xcode tools)
3. Ensures Homebrew is installed
4. Installs Homebrew packages based on your install type
5. Performs post-installation setup (Docker groups, zinit, etc.)

## Adding New Packages

To add packages:

1. Edit the appropriate OS-specific YAML file
2. Add the package to the correct section (native vs homebrew) and category (lite/full/gui)
3. Run `chezmoi apply` - the script will automatically detect changes and install new packages

## Example: Adding a Package

To add `htop` for Ubuntu systems:

```yaml
# In packages_ubuntu.yaml
native:
  lite:
    - htop  # Add here for native apt installation
```

Or to add a cross-platform development tool:

```yaml
# In packages_ubuntu.yaml (and other OS files)
homebrew:
  full:
    - new-dev-tool  # Add here for Homebrew installation
```

## Migration from run_once_after

This setup replaces the previous `run_once_after_*` scripts with:

- ✅ Automatic re-installation when package lists change
- ✅ Better separation between native and Homebrew packages
- ✅ OS-specific package definitions
- ✅ Cleaner, more maintainable configuration
- ✅ Following chezmoi best practices

## Troubleshooting

### Force Package Reinstallation

If you need to force a complete reinstallation:

```bash
# Remove the chezmoi state for the script
chezmoi state delete-bucket --bucket=scriptState

# Re-run chezmoi apply
chezmoi apply
```

### Check What Packages Will Be Installed

```bash
# View the package file for your OS
cat packages_$(uname -s | tr '[:upper:]' '[:lower:]').yaml

# Or check the generated script
chezmoi cat scripts/run_onchange_install-packages.sh.tmpl
```

### Package Installation Fails

The script continues on package failures and reports which packages failed at the end. You can:

1. Check the package name is correct in the YAML file
2. Manually install the failed package
3. Re-run `chezmoi apply`
