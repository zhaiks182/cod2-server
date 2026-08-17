#!/bin/bash

# Auto-detect the folder this script lives in, so it works regardless of
# where the repo was cloned/copied to (no hardcoded path).
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sv_maxclients="30"
#fs_game="dtNriflesDM"
fs_homepath="$DIR"
cod="$DIR/cod2_lnxded"
com_hunkMegs="256"
config="server.cfg"
cracked="1"
net_port="28960"


args=\
"+set fs_homepath \"$fs_homepath\" "\
"+set sv_cracked $cracked "\
"+set fs_game $fs_game "\
"+set net_port $net_port "\
"+set com_hunkMegs $com_hunkMegs "\
"+set sv_maxclients $sv_maxclients "\
"+set fs_basepath \"$fs_homepath\" "\
"+exec $config"

LD_PRELOAD="$DIR/libCoD2x.so" $cod $args +set g_gametype sd +map mp_toujane_fix +set rcon_password pug2026! +map_rotate
