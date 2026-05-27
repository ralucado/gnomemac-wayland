#!/usr/bin/env bash
# Restore the macOS-flavored GNOME 42 setup on a fresh Ubuntu 22.04 box.
# Read README.md first for the manual prerequisites (NVIDIA driver,
# GDM Wayland enable, Mozilla Firefox deb install, Apple font DMGs, GNOME
# extensions).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCHEMA_BASE="$HOME/.local/share/gnome-shell/extensions"

say() { printf '\n>>> %s\n' "$*"; }

# --- 0. Sanity checks -------------------------------------------------------

if [ "${XDG_SESSION_TYPE:-}" != "wayland" ]; then
  echo "WARNING: This backup is tuned for Wayland. Current session is"
  echo "         '$XDG_SESSION_TYPE'. Continue anyway? (y/N)"
  read -r answer
  [ "$answer" = "y" ] || exit 1
fi

# --- 1. apt deps ------------------------------------------------------------

say "Installing apt dependencies (Touchégg PPA + theme/font tooling)"
sudo add-apt-repository -y ppa:touchegg/stable
sudo apt update
sudo apt install -y \
  touchegg \
  sassc gnome-themes-extra gtk2-engines-murrine libxml2-utils libglib2.0-dev-bin \
  p7zip-full \
  chrome-gnome-shell

# --- 2. WhiteSur GTK + Shell themes ----------------------------------------

say "Copying WhiteSur themes → ~/.themes/"
mkdir -p "$HOME/.themes"
cp -a "$HERE/themes/dot-themes/." "$HOME/.themes/"

# --- 3. Apple SF / New York fonts ------------------------------------------

say "Installing Apple fonts (extracted from DMGs in ~/Downloads/)"
mkdir -p "$HOME/.local/share/fonts/apple"
for dmg in SF-Pro.dmg SF-Mono.dmg SF-Compact.dmg NY.dmg; do
  src="$HOME/Downloads/$dmg"
  if [ ! -f "$src" ]; then
    echo "  SKIP $dmg — not in ~/Downloads/. Get from https://developer.apple.com/fonts/"
    continue
  fi
  workdir=$(mktemp -d)
  7z x -y -o"$workdir" "$src" >/dev/null 2>&1 || { rm -rf "$workdir"; continue; }
  pkg=$(find "$workdir" -name '*.pkg' | head -1)
  [ -z "$pkg" ] && { rm -rf "$workdir"; continue; }
  pkgdir="$workdir/pkg"; mkdir -p "$pkgdir"
  7z x -y -o"$pkgdir" "$pkg" >/dev/null 2>&1
  for inner in $(find "$pkgdir" -name '*.pkg'); do
    7z x -y -o"$(dirname "$inner")/inner" "$inner" >/dev/null 2>&1 || true
  done
  for payload in $(find "$pkgdir" -name 'Payload' -o -name 'Payload~'); do
    pdir=$(dirname "$payload")/payload-extracted; mkdir -p "$pdir"
    (cd "$pdir" && gunzip -c "$payload" 2>/dev/null | cpio -idm 2>/dev/null) \
      || (cd "$pdir" && cpio -idm <"$payload" 2>/dev/null) || true
  done
  find "$workdir" -iname '*.otf' -exec cp -n {} "$HOME/.local/share/fonts/apple/" \;
  rm -rf "$workdir"
done
fc-cache -f "$HOME/.local/share/fonts/"

# --- 4. Config files --------------------------------------------------------

say "Installing config files"
mkdir -p "$HOME/.config/touchegg" "$HOME/.config/environment.d" "$HOME/.config/fontconfig/conf.d"
cp "$HERE/config/touchegg.conf"                       "$HOME/.config/touchegg/touchegg.conf"
cp "$HERE/config/environment-d_firefox.conf"          "$HOME/.config/environment.d/firefox.conf"
cp "$HERE/config/fontconfig_10-apple-system-fonts.conf" "$HOME/.config/fontconfig/conf.d/10-apple-system-fonts.conf"
fc-cache -f

# monitors.xml is hardware-specific; only copy if the user opts in
if [ ! -f "$HOME/.config/monitors.xml" ]; then
  echo "  Copying monitors.xml (4K @ 2x scale, eDP-1 disabled)."
  echo "  Delete this file later if your hardware differs."
  cp "$HERE/config/monitors.xml" "$HOME/.config/monitors.xml"
else
  echo "  Skipping monitors.xml — file already present at \$HOME/.config/."
fi

# --- 5. Helper scripts ------------------------------------------------------

say "Installing helper scripts → ~/.local/bin/"
mkdir -p "$HOME/.local/bin"
cp "$HERE/scripts/"*.sh "$HOME/.local/bin/"
chmod +x "$HOME/.local/bin/"*.sh

# --- 6. Firefox chrome + user.js -------------------------------------------

say "Installing Firefox WhiteSur chrome + user.js"
mkdir -p "$HOME/.mozilla/firefox/firefox-themes"
cp -a "$HERE/firefox/firefox-themes/." "$HOME/.mozilla/firefox/firefox-themes/"

# Locate any active Firefox profile and link chrome/ + drop user.js
PROFILE_DIR=$(grep -lE '^Path=' "$HOME/.mozilla/firefox/profiles.ini" 2>/dev/null | head -1 || true)
ACTIVE=$(grep -E 'Default=[^=]' "$HOME/.mozilla/firefox/profiles.ini" 2>/dev/null \
  | grep -v '^Default=1' | head -1 | cut -d= -f2 || true)
if [ -n "$ACTIVE" ] && [ -d "$HOME/.mozilla/firefox/$ACTIVE" ]; then
  echo "  Linking $HOME/.mozilla/firefox/$ACTIVE/chrome -> firefox-themes"
  rm -rf "$HOME/.mozilla/firefox/$ACTIVE/chrome"
  ln -s "$HOME/.mozilla/firefox/firefox-themes" "$HOME/.mozilla/firefox/$ACTIVE/chrome"
  echo "  Dropping user.js into $ACTIVE"
  cp "$HERE/firefox/user.js" "$HOME/.mozilla/firefox/$ACTIVE/user.js"
else
  echo "  No active Firefox profile found; launch Firefox once to create one,"
  echo "  then manually:"
  echo "    ln -s \$HOME/.mozilla/firefox/firefox-themes \$HOME/.mozilla/firefox/<profile>/chrome"
  echo "    cp $HERE/firefox/user.js \$HOME/.mozilla/firefox/<profile>/user.js"
fi

# --- 7. dconf — the big one ------------------------------------------------

say "Loading dconf settings (themes, extensions, fonts, behavior)"
dconf load /org/gnome/ < "$HERE/dconf/org-gnome.ini"

# --- 8. Done ----------------------------------------------------------------

cat <<TXT

==============================================================================
Automatable bits done. Remaining manual steps:

1. Install GNOME extensions via the browser (from README.md §5). The dconf
   load already enabled them in shell state — extensions just need to be
   installed once and they will activate automatically.

2. Log out and log back into the Wayland session ("Ubuntu" in GDM, NOT
   "Ubuntu on Xorg"). The Mutter experimental flags
   (scale-monitor-framebuffer, xwayland-native-scaling) only take effect on
   a fresh shell.

3. Start the Touchégg user client now (or it auto-starts at next login):
     /usr/bin/touchegg --client &

4. Open Firefox once. It will pick up the chrome customizations and the
   prefs in user.js. The WhiteSur traffic-light buttons and rounded tabs
   appear after the first restart.

5. If anything looks blurry on the 4K display, verify Mutter's experimental
   features are present (the dconf load should have set them):
     gsettings get org.gnome.mutter experimental-features
   Expected: ['scale-monitor-framebuffer', 'xwayland-native-scaling']

TXT
