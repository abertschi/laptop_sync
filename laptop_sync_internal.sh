#!/bin/bash

## 
## sync_internal.sh
##
## Sync script for rsync.
##  
## Args:
##   --force-local.........: Forces ssh using SSH_HOME_NET
##   --force-remote........: Forces ssh using SSH_INTERNET
##   --rsync-args="args...": Additional rsync arguments
##   --force-sync.........." Avoids battery/time/connectivity test
##

set -o nounset
set -o errexit

readonly script_dir=$( dirname "$(readlink -f "$0")" )

readonly sync_from=/home/user/
readonly sync_to=some_host:/backup/data
readonly ssh_home_net="ssh"
readonly ssh_internet="ssh -J jumphost"
readonly sync_file="merge $script_dir/rsync.txt"

readonly wifi_if_name=wlp0s20f3
readonly ssid="ssid1\|ssid2"

readonly power_supply_path=/sys/class/power_supply/AC/online
readonly last_run_file="$script_dir/sync.lastrun.txt"

exit_code=0

# args
arg_force_sync=0 
arg_rsync_args=""
arg_force_remote=0
arg_force_local=0

function sync_home_net {
    log "INFO" "syncing in home net";
    set -x
    rsync --archive -z  --delete -e "$ssh_home_net" $arg_rsync_args \
          --filter="$sync_file" "$sync_from" "$sync_to"
    exit_code=$?
    set +x
}

function sync_internet {
    log "INFO" "syncing over internet";
    set -x
    rsync --archive -z --delete -e "$ssh_internet" $arg_rsync_args \
          --filter="$sync_file" "$sync_from" "$sync_to"
    exit_code=$?
    set +x
}

function on_ac {
    cat "$power_supply_path"
}

function on_internet {
    ping -c 1 google.com &> /dev/null && echo 1 || echo 0
}

function on_home_net {
    nmcli | grep "$wifi_if_name" | head -n 1 | awk '{print $4}' | grep -q "$ssid" && echo 1 || echo 0
}

function write_last_run {
    date > "$last_run_file"
}

function can_run_again {
    local run=0

    run=$(cat "$last_run_file" 2> /dev/null || echo 0)
    if [[ "${run}" == "0" ]]; then
        echo 1
    else
        local next_run=$(date --date "$run +6 hours" +%F_%T)
        local now=$(date +%F_%T)
        [[ "${next_run}" < "${now}" ]] && echo 1 || echo 0
    fi
}

function log {
    local prefix="[$(date +%Y/%m/%d\ %H:%M:%S)]:"
    echo "${prefix} $@" >&2
}

function secs_to_human() {
    echo "$(( ${1} / 3600 ))h $(( (${1} / 60) % 60 ))m $(( ${1} % 60 ))s"
}

function start_count() {
    SECONDS=0
}

function stop_count() {
    local T=$(secs_to_human $SECONDS)
    log "INFO" "Sync took $T"
}    

# main

while [ $# -gt 0 ]; do
    case "$1" in
        --force-sync*)
            log "TRACE" "arg_force_sync=1"
            arg_force_sync=1
            ;;
        --force-remote*)
            log "TRACE" "arg_force_remote=1"
            arg_force_remote=1
            ;;
        --force-local*)
            log "TRACE" "arg_force_local=1"
            arg_force_local=1
            ;;
        --rsync-args=*)
            arg_rsync_args="${1#*=}"
            log "TRACE" "arg_rsync_args=$arg_rsync_args"    
            ;;
    esac
    shift
done

start_count

if [[ "$arg_force_sync" != "1" ]]; then
    on_ac | grep -q 0 && (log "TRACE" "Not connected to AC") && exit 0
    can_run_again | grep -q 0 && (log "TRACE" "Not time to run") && exit 0
    on_internet | grep -q 0 && (log "TRACE" "No internet") && exit 0
fi

if [[ "$arg_force_remote" == "1" ]]; then
    sync_internet
elif [[ "$arg_force_local" == "1" ]]; then
    on_home_net | grep -q 1 && sync_home_net || (log "WARN" "Not in homenet. Exit.") && exit 0
else
    on_home_net | grep -q 1 && sync_home_net || sync_internet
fi

stop_count

if [[ $exit_code == 0 ]]; then
    log "INFO" "syncing was successful";
    write_last_run
fi    

log "INFO" "Exit Code is: $exit_code"
exit $exit_code
