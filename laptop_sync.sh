#!/bin/env bash

#
# laptop_sync.sh
#
# Wrapper script around laptop_sync_internal.sh
#
# - Notifications
# - Execution Lock
# - Logging
#

set -o nounset

readonly notify_exec=notify-send

readonly script_dir=$( dirname "$(readlink -f "$0")" )
readonly notify_log_file=$(mktemp -u --tmpdir laptop_sync.XXXXXX)
readonly exec="$script_dir/laptop_sync_internal.sh"
readonly log_file="$script_dir/sync.log"
readonly lock_file=/tmp/sync.lockfile
readonly block_file=/tmp/sync.block

main() {
    if [[ -f "$block_file" ]]; then
        echo "Sync is disabled due to file $block_file. Remove file to continue."
        exit
    fi    

    /usr/bin/flock -F -n -E 249 "$lock_file" "$exec" "$@" 2>&1 \
        | tee -a "$log_file" \
        | tee "$notify_log_file"
    
    local status=${PIPESTATUS[0]}
    local notify_log=$(cat "$notify_log_file")
    
    if [[ $status != 249 && $status != 0 ]]; then
        echo "Error code: $status"
        $notify_exec "sync.sh failed with status: $status, $notify_log" &> /dev/null
    fi
}


main "${@}"
