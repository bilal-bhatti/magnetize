#!/bin/bash
# send-magnet.sh — forwards one magnet link to a remote Transmission daemon and
# prints a one-line status to stdout. Magnetize.app turns that line into a
# notification, so the alert carries the app's own icon (not Script Editor's).
#
# Audit points:
#   - The ONLY network call is `curl` to $HOST. Nothing else leaves the machine.
#   - Username + password live in the macOS Keychain. On first run (or if the
#     entry is missing) it asks for them via a dialog and saves them; after that
#     every magnet click is silent. Wrong credentials are detected, cleared, and
#     re-prompted automatically.
#
# Invoked by Magnetize.app with the magnet URL as the first argument.
# Always exits 0 — the status is conveyed by the printed line, not the exit code.

KEYCHAIN_SERVICE="magnetize"
LOG="$HOME/Library/Logs/Magnetize.log"
CONFIG_DIR="$HOME/Library/Application Support/Magnetize"
CONFIG_FILE="$CONFIG_DIR/rpc-url"          # plain text, one line: the RPC URL
DEFAULT_HOST="http://localhost:9091/transmission/rpc"

# ask <prompt> <default-answer> <extra-opts e.g. 'with hidden answer'>
ask() { /usr/bin/osascript -e "tell application \"System Events\" to text returned of (display dialog \"$1\" default answer \"$2\" $3 with title \"Magnetize\")" 2>/dev/null; }

MAGNET="$1"
[ -z "$MAGNET" ] && { echo "No magnet URL received"; exit 0; }

# --- RPC URL: read from config file, or prompt (pre-filled) and save ----------
# Change servers later by editing this file (no rebuild), or delete it to be
# re-prompted:  ~/Library/Application Support/Magnetize/rpc-url
HOST=""
[ -f "$CONFIG_FILE" ] && IFS= read -r HOST < "$CONFIG_FILE"
if [ -z "$HOST" ]; then
  HOST="$(ask 'Transmission RPC URL:' "$DEFAULT_HOST" '')"
  [ -z "$HOST" ] && exit 0
  /bin/mkdir -p "$CONFIG_DIR"
  printf '%s\n' "$HOST" > "$CONFIG_FILE"
fi

# --- credentials: read from Keychain, or prompt + store on first use ----------
read_kc_password() { /usr/bin/security find-generic-password -s "$KEYCHAIN_SERVICE" -w 2>/dev/null; }
read_kc_username() {
  /usr/bin/security find-generic-password -s "$KEYCHAIN_SERVICE" 2>/dev/null \
    | /usr/bin/sed -n 's/^[[:space:]]*"acct"<blob>="\(.*\)"$/\1/p'
}

USERNAME="$(read_kc_username)"
PASSWORD="$(read_kc_password)"

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
  USERNAME="$(ask 'Transmission username:' '' '')"
  [ -z "$USERNAME" ] && exit 0                      # cancelled / empty
  PASSWORD="$(ask 'Transmission password:' '' 'with hidden answer')"
  [ -z "$PASSWORD" ] && exit 0
  /usr/bin/security add-generic-password -s "$KEYCHAIN_SERVICE" -a "$USERNAME" -w "$PASSWORD" -U >/dev/null 2>&1
fi

CREDS="$USERNAME:$PASSWORD"

# --- handshake: status line + session id, parsed from clean header dump -------
HEADERS="$(/usr/bin/curl -s -D - -o /dev/null -u "$CREDS" "$HOST")"
CODE="$(printf '%s' "$HEADERS" | /usr/bin/awk 'NR==1{print $2}')"
SID="$(printf '%s' "$HEADERS" \
       | /usr/bin/sed -n 's/^[Xx]-[Tt]ransmission-[Ss]ession-[Ii]d: //p' \
       | /usr/bin/tr -d '\r\n')"

if [ "$CODE" = "401" ]; then
  /usr/bin/security delete-generic-password -s "$KEYCHAIN_SERVICE" >/dev/null 2>&1
  echo "Wrong credentials — cleared. Click the magnet again to re-enter."
  exit 0
fi

# --- add ----------------------------------------------------------------------
ESCAPED="$(printf '%s' "$MAGNET" | /usr/bin/sed 's/\\/\\\\/g; s/"/\\"/g')"
BODY="{\"method\":\"torrent-add\",\"arguments\":{\"filename\":\"$ESCAPED\"}}"

RESP="$(/usr/bin/curl -s -u "$CREDS" \
        -H "X-Transmission-Session-Id: $SID" \
        -H 'Content-Type: application/json' \
        --data-binary "$BODY" \
        "$HOST")"

case "$RESP" in
  *'"result":"success"'*'torrent-duplicate'*) echo "Already in Transmission" ;;
  *'"result":"success"'*)                      echo "Sent to Transmission" ;;
  *) echo "Failed — see ~/Library/Logs/Magnetize.log"
     printf '%s  %s\n   %s\n\n' "$(date)" "$MAGNET" "$RESP" >> "$LOG" ;;
esac
exit 0
