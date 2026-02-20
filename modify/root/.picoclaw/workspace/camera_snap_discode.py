#!/usr/bin/env python3
# MaixCAM camera capture only. HTTP upload is handled by the caller after this exits.
import sys
import gc
import subprocess
import time

SNAPSHOT_PATH = "/root/.picoclaw/workspace/snapshot.jpg"

def main():
    # Stop launcher_daemon first (prevents auto-restart of launcher),
    # then stop launcher to release ISP/camera hardware.
    # Use SIGTERM (not SIGKILL) so launcher can clean up module references properly.
    subprocess.run(["killall", "launcher_daemon"],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["killall", "launcher"],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    # Wait for launcher to fully exit (up to 8 seconds) so ISP/kernel modules are released
    for _ in range(8):
        result = subprocess.run(["pgrep", "-x", "launcher"],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if result.returncode != 0:
            break
        time.sleep(1)
    else:
        # launcher still running after 8s - force kill
        subprocess.run(["killall", "-9", "launcher"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(1)

    try:
        from maix import camera
        cam = camera.Camera(640, 480)
        img = cam.read()
        img.save(SNAPSHOT_PATH)
    except Exception as e:
        print(f"Camera error: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        # Explicitly release camera/ISP before exiting
        try:
            del cam
        except Exception:
            pass
        gc.collect()

    print(SNAPSHOT_PATH)

if __name__ == "__main__":
    main()
