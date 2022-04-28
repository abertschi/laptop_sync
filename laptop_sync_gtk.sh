#!/bin/bash

# Inspired from yad examples

SCRIPT_DIR=$( dirname "$(readlink -f "$0")" )
export LOG="$SCRIPT_DIR/sync.log"
export EXEC="$SCRIPT_DIR/laptop_sync.sh"
export NOTIFY="notify-send"
export BLOCK_FILE=/tmp/sync.block


ERR(){ echo "ERROR: $1" 1>&2; }

declare -i DEPCOUNT=0
for DEP in /usr/bin/{xdotool,yad,xprop};do
    [ -x "$DEP" ] || {
        ERR "$LINENO Dependency '$DEP' not met."
        DEPCOUNT+=1
    }
done

[ $DEPCOUNT -eq 0 ] || exit 1

VERSION=`yad --version | awk '{ print $1 }'`
verlte() {
    [  "$1" = "`echo -e "$1\n$2" | sort -V | head -n1`" ]
}

verlt() {
    [ "$1" = "$2" ] && return 1 || verlte $1 $2
}

if verlt $VERSION 0.38.2; then
    yad --text=" The version of yad installed is too old for to run this program, \n Please upgrade yad to a version higher than 0.38.2   " \
        --button="gtk-close"
    exit
fi

# window class for the list dialog
export CLASS="left_click_001"

# fifo
export YAD_NOTIF=$(mktemp -u --tmpdir YAD_NOTIF.XXXXXX)
mkfifo "$YAD_NOTIF"

# trap that removes fifo
clean_up() {
    rm -f $YAD_NOTIF
}

trap clean_up EXIT

show_status_log(){
    content=""
    if [[ -f "$LOG" ]]; then
        content="$(cat $LOG)"
    fi    
    echo -e "# $LOG\n" "$content" | tail -n 10000 | yad --text-info
    # echo -e "# $LOG\n" "$content" | grep -v TRACE | yad --text-info
}
export -f show_status_log

sync_now(){
    $NOTIFY "Start laptop sync..."
    ( "$EXEC" --force-sync --rsync-args="-v " &> /dev/null ) &
}
export -f sync_now

enable(){
    echo "enable"
    rm -f "$BLOCK_FILE"
}
export -f enable

disable(){
    touch "$BLOCK_FILE"
}
export -f disable


list_dialog() {
    # Ensures only one instance of this window
    # Also, if there is another yad window closes it
    if [[ $(pgrep -c $(basename $0)) -ne 1 ]]; then
        pids="$(xdotool search --class "$CLASS")"
        wpid="$(xdotool getwindowfocus)"

        for pid in $pids; do
            # Compares window class pid with the pid of a window in focus
            if [[ "$pid" == "$wpid" ]]; then
                xdotool windowunmap $pid
                exit 1
            fi
        done
    fi

    on_off_cmd=""
    if [[ -f "$BLOCK_FILE" ]]; then
        on_off_cmd="enable\nEnable"
    else
        on_off_cmd="disable\nDisable"
    fi    

    echo -e " show_status_log\nStatus Log\n" \
         "sync_now\nSync Now\n" \
         "$on_off_cmd" |
        yad --list \
            --class="$CLASS" \
            --column="" \
            --column="" \
            --no-markup \
            --no-headers \
            --no-buttons \
            --undecorated \
            --hide-column="1" \
            --close-on-unfocus \
            --on-top \
            --skip-taskbar \
            --mouse \
            --width=300 --height=150 \
            --sticky \
            --select-action="sh -c \"echo %s | cut -d ' ' -f 2 2>&1 | xargs -I {} bash -c {} \""

}
export -f list_dialog

# fuction to set the notification icon
function set_notification_icon() {
    echo "icon:gtk-yes" 
    echo "tooltip:Laptop Sync"
    echo "menu:Quit!quit!gtk-quit"
}

exec 3<> $YAD_NOTIF

yad --notification --command="bash -c 'list_dialog'" --listen <&3 & notifpid=$!

# waits until the notification icon is ready
until xdotool getwindowname $(xdotool search --pid "$notifpid" | tail -1) &>/dev/null; do
    sleep 0.5       
done

set_notification_icon >&3

wait $notifpid

exec 3>&-

exit 0
