# laptop_sync

A simple set of bash scripts to backup a laptop to a remote machine using rsync.

### Features
- Do not sync while laptop is on battery
- Do not sync while syncing is already running
- Do not sync if already recently synced
- Different ssh options based on wifi ssids (home network vs public internet)
- Tray with yad, notifications with libnotif 

### Requirements
- ssh
- rsync
- flock
- yad (Only for laptop_sync_gtk)
- libnotif (for desktop notifications with notify-send, optional)


### Run
- 1. Setup sync options in laptop_sync_internal.sh
- 2. cronjob: `*/30 * * * * /some/bin/laptop_sync.sh`
