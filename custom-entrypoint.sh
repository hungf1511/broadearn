#!/bin/bash
set -m

MASKED_PASSWORD=$(printf '***%.0s' $(seq ${#BROADEARN_PASSWORD}))

echo " "
echo "=== === === === === === === ==="
echo "Executing custom entrypoint ..."
echo "=== === === === === === === ==="
echo " "

eval "$(dbus-launch --sh-syntax)"
echo "$BROADEARN_PASSWORD" | gnome-keyring-daemon --unlock --replace

setup_wipter() {
  sleep 5
  FLAG_FILE="/root/.config/wipter.setup_done"

  if [ -f "$FLAG_FILE" ]; then
    echo " "
    echo "=== Wipter setup already done; skipping ==="
    echo " "
    return 0
  fi

  if [ -z "$BROADEARN_EMAIL" ] || [ -z "$BROADEARN_PASSWORD" ]; then
    echo " "
    echo "=== BROADEARN_EMAIL or BROADEARN_PASSWORD is missing ==="
    echo " "
    return 0
  fi

  echo " "
  echo "=== Found login details. Starting login... ==="
  echo " "

  local BROADEARN_WIN=""
  local attempts=0
  while [ -z "$BROADEARN_WIN" ] && [ $attempts -lt 30 ]; do
    wmctrl -l
    BROADEARN_INFO=$(wmctrl -l | grep -i "BroadEarn\|electron\|app")
    if [ -n "$BROADEARN_INFO" ]; then
      BROADEARN_INFO=$(echo "$BROADEARN_INFO" | head -n 1 | awk '{print $1}')
      break
    fi
    sleep 5
    attempts=$((attempts+1))
  done

  if [ -z "$BROADEARN_WIN" ]; then
    echo " "
    echo "=== BroadEarn window not found after waiting. Exiting. ==="
    echo " "
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
  

  # Chụp ảnh gửi Discord
  if [[ -n "$DISCORD_WEBHOOK_URL" && "$DISCORD_WEBHOOK_URL" =~ ^https://discord\.com/api/webhooks/ ]]; then
    SCREENSHOT_PATH="/tmp/wipter_login.png"
    HOSTNAME="$(hostname)"
    scrot -o -D "$DISPLAY" "$SCREENSHOT_PATH"
    curl -s -o /dev/null -X POST "$DISCORD_WEBHOOK_URL" \
      -F "file=@$SCREENSHOT_PATH" \
      -F "payload_json={\"embeds\": [{\"title\": \"Wipter login on host: $HOSTNAME\", \"color\": 5814783}]}"
  else
    echo "[INFO] Discord webhook not configured; skipping screenshot."
  fi

  # Đóng cửa sổ Wipter
  wmctrl -ic "$BROADEARN_WIN"
  echo "=== Wipter setup complete ==="
  mkdir -p "$(dirname "$FLAG_FILE")"
  touch "$FLAG_FILE"
  return 0
}

echo "=== Starting Wipter... ==="
/opt/Wipter/wipter-app &
setup_wipter
