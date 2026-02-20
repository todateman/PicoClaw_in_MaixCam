---
name: camera
description: Take a photo with MaixCAM and send it to Discord.
homepage: https://github.com/sipeed/MaixPy
metadata: {"nanobot":{"emoji":"📷","requires":{"bins":["python3","curl"]}}}
---

# Camera

Take a photo with MaixCAM camera and send it to Discord.

## Usage

```bash
bash /root/.picoclaw/workspace/camera_snap.sh
```

Run this command to capture and send the image to Discord in one step.

## Trigger phrases

When the user says any of the following, run the command above immediately without asking for confirmation:

- カメラ画像を送って
- 写真撮って
- 撮影して
- 画像送って
- カメラ
- snapshot
- camera

## Steps

1. Run `bash /root/.picoclaw/workspace/camera_snap.sh` via shell
2. On success: output will show "送信成功"
3. On failure: report the error message to the user

## How it works

- Step 1 (Python): Stops the launcher to release ISP, captures photo, releases camera, exits
- Step 2 (curl): After Python fully exits, uploads snapshot.jpg to Discord webhook

## Troubleshooting

Camera not found:
```bash
ls /dev/video*
```

Script not found:
```bash
ls /root/.picoclaw/workspace/camera_snap*.{py,sh}
```

Discord send failed:
```bash
curl -s https://discord.com > /dev/null && echo "OK" || echo "NG"
```
