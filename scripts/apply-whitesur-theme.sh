#!/usr/bin/env bash
# Build and apply a WhiteSur GTK + Shell theme variant.
# Pick the accent color below, then run this script.
set -euo pipefail

# === CHOOSE COLOR HERE ===
# Options: default (Big Sur blue), blue, purple, pink, red, orange, yellow, green, grey, all
ACCENT="purple"
# Color scheme: dark or light
SCHEME="dark"
# =========================

REPO_DIR="/tmp/WhiteSur-gtk-theme"
USER_THEME_SCHEMA="$HOME/.local/share/gnome-shell/extensions/user-theme@gnome-shell-extensions.gcampax.github.com/schemas"

if [ ! -d "$REPO_DIR" ]; then
  git clone --depth=1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git "$REPO_DIR"
fi

cd "$REPO_DIR"
# The WhiteSur installer always tries to apt-install build deps, even when
# already present. If sassc + xmllint + glib-compile-resources are already
# on PATH, neuter the install_theme_deps function so it doesn't fail on a
# system where apt is broken or sudo is unavailable.
if command -v sassc >/dev/null && command -v xmllint >/dev/null && command -v glib-compile-resources >/dev/null; then
  sed -i 's/^install_theme_deps()[[:space:]]*{/install_theme_deps() { return 0;/' libs/lib-install.sh
fi

./install.sh -c "$SCHEME" -t "$ACCENT"

# Theme directories generated for the chosen accent
if [ "$ACCENT" = "default" ]; then
  GTK_NAME="WhiteSur-${SCHEME^}"
else
  GTK_NAME="WhiteSur-${SCHEME^}-${ACCENT}"
fi

# capitalize for "Dark" / "Light"
SCHEME_CAP="$(tr '[:lower:]' '[:upper:]' <<<"${SCHEME:0:1}")${SCHEME:1}"
GTK_NAME="WhiteSur-${SCHEME_CAP}"
[ "$ACCENT" != "default" ] && GTK_NAME="${GTK_NAME}-${ACCENT}"

[ "$SCHEME" = "dark" ] \
  && gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' \
  || gsettings set org.gnome.desktop.interface color-scheme 'default'

gsettings set org.gnome.desktop.interface gtk-theme "$GTK_NAME"
GSETTINGS_SCHEMA_DIR="$USER_THEME_SCHEMA" \
  gsettings set org.gnome.shell.extensions.user-theme name "$GTK_NAME"

echo "Applied $GTK_NAME. If the shell didn't switch, press Alt+F2 then r then Enter (X11) to reload."
