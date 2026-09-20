# dotfiles-public

Public [chezmoi](https://www.chezmoi.io/) profile for development machines and disposable VMs.

The default `lite` profile installs a zsh shell environment, Neovim, common CLI tools, `uv`, and `mise`. Mise manages the shared Node.js and Terraform versions in `~/.config/mise/config.toml`; a project's `mise.toml` can override them. Use `mise install` after changing a tool version. Use `uv` for Python project environments and dependencies.

The `full` profile adds terminal utilities, and `gui` adds desktop applications where supported. The profile contains no private credentials; supply repository access and other secrets per machine.
