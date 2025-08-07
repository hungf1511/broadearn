#!/bin/bash
set -m

export DISPLAY=:0
MASKED_PASSWORD=$(printf '***%.0s' $(seq ${#BROADEARN_PASSWORD}))

echo " "
echo "=== === === === === === === ==="
echo "Starting GUI environment ..."
echo "=== === === === === === === ==="
echo " "

# 1. Start virtual X server
Xvfb :0 -screen 0 1280x720x24 &
sleep 2

# 2. Start window manager
fluxbox &
sleep 2

# 3. Start VNC server
x11vnc -display :0 -nopw -forever -shared -rfbport ${VNC_PORT:-5900} &
sleep 2

# 4. Start noVNC
/web/novnc/utils/novnc_proxy --vnc localhost:${VNC_PORT:-5900} --listen ${NOVNC_PORT:-6080} &
sleep 2

# 5. D-Bus & Gnome Keyring
eval "$(dbus-launch --sh-syntax)"
echo "$BROADEARN_PASSWORD" | gnome-keyring-daemon --unlock --replace

echo " "
echo "=== === === === ==="
echo "Starting BroadEarn..."
echo "=== === === === ==="
echo " "

/opt/BroadEarn/broadearn --no-sandbox &
sleep 8

setup_broadearn() {
  FLAG_FILE="/root/.config/broadearn.setup_done"

  if [ -f "$FLAG_FILE" ]; then
    echo "=== BroadEarn setup already done; skipping ==="
    return 0
  fi

  if [ -z "$BROADEARN_EMAIL" ] || [ -z "$BROADEARN_PASSWORD" ]; then
    echo "=== BROADEARN_EMAIL or BROADEARN_PASSWORD missing ==="
    return 0
  fi

  echo "=== Found login details. Attempting login... ==="

  local BROADEARN_WIN=""
  local attempts=0
  while [ -z "$BROADEARN_WIN" ] && [ $attempts -lt 30 ]; do
    BROADEARN_INFO=$(wmctrl -l | grep -i "BroadEarn\|electron\|app")
    if [ -n "$BROADEARN_INFO" ]; then
      BROADEARN_WIN=$(echo "$BROADEARN_INFO" | head -n 1 | awk '{print $1}')
      break
    fi
    sleep 5
    attempts=$((attempts+1))
  done

  if [ -z "$BROADEARN_WIN" ]; then
    echo "=== BroadEarn window not found. Exiting. ==="
    return 0
  fi

  wmctrl -ia "$BROADEARN_WIN"
  sleep 6

  # Gõ login
  xte "key Tab"; sleep 3
  echo "=== Typing EMAIL: $BROADEARN_EMAIL ==="
  xte "str $BROADEARN_EMAIL"; sleep 3
  xte "key Tab"; sleep 3
  echo "=== Typing PASSWORD: $MASKED_PASSWORD ==="
  xte "str $BROADEARN_PASSWORD"; sleep 3
  xte "key Return"; sleep 5
  xte "key Tab"; sleep 3
  xte "key Tab"; sleep 3
  xte "key Tab"; sleep 3
  xte "key Tab"; sleep 3
  xte "key Return"; sleep 5

  # Gửi ảnh sau khi đăng nhập
  if [[ -n "$DISCORD_WEBHOOK_URL" && "$DISCORD_WEBHOOK_URL" =~ ^https://discord\.com/api/webhooks/ ]]; then
    SCREENSHOT_PATH="/tmp/broadearn_login.png"
    HOSTNAME="$(hostname)"
    scrot -o "$SCREENSHOT_PATH"
    curl -s -o /dev/null -X POST "$DISCORD_WEBHOOK_URL" \
      -F "file=@$SCREENSHOT_PATH" \
      -F "payload_json={\"embeds\": [{\"title\": \"BroadEarn login on host: $HOSTNAME\", \"color\": 5814783}]}"
  else
    echo "[INFO] Discord webhook not configured; skipping screenshot."
  fi

  wmctrl -ic "$BROADEARN_WIN"
  echo "=== BroadEarn setup complete ==="
  mkdir -p "$(dirname "$FLAG_FILE")"
  touch "$FLAG_FILE"
}

setup_broadearn
wait
