# buttonscan

Use the front buttons of a Canon CanoScan LiDE 400 on Linux. A small shell
script polls the scanner's buttons through SANE (the `pixma` backend) and runs
a scan action when one is pressed. It can run as a systemd user service, so it
works in the background with no terminal open.

Tested only with a CanoScan LiDE 400. Other Canon models may report different
button values (see "Other scanners" below).

## What the buttons do

| Button | Label       | `--target` value | Action |
|--------|-------------|------------------|--------|
| 1      | SCAN START  | 5                | Scan a page (300 dpi, black and white) and add it to the current PDF |
| 2      | FINISH      | 6                | Save the collected pages as one PDF |
| 3      | AUTO SCAN   | 2                | Scan in colour (300 dpi) and save a lossless PNG |
| 4      | COPY        | 1                | Scan in greyscale (300 dpi) and print on the default printer |
| 5      | SEND        | 3                | Scan to a black and white PDF and open an email with it attached |

For a single sheet, press 1, then 2. Files are saved in `~/Scans/` with a
timestamp in the name. If `notify-send` is installed, each step also shows a
desktop notification.

AUTO SCAN does not detect the type of item (that is a feature of Canon's own
software); it always makes a colour PNG.

## Requirements

On Debian or Ubuntu:

```
sudo apt install sane-utils img2pdf cups-client xdg-utils libnotify-bin
```

- `sane-utils`: `scanimage`
- `img2pdf`: builds the PDFs
- `cups-client`: `lp`, for the COPY button
- `xdg-utils`: `xdg-email`, for the SEND button (works best with Thunderbird;
  some mail clients ignore the attachment)
- `libnotify-bin`: `notify-send`, for notifications (optional)

Check that SANE can see your scanner first:

```
scanimage -L
```

## Install

```
./install.sh
```

This copies the script to `~/.local/bin/`, installs a systemd user service,
and starts it. It also starts at each login.

## Settings

Optional settings live in `~/.config/buttonscan.conf`, which the installer
creates:

| Setting          | Meaning |
|------------------|---------|
| `SCANNER_DEVICE` | SANE device name, e.g. `pixma:XXXXXXXX_XXXXXX` (from `scanimage -L`). If unset, the first scanner found is used. |
| `SCAN_DIR`       | Where files are saved. Default: `~/Scans`. |

After changing settings: `systemctl --user restart buttonscan`

## Everyday use

```
systemctl --user status buttonscan      # is it running?
journalctl --user -u buttonscan -f      # watch what it is doing
systemctl --user stop buttonscan        # stop it
systemctl --user start buttonscan       # start it again
```

Stop the service before using another scanning program such as `simple-scan`.
The service checks the buttons about once a second, so the other program may
occasionally report the scanner as busy.

If the SEND button never opens an email window, the service probably doesn't
have your desktop's display settings. The PDF is still saved in the scan
folder.

## Other scanners

The values in the table are what the LiDE 400 reports in the `--target` option
when a button is pressed. To find the values for another model, run this and
press each button in turn:

```
while true; do
    scanimage -d 'YOUR_DEVICE' --button-update -A 2>/dev/null | grep -- '--target '
    sleep 1
done
```

Then change the numbers in the `case` block of `buttonscan.sh`.

## Uninstall

```
systemctl --user disable --now buttonscan
rm ~/.config/systemd/user/buttonscan.service ~/.local/bin/buttonscan.sh
rm -f ~/.config/buttonscan.conf
```
