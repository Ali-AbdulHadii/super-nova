#!/usr/bin/env bash
# super-nova.sh -- build this fork and run it in place of the packaged shell.
#
#   scripts/super-nova.sh install     build, install into $HOME, restart the shell
#   scripts/super-nova.sh uninstall   remove it again; the caelestia-shell package takes over
#
# Everything lands under $HOME, so no sudo and no clash with the pacman
# package, which stays installed as the fallback:
#   ~/.config/quickshell/caelestia   QML (quickshell prefers it over /etc/xdg)
#   ~/.local/lib/qt6/qml/Caelestia   compiled QML plugin
#   ~/.local/lib/caelestia           helper binaries
# The plugin and helpers are only found through two env vars, which this
# script adds to ~/.config/caelestia/hypr-user.lua inside a marked block.
#
# The plugin links against the system Qt. After a Qt update from pacman,
# run `install` again, or the shell may refuse to load it.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$REPO/build/install"
QSCONF="$HOME/.config/quickshell/caelestia"
QMLDIR="$HOME/.local/lib/qt6/qml"
LIBDIR="$HOME/.local/lib/caelestia"
HYPR_USER="$HOME/.config/caelestia/hypr-user.lua"
BEGIN="-- >>> super-nova (managed by scripts/super-nova.sh)"
END="-- <<< super-nova"

log() { printf '\033[1;35m::\033[0m %s\n' "$*"; }

hypr() {
    HYPRLAND_INSTANCE_SIGNATURE="${HYPRLAND_INSTANCE_SIGNATURE:-$(ls -t "$XDG_RUNTIME_DIR/hypr/" | head -1)}" hyprctl "$@"
}

remove_env_block() {
    [ -f "$HYPR_USER" ] || return 0
    # awk, not sed: the markers contain "/" and would break a sed address.
    awk -v b="$BEGIN" -v e="$END" '$0 == b {skip = 1} !skip {print} $0 == e {skip = 0}' \
        "$HYPR_USER" > "$HYPR_USER.tmp" && mv "$HYPR_USER.tmp" "$HYPR_USER"
}

add_env_block() {
    remove_env_block
    cat >> "$HYPR_USER" <<EOF
$BEGIN
hl.env("QML2_IMPORT_PATH", os.getenv("HOME") .. "/.local/lib/qt6/qml")
hl.env("CAELESTIA_LIB_DIR", os.getenv("HOME") .. "/.local/lib/caelestia")
$END
EOF
}

# Restart through Hyprland so the shell inherits the env set by hl.env().
restart_shell() {
    hypr reload >/dev/null
    caelestia shell -k >/dev/null 2>&1 || true
    timeout 10 sh -c 'while pgrep -x qs >/dev/null; do sleep 0.3; done' || pkill -9 -x qs || true
    hypr eval 'hl.dispatch(hl.dsp.exec_cmd("caelestia shell -d"))' >/dev/null
    if timeout 20 sh -c 'until qs -c caelestia ipc show >/dev/null 2>&1; do sleep 0.5; done'; then
        log "shell is up"
    else
        log "shell did not answer within 20s -- check: caelestia shell -l"
        return 1
    fi
}

install() {
    command -v ninja >/dev/null || { log "ninja is missing: sudo pacman -S ninja"; exit 1; }

    log "configuring"
    cmake -S "$REPO" -B "$BUILD" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$HOME/.local" \
        -DINSTALL_QSCONFDIR="$QSCONF" \
        -DINSTALL_QMLDIR="$QMLDIR" \
        -DINSTALL_LIBDIR="$LIBDIR" \
        -DDISTRIBUTOR="super-nova" >/dev/null

    log "building"
    cmake --build "$BUILD"

    # cmake --install never deletes, so clear old copies first or files
    # removed from the repo would linger and still be loaded.
    log "installing"
    rm -rf "$QSCONF" "$QMLDIR/Caelestia" "$LIBDIR"
    cmake --install "$BUILD" >/dev/null

    add_env_block
    restart_shell
}

uninstall() {
    log "removing super-nova; the caelestia-shell package takes over"
    rm -rf "$QSCONF" "$QMLDIR/Caelestia" "$LIBDIR"
    remove_env_block
    # Deleting the lines does not unset what the running Hyprland already
    # exported; point both back at the package until the next login.
    hypr eval 'hl.env("QML2_IMPORT_PATH", "")' >/dev/null
    hypr eval 'hl.env("CAELESTIA_LIB_DIR", "/usr/lib/caelestia")' >/dev/null
    restart_shell
}

case "${1:-}" in
    install) install ;;
    uninstall) uninstall ;;
    *) echo "usage: $0 install|uninstall" >&2; exit 2 ;;
esac
