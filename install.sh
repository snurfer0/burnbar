#!/bin/sh
# Builds burnbar, installs the panel widget for this user and links the `burnbar` command.
# A running plasmashell keeps the old version of an already-loaded widget until it restarts.
set -e
cd "$(dirname "$0")"
command -v bun >/dev/null || { echo "bun is needed to build: https://bun.sh" >&2; exit 1; }

bun install --frozen-lockfile
bun run build

kpackagetool6 -t Plasma/Applet -u plasmoid >/dev/null 2>&1 || kpackagetool6 -t Plasma/Applet -i plasmoid

mkdir -p "$HOME/.local/bin"
printf '#!/bin/sh\nexec sh "%s/plasma/plasmoids/io.github.snurfer0.burnbar/contents/code/run.sh" "$@"\n' \
    "${XDG_DATA_HOME:-$HOME/.local/share}" > "$HOME/.local/bin/burnbar"
chmod +x "$HOME/.local/bin/burnbar"
echo "Installed. Add the Burnbar widget to a panel."
