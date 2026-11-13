#!/bin/sh

. /opt/muos/script/var/func.sh

# muOS only runs scripts in MUOS/init when "User Init Scripts" is enabled
SET_VAR "global" "settings/advanced/user_init" "1"

# The new init script takes effect on the next boot
setsid bash -c '
/opt/muos/script/system/halt.sh reboot
'
