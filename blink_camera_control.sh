#!/bin/bash
#
# Standalone script to start and stop the blink-camera application on the Hailo device.
# Connects via SSH using sshpass. No dependency on hailo-skills or load_hailo_env.py.
#
# Usage: blink_camera_control.sh <start|stop|status>
#
# Configuration: edit the defaults below or set environment variables to override.
# Required: sshpass (e.g. apt install sshpass).
#

set -e

# --- Configuration (edit these or set env vars) ---
# SSH target: user@ip (e.g. root@10.0.0.1)
HAILO_HOST="${HAILO_HOST:-root@10.0.0.1}"
# SSH password (used by sshpass)
HAILO_PASSWORD="${HAILO_PASSWORD:-root}"
# Path on the Hailo device where the app is deployed (run_blink_detector.py, resources/, etc.)
HAILO_DEVICE_TARGET_DIR="${HAILO_DEVICE_TARGET_DIR:-/home/root/apps/blink-detector}"
# SSH options (StrictHostKeyChecking=no for non-interactive use)
HAILO_SSH_OPTS="${HAILO_SSH_OPTS:--o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5}"
# HEF (Hailo Executable Format) model path relative to HAILO_DEVICE_TARGET_DIR on device
HEF_PATH="${HEF_PATH:-resources/v8s_640x640_full_ir_01_med_30e.hef}"

# Process name used for start/stop/status
BLINK_PROCESS_PATTERN="run_blink_detector.py"

# --- Helpers ---
CMD="${1:-}"

usage() {
  echo "Usage: $0 <start|stop|status>"
  echo ""
  echo "  start   Start blink-camera on the Hailo device (background, logs to logs/run.log)."
  echo "  stop    Stop the running blink-camera process on the device."
  echo "  status  Show whether blink-camera is running on the device."
  echo ""
  echo "Configuration (edit script or set env): HAILO_HOST, HAILO_PASSWORD, HAILO_DEVICE_TARGET_DIR."
  echo "Example: HAILO_HOST=root@192.168.1.100 HAILO_PASSWORD=secret $0 start"
  echo ""
  echo "If stop fails with 'SSH error': run '$0 status' to test connectivity; check HAILO_HOST and HAILO_PASSWORD."
  exit 1
}

run_ssh() {
  sshpass -p "$HAILO_PASSWORD" ssh $HAILO_SSH_OPTS -n "$HAILO_HOST" "$@"
}

# --- Commands ---
cmd_start() {
  echo "Starting blink-camera on Hailo device ($HAILO_HOST)..."
  run_ssh "cd $HAILO_DEVICE_TARGET_DIR && mkdir -p logs && (setsid env HAILO_MONITOR=1 python3 $BLINK_PROCESS_PATTERN --hef $HEF_PATH > logs/run.log 2>&1 < /dev/null &) && exit" || {
    echo "Warning: Failed to send start command (SSH error)." >&2
    exit 1
  }
  echo "Start command sent. Verifying..."
  sleep 2
  if run_ssh "ps -ef | grep -q '[r]un_blink_detector.py'" 2>/dev/null; then
    echo "Blink-camera is running."
  else
    echo "Warning: Process might not have started; check device logs (e.g. logs/run.log on device)." >&2
  fi
}

cmd_stop() {
  echo "Stopping blink-camera on Hailo device ($HAILO_HOST)..."
  # Run pkill. Some Hailo devices close the SSH connection when pkill runs, so SSH may return 255;
  # we still treat the command as sent and verify with a separate connection.
  run_ssh "pkill -f $BLINK_PROCESS_PATTERN" 2>/dev/null || true
  echo "Stop command sent. Verifying..."
  sleep 2
  if run_ssh "ps -ef | grep -q '[r]un_blink_detector.py'" 2>/dev/null; then
    echo "Warning: Process still running." >&2
  else
    echo "Blink-camera stopped."
  fi
}

cmd_status() {
  if run_ssh "ps -ef | grep '[r]un_blink_detector.py'" 2>/dev/null; then
    echo "Blink-camera is running on $HAILO_HOST."
  else
    echo "Blink-camera is not running on $HAILO_HOST."
  fi
}

# --- Main ---
if [ -z "$CMD" ]; then
  usage
fi

case "$CMD" in
  start)  cmd_start ;;
  stop)   cmd_stop ;;
  status) cmd_status ;;
  -h|--help) usage ;;
  *)
    echo "Unknown command: $CMD" >&2
    usage
    ;;
esac
