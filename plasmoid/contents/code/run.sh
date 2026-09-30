#!/bin/sh
# Runs the bundled burnbar with Bun or Node.js. plasmashell's PATH rarely includes a runtime
# installed per user, so the usual per-user locations are tried as well.
here=$(dirname "$0")

# The widget's icon is looked up by name, so it has to sit in an icon theme folder.
# A package installed from the KDE Store has no install step to put it there,
# and an update may bring a new icon.
icons="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps"
if ! cmp -s "$here/../icon.svg" "$icons/burnbar.svg"; then
    mkdir -p "$icons" && cp "$here/../icon.svg" "$icons/burnbar.svg"
fi 2>/dev/null

for runtime in bun node "$HOME/.bun/bin/bun" "$HOME/.local/share/mise/shims/node" "$HOME/.volta/bin/node" "$HOME/.local/bin/node"; do
    if command -v "$runtime" >/dev/null 2>&1; then
        exec "$runtime" "$here/burnbar.mjs" "$@"
    fi
done
echo '{"ok":false,"error":"burnbar needs Bun or Node.js 20 or newer"}'
exit 1
