#!/bin/sh

. /opt/muos/script/var/func.sh

# muOS only runs scripts in MUOS/init when "User Init Scripts" is enabled
SET_VAR "global" "settings/advanced/user_init" "1"

rm -f "$(GET_VAR "device" "storage/rom/mount")/MUOS/application/Jack Fix/disabled"
setsid sh "$MUOS_STORE_DIR/init/jack_fix.sh" >/dev/null 2>&1 </dev/null &
