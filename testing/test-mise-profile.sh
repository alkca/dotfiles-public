#!/usr/bin/env bash
# Focused smoke test for the shared mise shell setup and package profiles.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

mkdir -p "$scratch/home/.config/zsh" "$scratch/home/.local/share/zinit/zinit.git" "$scratch/home/.local/share/fnm" "$scratch/home/.nvm" "$scratch/home/.cache" "$scratch/bin"
cp "$root/private_dot_config/private_zsh/dot_zshrc" "$scratch/home/.config/zsh/.zshrc"
sed 's#/home/[[:alnum:]_-]*#$HOME#g' "$root/dot_bashrc" > "$scratch/home/.bashrc"
printf 'zinit() { :; }\n' > "$scratch/home/.local/share/zinit/zinit.git/zinit.zsh"
printf '%s\n' "$(date +%s)" > "$scratch/home/.cache/chezmoi_last_check"
cat > "$scratch/bin/mise" <<'MISE'
#!/usr/bin/env sh
if [ "$1" = activate ] && { [ "$2" = zsh ] || [ "$2" = bash ]; }; then
    printf 'export MISE_TEST_ACTIVATED=1\n'
    exit 0
fi
if [ "$1" = install ]; then
    printf '%s|%s\n' "$PWD" "$*" > "$MISE_TEST_INSTALL_LOG"
    exit 0
fi
exit 1
MISE
chmod +x "$scratch/bin/mise"
cat > "$scratch/home/.local/share/fnm/fnm" <<'FNM'
#!/usr/bin/env sh
printf 'called\n' > "$FNM_TEST_MARKER"
FNM
chmod +x "$scratch/home/.local/share/fnm/fnm"
cat > "$scratch/home/.nvm/nvm.sh" <<'NVM'
printf 'called\n' > "$NVM_TEST_MARKER"
NVM

if ! HOME="$scratch/home" USER=mise-test LOGNAME=mise-test \
    XDG_CONFIG_HOME="$scratch/home/.config" \
    XDG_DATA_HOME="$scratch/home/.local/share" \
    XDG_CACHE_HOME="$scratch/home/.cache" \
    ZDOTDIR="$scratch/home/.config/zsh" \
    FNM_TEST_MARKER="$scratch/fnm-called" \
    PATH="$scratch/bin:/usr/bin:/bin" \
    /usr/bin/zsh -ic '[[ "${MISE_TEST_ACTIVATED:-}" == 1 ]]' \
    >"$scratch/zsh.log" 2>&1; then
    cat "$scratch/zsh.log" >&2
    printf 'mise did not activate in an interactive zsh session\n' >&2
    exit 1
fi

if ! HOME="$scratch/home" USER=mise-test LOGNAME=mise-test \
    NVM_TEST_MARKER="$scratch/nvm-called" \
    PATH="$scratch/bin:/usr/bin:/bin" \
    /usr/bin/bash --noprofile --rcfile "$scratch/home/.bashrc" -ic \
    '[[ "${MISE_TEST_ACTIVATED:-}" == 1 ]]' >"$scratch/bash.log" 2>&1; then
    cat "$scratch/bash.log" >&2
    printf 'mise did not activate in an interactive bash session\n' >&2
    exit 1
fi

if [[ -e "$scratch/nvm-called" ]]; then
    printf 'nvm was still activated by bash\n' >&2
    exit 1
fi

if [[ -e "$scratch/fnm-called" ]]; then
    printf 'fnm was still activated by zsh\n' >&2
    exit 1
fi

if rg -q 'tfenv' "$root/private_dot_config/private_zsh/dot_zshenv" ||
    [[ -e "$root/private_dot_config/tfenv/version" ]]; then
    printf 'tfenv is still configured in the shared profile\n' >&2
    exit 1
fi

python3 - "$root/private_dot_config/mise/config.toml" <<'TOML'
import sys
import tomllib
from pathlib import Path

tools = tomllib.loads(Path(sys.argv[1]).read_text()).get("tools", {})
assert tools.get("node"), "missing global Node.js version"
assert tools.get("terraform"), "missing global Terraform version"
TOML

HOME="$scratch/home" chezmoi --source "$root" --destination "$scratch/home" \
    --config "$scratch/chezmoi.toml" init --promptDefaults
HOME="$scratch/home" chezmoi --source "$root" --destination "$scratch/home" \
    --config "$scratch/chezmoi.toml" execute-template -f \
    scripts/run_onchange_after_install-mise-tools.sh.tmpl > "$scratch/install-mise.sh"
HOME="$scratch/home" PATH="$scratch/bin:/usr/bin:/bin" \
    MISE_TEST_INSTALL_LOG="$scratch/mise-install.log" \
    bash "$scratch/install-mise.sh"
if [[ "$(cat "$scratch/mise-install.log")" != "$scratch/home|install node terraform" ]]; then
    printf 'mise post-install script did not install global Node and Terraform\n' >&2
    exit 1
fi

for platform in darwin debian arch pios; do
    if ! yq -e '.homebrew.lite[] | select(. == "mise")' \
        "$root/packages_${platform}.yaml" >/dev/null; then
        printf 'mise is missing from the %s lite package profile\n' "$platform" >&2
        exit 1
    fi
done

printf 'mise is available and activated in the shared lite profile\n'
