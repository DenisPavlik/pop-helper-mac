#!/bin/bash
# PoP load-test harness.
# Launches Warband on whatever module state is currently on disk, then decides:
#   - CRASHED: the process exited on its own (SIGSEGV=exit 139, abort=134, etc.)
#   - LOADED_OK: the process was still alive after MAXWAIT seconds => it finished
#                loading and is sitting at the main menu.
# Always prints a single "RESULT: ..." line and exits 0.
# Usage: bash loadtest.sh [MAXWAIT_SECONDS]
set -u
GAMEROOT="$HOME/Library/Application Support/Steam/steamapps/common/MountBlade Warband"
GBIN="$GAMEROOT/Mount and Blade.app/Contents/MacOS/Mount and Blade"
LOG=/tmp/pop_lt_stdout.log
MAXWAIT=${1:-80}

# Kill any stray instance from a previous run so we measure a clean launch.
pkill -f "MacOS/Mount and Blade" 2>/dev/null
sleep 2

cd "$GAMEROOT" || { echo "RESULT: ERROR cannot cd to game root"; exit 0; }
rm -f "$LOG"

SteamAppId=48700 "$GBIN" >"$LOG" 2>&1 &
PID=$!

secs=0
while [ "$secs" -lt "$MAXWAIT" ]; do
  if ! kill -0 "$PID" 2>/dev/null; then
    wait "$PID" 2>/dev/null; code=$?
    echo "RESULT: CRASHED exit=$code after ${secs}s"
    exit 0
  fi
  sleep 2
  secs=$((secs + 2))
done

# Survived the whole window => loading completed, sitting at main menu.
kill "$PID" 2>/dev/null
sleep 1
kill -9 "$PID" 2>/dev/null
echo "RESULT: LOADED_OK (still alive at ${MAXWAIT}s -> reached main menu)"
exit 0
