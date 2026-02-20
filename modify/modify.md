# MaixCAMのカスタマイズ内容

ここにはMaixCAMにPicoClawをインストールして以降にカスタマイズした内容を記録する。  
新規に作成・変更したファイルはこのディレクトリ内に保存済みで、別のMaixCAMでも再現できる。

## ファイル構成

このディレクトリ内のファイルは MaixCAM のルートファイルシステム `/` を基点としたパスに対応する。

```txt
modify/
├── modify.md                                       このファイル
├── etc/
│   └── init.d/
│       ├── S98tailscale                            → /etc/init.d/S98tailscale
│       └── S99picoclaw                             → /etc/init.d/S99picoclaw
└── root/
    ├── picoclaw-watchdog.sh                        → /root/picoclaw-watchdog.sh
    └── .picoclaw/
        └── workspace/
            ├── camera_snap.sh                      → /root/.picoclaw/workspace/camera_snap.sh
            ├── camera_snap_discode.py              → /root/.picoclaw/workspace/camera_snap_discode.py
            └── skills/
                └── camera/
                    └── SKILL.md                    → /root/.picoclaw/workspace/skills/camera/SKILL.md
```

---

## 再現手順（前提: PicoClaw バイナリ `/root/picoclaw` インストール済み）

### 1. Tailscale の設定

ローカルネットワーク外からもSSH接続できるように Tailscale をセットアップする。

**インストール:**

1. <https://pkgs.tailscale.com/stable/#static> から最新RISC-V向けバイナリ（例: `tailscale_1.94.2_riscv64.tgz`）をダウンロード
2. MaixCAM の `/usr/bin/` に転送:
3. 
   ```bash
   scp tailscale_1.94.2_riscv64/tailscale root@<MaixCAMのIP>:/usr/bin/
   scp tailscale_1.94.2_riscv64/tailscaled root@<MaixCAMのIP>:/usr/bin/
   ```
4. SSH接続して認証:
   ```bash
   tailscaled --state=/var/lib/tailscale/tailscaled.state &
   tailscale up
   ```
   表示される認証URLをブラウザで開いて Tailscale アカウントで認証。

**自動起動化:**

```bash
scp ./modify/etc/init.d/S98tailscale root@<MaixCAMのIP>:/etc/init.d/
ssh root@<MaixCAMのIP> "chmod +x /etc/init.d/S98tailscale"
```

---

### 2. ウォッチドッグ + 自動起動 の設定

PicoClaw をウォッチドッグ経由で起動し、クラッシュ・ハング時に自動再起動させる。

**ファイル転送:**

```bash
scp ./modify/root/picoclaw-watchdog.sh root@<MaixCAMのIP>:/root/
scp ./modify/etc/init.d/S99picoclaw root@<MaixCAMのIP>:/etc/init.d/
```

**パーミッション設定:**

```bash
ssh root@<MaixCAMのIP> "chmod +x /root/picoclaw-watchdog.sh && chmod +x /etc/init.d/S99picoclaw && sed -i 's/\r//' /root/picoclaw-watchdog.sh"
```

**動作確認:**

```bash
ssh root@<MaixCAMのIP> "/etc/init.d/S99picoclaw start && sleep 3 && ps aux | grep picoclaw"
```

**ウォッチドッグの仕組み:**

- 60秒ごとにプロセス死活確認（`kill -0`）→ クラッシュ検知で即時再起動
- 起動後60分以上経過かつ heartbeat.log が60分以上更新なし → ハング検知で再起動
- 再起動時に `udevadm` プロセスのリークを防ぐため `killall udevadm` を実行
- 起動・再起動時に Discord Bot API で通知を送信

---

### 3. config.json の変更

```bash
ssh root@<MaixCAMのIP> "sed -i 's/\"monitor_usb\": true/\"monitor_usb\": false/' /root/.picoclaw/config.json"
```

> **理由**: `monitor_usb: true` にすると PicoClaw 再起動のたびに `udevadm monitor` プロセスがリークし、最終的に OOM で launcher が強制終了される（`run app failed, code:-1` エラー）。

---

### 4. HEARTBEAT.md の変更（I2C チェックの削除）

```bash
ssh root@<MaixCAMのIP> "sed -i '/- Check I2C devices/d' /root/.picoclaw/workspace/HEARTBEAT.md"
```

> **理由**: MaixCAM の Hynitron タッチスクリーンドライバーが I2C タイムアウトエラーを毎秒 dmesg に出力し続けるため、Heartbeat の「I2C デバイス確認」タスクが常に失敗してログを汚染する。

---

### 5. カメラスキルの設置

Discord に写真を送るカメラスキルを設置する。  
Discordの接続に必要なwebhook以外の設定は、 `/root/.picoclaw/config.json` に済ませてあるものとする。

**ファイル転送:**

```bash
scp ./modify/root/.picoclaw/workspace/camera_snap.sh root@<MaixCAMのIP>:/root/.picoclaw/workspace/
scp ./modify/root/.picoclaw/workspace/camera_snap_discode.py root@<MaixCAMのIP>:/root/.picoclaw/workspace/
ssh root@<MaixCAMのIP> "mkdir -p /root/.picoclaw/workspace/skills/camera"
scp ./modify/root/.picoclaw/workspace/skills/camera/SKILL.md root@<MaixCAMのIP>:/root/.picoclaw/workspace/skills/camera/
```

**パーミッション設定と改行コード修正:**

```bash
ssh root@<MaixCAMのIP> "
  chmod +x /root/.picoclaw/workspace/camera_snap.sh
  sed -i 's/\r//' /root/.picoclaw/workspace/camera_snap.sh
  sed -i 's/\r//' /root/.picoclaw/workspace/camera_snap_discode.py
"
```

**WEBHOOK URLの更新:**

`camera_snap.sh` の `WEBHOOK=` 行を自分の Discord Webhook URL に書き換える:

```bash
ssh root@<MaixCAMのIP> 'sed -i "s|WEBHOOK=.*|WEBHOOK=\"https://discordapp.com/api/webhooks/<ID>/<TOKEN>\"|" /root/.picoclaw/workspace/camera_snap.sh'
```

**動作確認:**

```bash
ssh root@<MaixCAMのIP> "bash /root/.picoclaw/workspace/camera_snap.sh"
# → "送信成功" が表示され Discord に写真が届けばOK
```

**カメラスキルの仕組み:**

1. Python (`camera_snap_discode.py`): `launcher_daemon` と `launcher` を SIGTERM で停止し、プロセス消滅を最大8秒待機。ISP を解放してから `camera.Camera()` で撮影。撮影後 `del cam; gc.collect()` でリソース解放して終了
2. Shell (`camera_snap.sh`): Python 終了後 2秒待機してから `curl` で Discord Webhook にアップロード。完了後 `launcher_daemon` を再起動して LCD 画面を復帰

> **注意**: カメラ使用中に Python を SIGKILL で強制終了すると `soph_ive` カーネルモジュールの参照カウントが -1 になりカメラ不能状態になる。この状態は reboot のみで回復可能。通常の正常終了では発生しない。

---

## 既知の問題・注意事項

| 問題 | 原因 | 対処 |
| ---- | ---- | ---- |
| `udevadm` プロセスリーク → OOM → `run app failed` | PicoClaw の `monitor_usb` 機能 | `config.json` で `monitor_usb: false` |
| I2C タイムアウトが dmesg に毎秒出力 | Hynitron タッチスクリーンドライバー（ハードウェア起因） | `HEARTBEAT.md` から I2C チェック削除 |
| heartbeat staleness 誤検知 | PicoClaw 起動直後は heartbeat.log が古い | watchdog が起動から60分未満の場合はチェックをスキップ |
| カメラ撮影でフリーズ（撮影前） | launcher が ISP を常時保持し `camera.Camera()` がハング | `killall launcher_daemon && killall launcher` + プロセス消滅待機 |
| curl `HTTP 000` でアップロード失敗 | Python stdout に MaixPy 初期化ログが混入し curl がファイルを開けない | スナップショットパスをシェル側でハードコード + Python stdout を `/dev/null` に捨てる |
| `soph_ive` 参照カウント -1 でカメラ不能 | カメラ動作中の SIGKILL | reboot で回復。通常動作では発生しない |
