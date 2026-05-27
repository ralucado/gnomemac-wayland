#!/usr/bin/env bash
# Disable the built-in laptop panel (eDP-1) whenever an external HDMI display
# is connected. Mac-like "clamshell" behaviour driven by user choice.
# If no external is detected, leave eDP-1 alone so the laptop is still usable.
set -euo pipefail

# Let gnome-shell finish initial monitor setup before we override.
sleep 3

if xrandr --query 2>/dev/null | grep -E '^HDMI-1 connected' >/dev/null; then
  xrandr --output eDP-1 --off || true
  xrandr --output HDMI-1 --auto --primary --pos 0x0 || true
fi
