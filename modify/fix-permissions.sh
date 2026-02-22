#!/bin/sh
# PicoClaw セキュリティ権限修正スクリプト
# 使用方法: ssh MaixCAM 'bash -s' < fix-permissions.sh
# 参照: security-fixes-20260222.md

set -e

PICOCLAW_HOME="${PICOCLAW_HOME:-/root/.picoclaw}"
PICOCLAW_BIN="${PICOCLAW_BIN:-/root/picoclaw}"
WORKSPACE="$PICOCLAW_HOME/workspace"

echo "[PicoClaw Security Permission Fixer]"
echo "Target: $PICOCLAW_HOME"
echo ""

# 1. バイナリ権限
if [ -f "$PICOCLAW_BIN" ]; then
    chmod 700 "$PICOCLAW_BIN"
    echo "[OK] Binary: chmod 700 $PICOCLAW_BIN"
fi

# 2. 設定ファイル
if [ -f "$PICOCLAW_HOME/config.json" ]; then
    chmod 600 "$PICOCLAW_HOME/config.json"
    echo "[OK] Config: chmod 600 config.json"
fi
if [ -f "$PICOCLAW_HOME/auth.json" ]; then
    chmod 600 "$PICOCLAW_HOME/auth.json"
    echo "[OK] Auth: chmod 600 auth.json"
fi

# 3. ワークスペースのファイル権限
if [ -d "$WORKSPACE" ]; then
    # 通常ファイルを 600 に
    find "$WORKSPACE" -type f ! -name "*.sh" ! -name "*.py" -exec chmod 600 {} \;
    # 実行可能スクリプトを 700 に
    find "$WORKSPACE" -type f -name "*.sh" -exec chmod 700 {} \;
    find "$WORKSPACE" -type f -name "*.py" -exec chmod 700 {} \;
    echo "[OK] Workspace: chmod 600 (files), 700 (scripts)"
fi

# 4. cronジョブのストアが破損していたら修復
CRON_FILE="$WORKSPACE/cron/jobs.json"
if [ -f "$CRON_FILE" ]; then
    # nullバイトチェック
    if od -c "$CRON_FILE" 2>/dev/null | grep -q '\\0'; then
        printf '{"version":1,"jobs":[]}' > "$CRON_FILE"
        chmod 600 "$CRON_FILE"
        echo "[FIXED] Cron jobs.json was corrupted (null bytes). Reset to empty."
    else
        echo "[OK] Cron jobs.json is valid"
    fi
fi

echo ""
echo "Done. Consider restarting PicoClaw to apply any config changes."
echo "  kill \$(cat /var/run/picoclaw.pid)  # watchdog will auto-restart"
