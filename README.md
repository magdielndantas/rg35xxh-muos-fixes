# RG35XX H muOS fixes

Fixes for two hardware-related problems on the **Anbernic RG35XX H** (Allwinner H700) running **muOS 2601.1 "Funky Jacaranda"**. Each fix comes as a `.muxupd` package that you install with muOS's Archive Manager.

| Package | Fixes |
|---|---|
| [Headphone Jack Fix](#1-headphone-jack-fix) | Speakers go silent when you touch the headphone jack, or stay muted with nothing plugged in |
| [Bluetooth Watchdog](#2-bluetooth-watchdog) | Bluetooth stops working (headphones/controllers won't connect) until you reboot |

Download both from [Releases](../../releases).

---

## 1. Headphone Jack Fix

### Symptoms
- The speakers mute when you touch or wiggle the 3.5 mm jack, with **no headphones plugged in**.
- Sometimes they stay muted until you fiddle with the jack again or reboot.
- Headphones "behave strangely": sound sometimes comes out of the speakers, sometimes the headphones, sometimes neither.

### Cause
The audio codec uses a GPIO to detect headphones (`PI3`, listed as `gpio-259 "Headphone detection"` in `/sys/kernel/debug/gpio`). When it reads **high**, the kernel switches off the speaker amplifier (`PI5`, `gpio-261`).

On this device `PI3` is configured with **no pull resistor** (`PULL0` bits 7:6 = `00`). When the jack's detect contact is worn, dirty or oxidised, the pin floats, so a finger touching the metal is enough to flip it. Here is a log of the two pins while touching an **empty** jack:

```
22:07:22 det=lo pa=hi   <- no headphones, speakers on
22:08:06 det=hi pa=lo   <- touched the jack: "headphones inserted", speakers off
22:08:07 det=lo pa=hi
22:08:09 det=hi pa=lo
22:08:09 det=lo pa=hi
22:08:11 det=hi pa=lo   <- stuck here: speakers muted
```

### Fix
The package turns on the SoC's **internal pull-down** on `PI3`. A floating pin then reads "no headphones" and the speakers stay on. Real headphones drive the pin high, which overrides the weak internal pull-down. A small loop re-applies the setting every 5 s in case something resets it (suspend/resume, for example).

After the fix, touching the jack no longer mutes the speakers.

> **Note:** this works around a hardware fault, it doesn't repair it. Cleaning the jack with contact cleaner (or replacing it) is the permanent fix. Detection with real headphones plugged in has **not been tested yet**. If you plug in headphones and sound still comes out of the speakers, switch the fix off in the app and please open an issue.

### What it installs
- `MUOS/init/jack_fix.sh`: runs at boot through muOS user init scripts and logs to `MUOS/log/jack_fix.log`.
- **Applications → Jack Fix**: switches the fix on or off and shows the new state on screen.

### Manual check (SSH)
```sh
mount -t debugfs none /sys/kernel/debug 2>/dev/null
grep -E "gpio-259 |gpio-261 " /sys/kernel/debug/gpio   # det / speaker amp
devmem 0x0300B13C 32                                   # bits 7:6 = 10 -> pull-down on
```

---

## 2. Bluetooth Watchdog

**Requires the [Bluetooth app for muOS](https://github.com/nvcuong1312/bltMuos) by nvcuong1312** ([forum thread](https://community.muos.dev/t/bluetooth-app/163)). This package only replaces the boot script that app installs (`MUOS/init/bluetooth.sh`). The fix has been sent to the app's author as [PR #21](https://github.com/nvcuong1312/bltMuos/pull/21). Once it is merged, just use the official app and you won't need this package.

### Symptoms
- Bluetooth headphones/controllers suddenly can't connect, or connect only sometimes.
- Rebooting the handheld fixes it, for a while.

### Cause
The Bluetooth chip (Realtek RTL8821CS, attached over UART `/dev/ttyS1` with the H5 protocol by `rtk_hciattach`) sometimes stops answering:

```
Bluetooth: hci0 command 0x0c14 tx timeout
Bluetooth: hci0 command 0x0405 tx timeout
$ hciconfig hci0 name
Can't read local name on hci0: Connection timed out (110)
```

`hciconfig` shows the TX command counter rising while the RX event counter is frozen. `bluetoothctl show` still says `Powered: yes`, but nothing gets through. The original boot script attaches the chip once and never checks on it again.

### Fix
The replacement `bluetooth.sh`:
1. power-cycles the chip (`sunxi-bt` rfkill) before attaching it, so it starts from a clean state;
2. checks every 20 s that the chip answers HCI *Read Local Name*;
3. after 3 failures in a row, power-cycles and re-attaches the chip and powers the adapter back on;
4. stays idle while Bluetooth is switched off or while `bluetoothd` isn't running (so it doesn't fight the app when the app restarts the stack).

Watchdog actions are logged to `MUOS/log/bt_watchdog.log`. Tested by cutting the chip's power under a running `rtk_hciattach` (same `tx timeout` errors as the real hang): recovered in about 60 s with no reboot.

Installing this package reboots the handheld, the same way the original app's installer does.

---

## Installing
1. Copy the `.muxupd` file(s) to `ARCHIVE/` on the SD card (`/mnt/mmc/ARCHIVE`).
2. On the device: **Applications → Archive Manager**, then pick the package.
3. User init scripts get enabled automatically (`settings/advanced/user_init = 1`).

## Uninstalling
- Jack Fix: run the app once to disable the fix, then delete `MUOS/init/jack_fix.sh` and `MUOS/application/Jack Fix/`.
- Bluetooth Watchdog: reinstall the original Bluetooth app package to get its stock `bluetooth.sh` back.

## Building
```sh
python build.py   # creates dist/*.muxupd from packages/
```
Each folder in `packages/` mirrors the device's root filesystem. muOS extracts the package over `/` and runs `opt/update.sh`.

## Compatibility
Only tested on an RG35XX H with muOS 2601.1. Other H700 devices (RG35XX Plus/SP/2024, RG40XX H/V, RG CubeXX...) probably share the Bluetooth setup. The headphone-detect pin may be different on them, so **don't install the Jack Fix on another model** without first checking `/sys/kernel/debug/gpio` for `Headphone detection` on `gpio-259`.

## License
MIT. See [LICENSE](LICENSE).
