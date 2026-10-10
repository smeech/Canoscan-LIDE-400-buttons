#!/bin/sh
# Button handler for the Canon CanoScan LiDE 400 (SANE pixma backend).
#   Button 1 SCAN START : scan a page and add it to the current PDF
#   Button 2 FINISH     : save the collected pages as one PDF
#   Button 3 AUTO SCAN  : scan in colour and save a lossless PNG
#   Button 4 COPY       : scan in greyscale and print on the default printer
#   Button 5 SEND       : scan to a mono PDF and open an email with it attached
#
# Settings (environment variables, or ~/.config/buttonscan.conf when run as
# a service):
#   SCANNER_DEVICE  SANE device name (see: scanimage -L). If unset, the first
#                   scanner SANE finds is used.
#   SCAN_DIR        where files are saved (default: ~/Scans)
#
# Messages go to stdout (the journal, when run as a service) and, if
# notify-send is installed, to a desktop notification.

DEV="$SCANNER_DEVICE"
DIR="${SCAN_DIR:-$HOME/Scans}"
mkdir -p "$DIR"
TMP=$(mktemp -d)
trap 'exit 1' INT TERM
trap 'rm -rf "$TMP"' EXIT

note() {
    echo "$*"
    command -v notify-send >/dev/null 2>&1 \
      && notify-send -a Scanner "Scanner" "$*" >/dev/null 2>&1
    return 0
}

find_scanner() {
    timeout 30 scanimage -f '%d%n' 2>/dev/null | head -n 1
}

read_target() {
    timeout 15 scanimage -d "$DEV" --button-update -A 2>/dev/null \
      | grep -- '--target ' | sed 's/.*\[\([0-9]*\)\].*/\1/'
}

stamp() { date +%Y%m%d-%H%M%S; }

n=0
[ -n "$DEV" ] && read_target >/dev/null    # discard start-up state

while true; do
    if [ -z "$DEV" ]; then
        DEV=$(find_scanner)
        if [ -z "$DEV" ]; then
            sleep 10
            continue
        fi
        echo "Using scanner $DEV"
        read_target >/dev/null    # discard start-up state
    fi

    t=$(read_target)
    case "$t" in
        5)  # Button 1, SCAN START: add a page to the current document
            n=$((n + 1))
            page=$(printf '%s/page-%03d.tif' "$TMP" "$n")
            note "Scanning page $n..."
            if timeout 180 scanimage -d "$DEV" --format=tiff --mode Lineart \
                   --resolution 300 > "$page"; then
                note "Page $n scanned. Press 1 for another, 2 to finish."
            else
                note "Scan failed"
                rm -f "$page"
                n=$((n - 1))
            fi
            ;;
        6)  # Button 2, FINISH: combine pages into one PDF
            if [ "$n" -gt 0 ]; then
                out="$DIR/scan-$(stamp).pdf"
                if img2pdf "$TMP"/page-*.tif -o "$out"; then
                    note "Saved $n page(s) to $out"
                else
                    note "Could not create PDF"
                fi
                rm -f "$TMP"/page-*.tif
                n=0
            else
                note "No pages to save"
            fi
            ;;
        2)  # Button 3, AUTO SCAN: colour, lossless PNG
            out="$DIR/scan-$(stamp).png"
            note "Colour scan..."
            if timeout 180 scanimage -d "$DEV" --format=png --mode Color \
                 --resolution 300 > "$out"; then
                note "Saved $out"
            else
                note "Scan failed"
                rm -f "$out"
            fi
            ;;
        1)  # Button 4, COPY: scan and print on the default printer
            note "Copying..."
            if timeout 180 scanimage -d "$DEV" --format=png --mode Gray \
                 --resolution 300 > "$TMP/copy.png" \
               && img2pdf "$TMP/copy.png" -o "$TMP/copy.pdf"; then
                lp "$TMP/copy.pdf" >/dev/null && note "Sent to printer"
            else
                note "Copy failed"
            fi
            rm -f "$TMP/copy.png" "$TMP/copy.pdf"
            ;;
        3)  # Button 5, SEND: scan to PDF and start an email with it attached
            out="$DIR/scan-$(stamp).pdf"
            note "Scanning for email..."
            if timeout 180 scanimage -d "$DEV" --format=tiff --mode Lineart \
                 --resolution 300 | img2pdf - -o "$out"; then
                note "Saved $out, opening email"
                xdg-email --subject "Scan" --attach "$out" \
                  </dev/null >/dev/null 2>&1 &
            else
                note "Scan failed"
                rm -f "$out"
            fi
            ;;
    esac
    sleep 1
done
