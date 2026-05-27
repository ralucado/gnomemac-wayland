#!/usr/bin/env bash
# dash-to-dock-reload.sh
#
# Idempotent workaround for the Dash-to-Dock cold-start render bug on
# Ubuntu 22.04 + GNOME Shell 42 (X11) where the upstream Dash to Dock
# extension (~/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com)
# collides at startup with the system Ubuntu Dock extension
# (/usr/share/gnome-shell/extensions/ubuntu-dock@ubuntu.com), leaving only the
# show-applications icon visible.
#
# On session start, after gnome-shell has settled, we disable Dash to Dock then
# re-enable it. Re-enabling re-runs Dash to Dock's enable() with a clean shell
# state, restoring favorites and running-app icons.
#
# Safe to run on an already-working dock: a disable/enable cycle of a healthy
# dock produces the same healthy dock. The script bails out cleanly if the
# extension isn't installed or gnome-extensions is unavailable.
#
# Installed by dash-to-dock-reload.desktop under ~/.config/autostart/.

set -u

EXT_UUID="dash-to-dock@micxgx.gmail.com"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dash-to-dock-reload"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/reload.log"

log() {
    printf '%s %s\n' "$(date -Iseconds)" "$*" >> "$LOG_FILE"
}

# Keep only the last ~200 lines of log so this stays self-trimming.
if [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)" -gt 400 ]; then
    tail -n 200 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi

log "starting dash-to-dock-reload (pid=$$)"

if ! command -v gnome-extensions >/dev/null 2>&1; then
    log "gnome-extensions not on PATH; nothing to do"
    exit 0
fi

# Only run inside a real GNOME session.
if [ "${XDG_CURRENT_DESKTOP:-}" != *GNOME* ] && [ "${DESKTOP_SESSION:-}" != *gnome* ] \
   && [ "${XDG_CURRENT_DESKTOP:-}" != *ubuntu* ] && [ "${DESKTOP_SESSION:-}" != *ubuntu* ]; then
    # Loose check; if no env vars match, still proceed because the desktop file
    # is OnlyShowIn=GNOME so we got launched on purpose.
    :
fi

# If gnome-extensions can't see the UUID at all, bail.
if ! gnome-extensions info "$EXT_UUID" >/dev/null 2>&1; then
    log "extension $EXT_UUID not found; nothing to do"
    exit 0
fi

# Give gnome-shell time to settle after login. The cold-start render bug
# happens during the initial enable() pass, so we want shell to be fully up
# before we toggle.
sleep 5

state="$(gnome-extensions info "$EXT_UUID" 2>/dev/null | awk -F': *' '/^[[:space:]]*State/ {print $2; exit}')"
log "initial state: ${state:-unknown}"

# Always do a disable -> enable cycle, even if reported as ENABLED, because the
# bug presents as "enabled but not rendered". Re-enabling is the cure and is
# harmless when the dock is already healthy.
if ! gnome-extensions disable "$EXT_UUID" 2>>"$LOG_FILE"; then
    log "disable returned non-zero (continuing)"
fi
sleep 2
if ! gnome-extensions enable "$EXT_UUID" 2>>"$LOG_FILE"; then
    log "enable failed"
    exit 1
fi

final_state="$(gnome-extensions info "$EXT_UUID" 2>/dev/null | awk -F': *' '/^[[:space:]]*State/ {print $2; exit}')"
log "final state: ${final_state:-unknown}"
log "done"
