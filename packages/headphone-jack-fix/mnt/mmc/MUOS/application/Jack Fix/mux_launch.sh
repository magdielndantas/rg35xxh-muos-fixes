#!/bin/sh
# HELP: Toggle the fix for a faulty headphone jack that mutes the speakers
# ICON: jack_fix
# GRID: Jack Fix

. /opt/muos/script/var/func.sh

APP_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/application/Jack Fix"
FLAG_OFF="$APP_DIR/disabled"
INIT="$MUOS_STORE_DIR/init/jack_fix.sh"

echo app >/tmp/act_go

if [ -f "$FLAG_OFF" ]; then
	rm -f "$FLAG_OFF"
	setsid sh "$INIT" >/dev/null 2>&1 </dev/null &
	MSG=$(printf "Jack Fix\n\nFix ENABLED\n\nTouching the headphone jack will\nno longer mute the speakers.")
else
	touch "$FLAG_OFF"
	sh "$INIT" stop
	MSG=$(printf "Jack Fix\n\nFix DISABLED\n\nHeadphone detection is back to\nthe stock (floating) behaviour.")
fi

/opt/muos/frontend/muxmessage 0 "$MSG" -d 3
