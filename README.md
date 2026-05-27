# macOS-flavored GNOME 42 / Wayland backup

A self-contained backup of a macOS-styled Ubuntu 22.04 + GNOME Shell 42 setup
running on **Wayland with NVIDIA**: WhiteSur GTK + Shell theme, Apple SF fonts,
Touchégg trackpad gestures, 16 GNOME extensions (Dash to Dock, Blur My Shell,
Hide Top Bar, Just Perfection, Gesture Improvements, etc.), and Mozilla deb
Firefox with the WhiteSur Firefox chrome.

## What's inside

```
gnomemac-backup/
├── README.md                                    this file
├── restore.sh                                   automated replay
├── dconf/
│   ├── org-gnome.ini                            full dconf dump of /org/gnome/
│   ├── extensions-enabled.txt                   16 UUIDs to install in browser
│   └── extensions-installed.txt                 same plus disabled extras
├── config/
│   ├── touchegg.conf                            gesture mappings (~/.config/touchegg/)
│   ├── monitors.xml                             4K-only @ 2x scale, eDP-1 disabled
│   ├── environment-d_firefox.conf               MOZ_ENABLE_WAYLAND=1
│   └── fontconfig_10-apple-system-fonts.conf    map -apple-system / system-ui → SF Pro
├── themes/
│   └── dot-themes/                              compiled WhiteSur GTK + Shell themes
├── firefox/
│   ├── firefox-themes/                          WhiteSur Firefox chrome (userChrome.css)
│   ├── user.js                                  prefs to drop into the new profile
│   └── profile-dir-name.txt                     suggested profile dirname
└── scripts/
    ├── apply-whitesur-theme.sh                  rebuild WhiteSur with a chosen accent
    ├── disable-laptop-display.sh                clamshell: turn eDP-1 off when HDMI present
    └── dash-to-dock-reload.sh                   workaround for an X11 cold-start bug
                                                 (Wayland may not need this)
```

## Target system

- Ubuntu 22.04 LTS (Jammy)
- GNOME Shell 42.x
- **Wayland session** (we settled on Wayland after the X11 multi-monitor pain;
  X11 also works but isn't what this backup is tuned for)
- NVIDIA-only GPU (laptop with no Intel iGPU exposed) — driver 580.x

## Manual gotchas before restore.sh works

These steps need human attention because they involve installing third-party
packages, downloading from vendor sites, or rebooting. Do them in this order
**before** running `restore.sh`.

### 1. NVIDIA driver — verify matching kernel-module + userspace

After installing the OS, install the NVIDIA driver:

```sh
sudo ubuntu-drivers install
```

Then verify everything matches. Two pitfalls:

- **DKMS build fails with `unrecognized command-line option '-ftrivial-auto-var-init=zero'`**
  Linux 6.8+ kernels are compiled with GCC 12+ and the NVIDIA DKMS module
  inherits that flag. If `cc` is still GCC 11, the build fails silently and
  you end up with a kernel-module / userspace version mismatch (nvidia-smi
  prints `NVML library version mismatch`). Fix:
  ```sh
  sudo apt install -y gcc-12
  sudo update-alternatives --install /usr/bin/cc cc /usr/bin/gcc-12 60
  sudo update-alternatives --install /usr/bin/cc cc /usr/bin/gcc-11 50
  sudo update-alternatives --set cc /usr/bin/gcc-12
  sudo dpkg --configure -a
  ```

- **Wayland requires `nvidia-drm.modeset=1`.** Without it, gnome-shell on
  Wayland fails to initialize EGL on the NVIDIA card and the session loops
  back to GDM. Add to GRUB:
  ```sh
  sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia-drm.modeset=1"/' /etc/default/grub
  sudo update-grub
  sudo reboot
  ```
  After reboot, verify: `cat /sys/module/nvidia_drm/parameters/modeset` should print `Y`.

### 2. GDM — enable the Wayland session in the chooser

Ubuntu 22.04 ships with `WaylandEnable=false` in `/etc/gdm3/custom.conf`, which
*hides the cog/session-picker icon* at the login screen entirely. To make
Wayland selectable:

```sh
sudo sed -i 's/^WaylandEnable=false/#WaylandEnable=false/' /etc/gdm3/custom.conf
sudo systemctl restart gdm
```

After this, click your username at the greeter, then the gear icon next to
the password field, and pick "**Ubuntu**" (= Wayland; "Ubuntu on Xorg" is the
explicit X11 fallback). The plain "Ubuntu" entry IS Wayland once Wayland is
enabled — confusing naming.

### 3. Firefox — install Mozilla's deb, *not* the snap

The snap-confined Firefox has font-resolution issues (`font: caption` doesn't
go through system GTK) and other integration problems on NVIDIA + Wayland.
Switch to the official Mozilla deb:

```sh
sudo install -d -m 0755 /etc/apt/keyrings
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- \
  | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
  | sudo tee /etc/apt/sources.list.d/mozilla.list > /dev/null
printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' \
  | sudo tee /etc/apt/preferences.d/mozilla
sudo snap remove firefox     # if installed
sudo apt update && sudo apt install -y firefox
```

The pin file makes apt prefer Mozilla's repo over the Ubuntu transitional
package. `restore.sh` will then drop `firefox/user.js` and `firefox/firefox-themes/`
into the new profile so Wayland HiDPI and the WhiteSur chrome both come up
correctly on first launch.

### 4. Apple SF Pro / SF Mono / New York fonts

Apple distributes these for free from
<https://developer.apple.com/fonts/> but the license forbids re-distribution,
so they're not bundled in this archive. Download the four DMGs (SF Pro,
SF Mono, SF Compact, NY) into `~/Downloads/`, then `restore.sh` extracts and
installs them. Direct CDN URLs (subject to change):
```
https://devimages-cdn.apple.com/design/resources/download/SF-Pro.dmg
https://devimages-cdn.apple.com/design/resources/download/SF-Mono.dmg
https://devimages-cdn.apple.com/design/resources/download/SF-Compact.dmg
https://devimages-cdn.apple.com/design/resources/download/NY.dmg
```

### 5. GNOME extensions — install via browser

GNOME 42 extensions install via the extensions website with a browser native
host. The Mozilla deb works with `chrome-gnome-shell` out of the box (snap
Firefox does not). Install the package, then add the browser add-on, then
visit each URL below and toggle ON.

```sh
sudo apt install -y chrome-gnome-shell
```

Browser add-ons (one or the other):
- Firefox: <https://addons.mozilla.org/firefox/addon/gnome-shell-integration/>
- Chrome:  <https://chromewebstore.google.com/detail/gnome-shell-integration/gphhapmejobijbbhgpjhcjognlahblep>

Then install each of these 16 extensions (URLs link by UUID):

```
https://extensions.gnome.org/extension/by-uuid/x11gestures@joseexposito.github.io
https://extensions.gnome.org/extension/by-uuid/fullscreen-to-empty-workspace@aiono.dev
https://extensions.gnome.org/extension/by-uuid/user-theme@gnome-shell-extensions.gcampax.github.com
https://extensions.gnome.org/extension/by-uuid/dash-to-dock@micxgx.gmail.com
https://extensions.gnome.org/extension/by-uuid/just-perfection-desktop@just-perfection
https://extensions.gnome.org/extension/by-uuid/blur-my-shell@aunetx
https://extensions.gnome.org/extension/by-uuid/Vitals@CoreCoding.com
https://extensions.gnome.org/extension/by-uuid/space-bar@luchrioh
https://extensions.gnome.org/extension/by-uuid/caffeine@patapon.info
https://extensions.gnome.org/extension/by-uuid/clipboard-indicator@tudmotu.com
https://extensions.gnome.org/extension/by-uuid/hidetopbar@mathieu.bidon.ca
https://extensions.gnome.org/extension/by-uuid/burn-my-windows@schneegans.github.com
https://extensions.gnome.org/extension/by-uuid/compiz-alike-magic-lamp-effect@hermes83.github.com
https://extensions.gnome.org/extension/by-uuid/gestureImprovements@gestures
```
(`ding@rastersoft.com` and `ubuntu-appindicators@ubuntu.com` ship with
Ubuntu — already installed.)

On Wayland, `x11gestures@joseexposito.github.io` is a no-op and can be
skipped — Wayland handles 3-finger workspace swipes natively.

## How to restore

After completing the manual steps above:

```sh
tar -xzf gnomemac-backup.tar.gz
cd gnomemac-backup
./restore.sh
```

The script:
1. apt-installs build/runtime deps (touchegg PPA + binary, sassc,
   gnome-themes-extra, gtk2-engines-murrine, libxml2-utils, p7zip-full,
   chrome-gnome-shell).
2. Copies the WhiteSur themes into `~/.themes/`.
3. Extracts the four Apple DMGs into `~/.local/share/fonts/apple/` if they're
   present in `~/Downloads/`.
4. Copies fontconfig, environment.d, monitors.xml, Touchégg config to the
   right paths.
5. Copies the Firefox chrome into `~/.mozilla/firefox/firefox-themes/` and
   makes `~/.mozilla/firefox/<your-profile>/chrome` symlink to it.
6. Drops `user.js` into the Firefox profile.
7. Loads the dconf dump — this is the big step that applies every GNOME and
   per-extension setting at once.
8. Prints the remaining manual steps (install extensions in browser, log
   out and back in).

## Order of operations on a fresh box

1. Install Ubuntu 22.04, log in (X11 initially is fine).
2. Run the **Manual gotchas** in order — NVIDIA driver, GDM Wayland, Firefox
   deb, Apple fonts, GNOME extensions.
3. Log out, pick "Ubuntu" (Wayland) at the greeter, log in.
4. Run `restore.sh`.
5. Log out, back in. Settings now applied.

## Caveats

- The dconf dump captures GNOME + per-extension settings; it does not include
  app-level configs (terminal profiles, Slack, Code, etc.).
- `monitors.xml` is for a single 4K display at 2× scale with the laptop panel
  disabled (clamshell). If your hardware differs, delete it after restore and
  let Settings → Displays write a fresh one.
- `gestureImprovements@gestures` + multi-monitor was unstable on X11; on
  Wayland it's been reliable. If issues recur, disable that extension first.
- `fullscreen-to-empty-workspace@aiono.dev` crashed gnome-shell on Wayland
  back in May 2026 with monitor reconfigure events; if that bug is back,
  disable it first too.
- NVIDIA + Wayland fractional/HiDPI scaling required `scale-monitor-framebuffer`
  and `xwayland-native-scaling` Mutter experimental flags — both already in
  the dconf dump, but check them if rendering looks blurry.
