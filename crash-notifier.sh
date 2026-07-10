#!/bin/bash
# ================================================================
# supervisord event listener — kirim notif ntfy saat service crash
# Dipanggil otomatis oleh supervisord, bukan dijalankan manual
# ================================================================

NTFY_TOPIC="${NTFY_TOPIC:-yans-proton}"
BORE_SERVER="${BORE_SERVER:-bore.pub}"

notify_crash() {
  local process="$1"
  local state="$2"
  local extra="${3:-}"

  local port
  port=$(grep -oP 'listening at [^:]+:\K[0-9]+' /tmp/bore.log 2>/dev/null | tail -1 || echo "?")

  curl -s --max-time 10 --retry 2 \
    -X POST "https://ntfy.sh/$NTFY_TOPIC" \
    -H "Title: ⚠️ Service Crash: ${process}" \
    -H "Priority: high" \
    -H "Tags: warning,rotating_light,arrows_counterclockwise" \
    -H "Content-Type: text/plain" \
    -d "Service '${process}' ${state}!

Supervisord akan restart otomatis dalam beberapa detik.

${extra}
SSH: ssh root@${BORE_SERVER} -p ${port}

Cek log:
  tail -f /tmp/hermes.log
  tail -f /tmp/hermes-error.log
  supervisorctl status

c2026 devculture linux" >/dev/null 2>&1 || true
}

# ── supervisord event listener protocol ──────────────────────────
# supervisord mengirim event ke stdin, kita baca dan balas RESULT 2\nOK
while true; do
  # Kirim READY ke supervisord
  printf "READY\n"

  # Baca header event: "ver:3.0 server:supervisor serial:N pool:crash-notifier poolserial:N eventname:EVENT_TYPE len:N"
  read -r header
  [ -z "$header" ] && sleep 1 && continue

  # Ambil panjang payload dari header
  payload_len=$(echo "$header" | grep -oP 'len:\K[0-9]+' || echo "0")

  # Baca payload
  payload=""
  if [ "$payload_len" -gt 0 ]; then
    payload=$(dd bs=1 count="$payload_len" 2>/dev/null)
  fi

  # Ambil event name dari header
  event_name=$(echo "$header" | grep -oP 'eventname:\K\S+' || echo "")

  # Proses event crash
  if [ "$event_name" = "PROCESS_STATE_EXITED" ] || [ "$event_name" = "PROCESS_STATE_FATAL" ]; then
    process=$(echo "$payload" | grep -oP 'processname:\K\S+' || echo "unknown")
    expected=$(echo "$payload" | grep -oP 'expected:\K[0-9]+' || echo "0")

    # Hanya notif jika exit tidak expected (crash) — expected=0 berarti crash
    if [ "$expected" = "0" ]; then
      notify_crash "$process" "CRASH (exit tidak normal)" "State: ${event_name}"
    fi
  fi

  if [ "$event_name" = "PROCESS_STATE_FATAL" ]; then
    process=$(echo "$payload" | grep -oP 'processname:\K\S+' || echo "unknown")
    notify_crash "$process" "FATAL (gagal restart berkali-kali)" "Supervisord menyerah restart. Cek config dan log!"
  fi

  # Balas supervisord bahwa event sudah diproses
  printf "RESULT 2\nOK"
done
