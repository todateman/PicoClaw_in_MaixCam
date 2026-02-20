#!/bin/sh

PICOCLAW=/root/picoclaw
LOG=/var/log/picoclaw-watchdog.log
HEARTBEAT_LOG=/root/.picoclaw/workspace/heartbeat.log
CONFIG=/root/.picoclaw/config.json
HEARTBEAT_TIMEOUT=3600
CHECK_INTERVAL=60

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
}

# Extract Discord bot token from config.json (look inside "discord" section)
get_discord_token() {
    grep -A10 '"discord"' "$CONFIG" | grep '"token"' | head -1 | sed 's/.*"token": *"\([^"]*\)".*/\1/'
}

# Extract last known Discord channel ID from heartbeat.log
get_discord_channel() {
    grep -o 'discord:[0-9]*' "$HEARTBEAT_LOG" 2>/dev/null | tail -1 | cut -d: -f2
}

# Send Discord notification via Bot API
notify_discord() {
    MSG="$1"
    TOKEN=$(get_discord_token)
    CHANNEL=$(get_discord_channel)

    if [ -z "$TOKEN" ] || [ -z "$CHANNEL" ]; then
        log "WARN: Discord token or channel not found, skip notification."
        return 1
    fi

    PAYLOAD="{\"content\":\"$MSG\"}"

    if which curl > /dev/null 2>&1; then
        curl -s -o /dev/null \
            -X POST \
            -H "Authorization: Bot $TOKEN" \
            -H "Content-Type: application/json" \
            -d "$PAYLOAD" \
            "https://discord.com/api/v10/channels/$CHANNEL/messages" \
            && log "Discord notification sent (curl)." \
            || log "WARN: Discord notification failed (curl)."
    elif which wget > /dev/null 2>&1; then
        wget -q -O /dev/null \
            --header="Authorization: Bot $TOKEN" \
            --header="Content-Type: application/json" \
            --post-data="$PAYLOAD" \
            "https://discord.com/api/v10/channels/$CHANNEL/messages" \
            && log "Discord notification sent (wget)." \
            || log "WARN: Discord notification failed (wget)."
    else
        log "WARN: Neither curl nor wget available, skip notification."
    fi
}

stop_picoclaw() {
    killall picoclaw 2>/dev/null
    # Clean up orphaned udevadm processes spawned by picoclaw device monitor
    killall udevadm 2>/dev/null
    sleep 2
}

start_picoclaw() {
    log "Starting PicoClaw gateway..."
    HOME=/root nohup $PICOCLAW gateway >> /var/log/picoclaw.log 2>&1 &
    PICOCLAW_PID=$!
    log "PicoClaw gateway started. PID=$PICOCLAW_PID"
    echo "$PICOCLAW_PID" > /var/run/picoclaw.pid
    PICOCLAW_STARTED=$(date +%s)
}

log "Watchdog started."
start_picoclaw

# Wait for PicoClaw to fully initialize, then send startup notification
sleep 15
notify_discord "PicoClaw started on MaixCAM at $(date '+%Y-%m-%d %H:%M:%S')"

while true; do
    sleep "$CHECK_INTERVAL"

    PID=$(cat /var/run/picoclaw.pid 2>/dev/null)

    # Check 1: Is the process alive?
    if [ -z "$PID" ] || ! kill -0 "$PID" 2>/dev/null; then
        log "WARN: PicoClaw process not found. PID=$PID Restarting..."
        stop_picoclaw
        start_picoclaw
        sleep 15
        notify_discord "PicoClaw restarted on MaixCAM (crash recovery) at $(date '+%Y-%m-%d %H:%M:%S')"
        continue
    fi

    # Check 2: Is heartbeat log stale? (process hung)
    # Only check after running at least HEARTBEAT_TIMEOUT to avoid false positives on startup
    NOW=$(date +%s)
    UPTIME=$(expr $NOW - $PICOCLAW_STARTED)
    if [ "$UPTIME" -gt "$HEARTBEAT_TIMEOUT" ] && [ -f "$HEARTBEAT_LOG" ]; then
        LAST_BEAT=$(stat -c %Y "$HEARTBEAT_LOG" 2>/dev/null || echo 0)
        ELAPSED=$(expr $NOW - $LAST_BEAT)
        if [ "$ELAPSED" -gt "$HEARTBEAT_TIMEOUT" ]; then
            log "WARN: Heartbeat stale for ${ELAPSED}s. Killing and restarting..."
            stop_picoclaw
            start_picoclaw
            sleep 15
            notify_discord "PicoClaw restarted on MaixCAM (heartbeat timeout) at $(date '+%Y-%m-%d %H:%M:%S')"
        fi
    fi
done
