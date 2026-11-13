#!/bin/sh
# Headphone Jack Fix for the Anbernic RG35XX H (Allwinner H700) on muOS
# https://github.com/magdielndantas/rg35xxh-muos-fixes
#
# Problem: the headphone-detect pin (PI3, "Headphone detection", gpio-259)
# is configured with NO pull resistor. When the 3.5 mm jack's detect contact
# wears out or gets dirty, the pin floats: just touching the jack makes the
# kernel think headphones were plugged in, and it switches the speaker
# amplifier off (PI5, gpio-261 goes low). The speakers go silent and often
# stay that way.
#
# Fix: enable the SoC's internal pull-down on PI3, so a floating pin reads
# "no headphones" (speakers on). Real headphones drive the pin high, which
# overrides the weak internal pull-down. A loop re-applies the setting every
# 5 seconds in case it gets reset (e.g. after suspend/resume).

APP_DIR="/mnt/mmc/MUOS/application/Jack Fix"
FLAG_OFF="$APP_DIR/disabled"
PIDFILE="/run/jack_fix.pid"
LOG="/mnt/mmc/MUOS/log/jack_fix.log"

# Port I PULL0 register: PIO base 0x0300B000 + bank 8 * 0x24 + 0x1C
# PI3 uses bits 7:6 (00 = no pull, 01 = pull-up, 10 = pull-down)
REG=$((0x0300B000 + 8 * 0x24 + 0x1C))
MASK=$((0xC0))
PULLDOWN=$((0x80))

log() { echo "$(date '+%F %T') $*" >>"$LOG"; }

read_reg() { printf '%d' "$(devmem "$REG" 32)"; }

set_pull() { # $1 = value for bits 7:6; returns 0 only if it changed something
	CUR=$(read_reg)
	NEW=$(((CUR & ~MASK) | $1))
	[ "$CUR" -ne "$NEW" ] && devmem "$REG" 32 "$NEW" && return 0
	return 1
}

stop_daemon() {
	[ -f "$PIDFILE" ] && kill "$(cat "$PIDFILE")" 2>/dev/null
	rm -f "$PIDFILE"
}

if [ "$1" = "stop" ]; then
	stop_daemon
	set_pull 0 && log "fix disabled (pull removed)"
	exit 0
fi

[ -f "$FLAG_OFF" ] && exit 0

# Safety: only touch the pin if PI3 (gpio-259) really is headphone detection
mount | grep -q debugfs || mount -t debugfs none /sys/kernel/debug 2>/dev/null
if ! grep "gpio-259 " /sys/kernel/debug/gpio 2>/dev/null | grep -q "Headphone detection"; then
	log "gpio-259 is not 'Headphone detection' on this device, doing nothing"
	exit 0
fi

stop_daemon
echo $$ >"$PIDFILE"
set_pull "$PULLDOWN" && log "fix enabled (pull-down on PI3)"

while [ ! -f "$FLAG_OFF" ]; do
	sleep 5
	set_pull "$PULLDOWN" && log "pull-down re-applied"
done

rm -f "$PIDFILE"
