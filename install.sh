#!/bin/sh
# Install buttonscan as a systemd user service (starts at login).
# Run from the folder containing buttonscan.sh and buttonscan.service.
set -e

here=$(cd "$(dirname "$0")" && pwd)
bin="$HOME/.local/bin"
unit="$HOME/.config/systemd/user"
conf="$HOME/.config/buttonscan.conf"

for cmd in scanimage img2pdf lp xdg-email systemctl timeout; do
    command -v "$cmd" >/dev/null 2>&1 \
      || echo "Warning: '$cmd' not found (see README for packages)" >&2
done

mkdir -p "$bin" "$unit"
install -m 755 "$here/buttonscan.sh" "$bin/buttonscan.sh"
install -m 644 "$here/buttonscan.service" "$unit/buttonscan.service"

# Create a settings file only if one doesn't exist, so re-running the
# installer never overwrites your settings.
if [ ! -f "$conf" ]; then
    cat > "$conf" <<'EOF'
# Optional settings for buttonscan. Remove the leading # to use one.
# Values are used exactly as written (no $HOME or ~ expansion).
#
# Your scanner's SANE device name; find it with: scanimage -L
# SCANNER_DEVICE=pixma:XXXXXXXX_XXXXXX
#
# Where scans are saved (default is ~/Scans)
# SCAN_DIR=/home/yourname/Scans
EOF
fi

systemctl --user daemon-reload
systemctl --user enable buttonscan.service
systemctl --user restart buttonscan.service

echo "Installed. Check it with: systemctl --user status buttonscan"
echo "Settings (optional): $conf"
echo "After editing settings: systemctl --user restart buttonscan"
