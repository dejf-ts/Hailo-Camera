#!/bin/sh
# Minimal standalone script: download Blink camera run.log from the device.
# All parameters are hardcoded; no external config or environment required.
# Saves the log into a temporary directory under the current user's home.

HOST="root@10.0.0.1"
PASSWORD="root"
REMOTE_LOG="/home/root/apps/blink-detector/logs/run.log"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5"
OUTPUT_DIR="${HOME}/tmp"
OUTPUT_FILE="${OUTPUT_DIR}/blink-run.log"

mkdir -p "$OUTPUT_DIR"
sshpass -p "$PASSWORD" scp $SSH_OPTS "$HOST:$REMOTE_LOG" "$OUTPUT_FILE"
echo "Saved to $OUTPUT_FILE"
