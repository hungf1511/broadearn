#!/bin/bash
set -m

MASKED_PASSWORD=$(printf '***%.0s' $(seq ${#BROADEARN_PASSWORD}))
MASKED_WIPTER_PASSWORD=$(printf '***%.0s' $(seq ${#WIPTER_PASSWORD}))


echo " "
echo "=== === === === === === === ==="
echo "Executing custom entrypoint ..."
echo "=== === === === === === === ==="
echo " "

# Launch dbus and keyring
eval "$(dbus-launch --sh-syntax)"
echo "$BROADEARN_PASSWORD" | gnome-keyring-daemon --unlock --replace

run_and_login_app() {
  APP_NAME="$1"
  EMAIL_VAR="$2"
  PASSWORD_VAR="$3"
  MASKED_PASSWORD="$4"
  EXECUTABLE="$5"
  WINDOW_TITLE="$6"
  FLAG_FILE="/root/.config/${APP_NAME}.setup_done"
  SCREENSHOT_PATH="/tmp/${APP_NAME}_login.png"

  echo "=== Starting $APP_NAME... ==="
  $EXECUTABLE --no-sandbox > /dev/null 2>&1 &
  sleep 5

  if [ -f "$FLAG_FILE" ]; then
    echo "\n=== $APP_NAME setup already done; skipping ===\n"
    return 0
  fi

  if [ -z "${!EMAIL_VAR}" ] || [ -z "${!PASSWORD_VAR}" ]; then
    echo "\n=== ${EMAIL_VAR} or ${PASSWORD_VAR} is missing ===\n"
    return 0
  fi

  echo "\n=== Found login details. Starting login for $APP_NAME... ===\n"

  local APP_WIN=""
  local attempts=0
  while [ -z "$APP_WIN" ] && [ $attempts -lt 30 ]; do
    APP_INFO=$(wmctrl -l | grep -i "$WINDOW_TITLE")
    if [ -n "$APP_INFO" ]; then
      APP_WIN=$(echo "$APP_INFO" | head -n 1 | awk '{print $1}')
      break
    fi
    sleep 5
    attempts=$((attempts+1))
  done

  if [ -z "$APP_WIN" ]; then
    echo "\n=== $APP_NAME window not found after waiting. Exiting. ===\n"
    return 0
  fi

  wmctrl -ia "$APP_WIN"
  sleep 6

  # Gõ login
  if [ "$APP_NAME" == "broadearn" ]; then
    xte "key Tab"; sleep 3
    echo "=== Typing EMAIL: ${!EMAIL_VAR} ==="
    xte "str ${!EMAIL_VAR}"; sleep 3
    xte "key Tab"; sleep 3
    echo "=== Typing PASSWORD: $MASKED_PASSWORD ==="
    xte "str ${!PASSWORD_VAR}"; sleep 3
    xte "key Return"; sleep 5
    xte "key Tab"; sleep 3; xte "key Tab"; sleep 3
    xte "key Tab"; sleep 3; xte "key Tab"; sleep 3
    xte "key Return"; sleep 10
  else
    xte "key Tab"; sleep 3
    xte "key Tab"; sleep 3
    xte "key Tab"; sleep 3
    echo "=== Typing EMAIL: ${!EMAIL_VAR} ==="
    xte "str ${!EMAIL_VAR}"; sleep 3
    xte "key Tab"; sleep 3
    echo "=== Typing PASSWORD: $MASKED_PASSWORD ==="
    xte "str ${!PASSWORD_VAR}"; sleep 3
    xte "key Return"; sleep 10
  fi

  if [[ -n "$DISCORD_WEBHOOK_URL" && "$DISCORD_WEBHOOK_URL" =~ ^https://discord\.com/api/webhooks/ ]]; then
    HOSTNAME="$(hostname)"
    scrot -o -D "$DISPLAY" "$SCREENSHOT_PATH"
    curl -s -o /dev/null -X POST "$DISCORD_WEBHOOK_URL" \
      -F "file=@$SCREENSHOT_PATH" \
      -F "payload_json={\"embeds\": [{\"title\": \"$APP_NAME login on host: $HOSTNAME\", \"color\": 5814783}]}"
  else
    echo "[INFO] Discord webhook not configured; skipping screenshot."
  fi

  wmctrl -ic "$APP_WIN"
  echo "=== $APP_NAME setup complete ==="
  mkdir -p "$(dirname "$FLAG_FILE")"
  touch "$FLAG_FILE"
  return 0
}

# Run BroadEarn
run_and_login_app "broadearn" "BROADEARN_EMAIL" "BROADEARN_PASSWORD" "$MASKED_PASSWORD" "/opt/BroadEarn/broadearn --no-sandbox > /dev/null 2>&1" "BroadEarn"

# Wait a bit, then run Wipter
sleep 5
run_and_login_app "wipter" "WIPTER_EMAIL" "WIPTER_PASSWORD" "$MASKED_WIPTER_PASSWORD" "/opt/Wipter/wipter-app" "Wipter"
