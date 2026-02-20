#!/bin/sh
# MaixCAM camera snapshot and Discord upload
# Runs Python capture first (releases all maix resources on exit),
# then uploads via curl in a fresh process.

WEBHOOK="https://discordapp.com/api/webhooks/1473659254798811262/fw6KZcAhaJ12m291pqF8PNCJDD8khjZnKdkUSbddpYr8sV05C570yK0f-1y7-kIRn-Te"
SNAPSHOT="/root/.picoclaw/workspace/snapshot.jpg"

# Step 1: Capture photo (Python exits cleanly, releasing ISP)
# Discard Python stdout (MaixPy init logs) to avoid polluting $SNAPSHOT path
python3 /root/.picoclaw/workspace/camera_snap_discode.py >/dev/null
if [ $? -ne 0 ]; then
    echo "Error: camera capture failed" >&2
    exit 1
fi

if [ ! -f "$SNAPSHOT" ]; then
    echo "Error: snapshot file not found" >&2
    exit 1
fi

# Step 2: Upload via curl (Python is fully gone, memory/ISP released)
# Brief pause for kernel/ISP resources and memory to fully release after Python exits
sleep 2

CODE=$(curl -s --max-time 30 -o /dev/null -w "%{http_code}" \
    -F "file=@${SNAPSHOT}" \
    "$WEBHOOK")

if [ "$CODE" = "200" ] || [ "$CODE" = "204" ]; then
    # Restart launcher_daemon so the GUI recovers
    /maixapp/apps/launcher/launcher_daemon >/dev/null 2>&1 &
    echo "送信成功"
else
    # Restart launcher_daemon even on failure
    /maixapp/apps/launcher/launcher_daemon >/dev/null 2>&1 &
    echo "Error: Discord upload failed (HTTP ${CODE})" >&2
    exit 1
fi
