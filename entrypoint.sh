#!/bin/bash

NTFY_TOPIC="${NTFY_TOPIC:-yans-proton}"
BORE_SERVER="${BORE_SERVER:-bore.pub}"
ROOT_PASS="${ROOT_PASS:-Kosay378%}"
HERMES_CMD="${HERMES_CMD:-}"
HERMES_AUTOSTART="${HERMES_AUTOSTART:-false}"

# ── ANSI Colors ─────────────────────────
CY='\033[1;36m'
PK='\033[1;35m'
WH='\033[1;37m'
RS='\033[0m'

# ── Banner (mobile-friendly) ─────────────
print_banner() {
  printf "\n"
  printf "${CY}╔════════════════════════╗${RS}\n"
  printf "${CY}║${RS}  ${CY}▓ ▓ ▓▓▓ ▓  ▓  ▓▓▓ ▓▓▓${RS}  ${CY}║${RS}\n"
  printf "${CY}║${RS}  ${CY}▓ ▓ ▓   ▓  ▓  ▓ ▓ ▓  ${RS}  ${CY}║${RS}\n"
  printf "${CY}║${RS}  ${CY}▓▓▓ ▓▓  ▓  ▓  ▓▓▓ ▓▓ ${RS}  ${CY}║${RS}\n"
  printf "${CY}║${RS}  ${PK}▓ ▓ ▓   ▓  ▓  ▓ ▓ ▓  ${RS}  ${CY}║${RS}\n"
  printf "${CY}║${RS}  ${PK}▓ ▓ ▓▓▓ ▓▓▓  ▓▓▓ ▓▓▓${RS}  ${CY}║${RS}\n"
  printf "${CY}╠════════════════════════╣${RS}\n"
  printf "${CY}║${RS}  ${WH}Devops${RS}                  ${CY}║${RS}\n"
  printf "${CY}║${RS}  ${PK}c2026 devculture linux${RS}  ${CY}║${RS}\n"
  printf "${CY}╚════════════════════════╝${RS}\n"
  printf "\n"
}

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# ── Notify biasa (tanpa tombol) ──────────
notify() {
  local title="$1" body="$2" priority="${3:-default}" tags="${4:-computer}"
  curl -s --max-time 10 --retry 2 \
    -X POST "https://ntfy.sh/$NTFY_TOPIC" \
    -H "Title: $title" \
    -H "Priority: $priority" \
    -H "Tags: $tags" \
    -H "Content-Type: text/plain" \
    -d "$body" >/dev/null 2>&1 || true
}

# ── Notify dengan tombol Restart ─────────
# Klik tombol → kirim pesan "restart" ke topik → VPS restart otomatis
notify_ssh() {
  local title="$1" body="$2" priority="${3:-high}" tags="${4:-tada,key,computer}"
  curl -s --max-time 10 --retry 2 \
    -X POST "https://ntfy.sh/$NTFY_TOPIC" \
    -H "Title: $title" \
    -H "Priority: $priority" \
    -H "Tags: $tags" \
    -H "Content-Type: text/plain" \
    -H "Actions: http, Restart VPS, https://ntfy.sh/${NTFY_TOPIC}, method=POST, headers.Title=Restart VPS, body=restart" \
    -d "$body" >/dev/null 2>&1 || true
}

# ── Watch Restart Command ─────────────────
# Poll ntfy setiap 10 detik, jika ada pesan "restart" → container exit → Railway restart
watch_restart() {
  log "=== Restart Watcher aktif (ketik 'restart' di ntfy) ==="
  local last_seen
  last_seen=$(date +%s)

  while true; do
    sleep 10
    local now
    now=$(date +%s)

    local msgs
    msgs=$(curl -s --max-time 8 \
      "https://ntfy.sh/${NTFY_TOPIC}/json?poll=1&since=${last_seen}" \
      2>/dev/null || echo "")
    last_seen=$now

    if echo "$msgs" | grep -qi '"message":"restart"'; then
      log "*** Restart command diterima! Container akan exit → Railway restart ***"
      notify "Restarting VPS..." \
"Restart command diterima dari ntfy!
Container akan restart dalam 3 detik...

c2026 devculture linux" \
      "urgent" "arrows_counterclockwise,warning"
      sleep 3
      # Exit dengan kode 1 agar Railway restart otomatis (policy: ON_FAILURE)
      kill -TERM 1 2>/dev/null || exit 1
    fi
  done
}

# ── Bore Tunnel ───────────────────────────
start_bore() {
  log "=== Bore Tunnel ==="
  local reconnect_count=0

  while true; do
    log "Menghubungkan ke $BORE_SERVER... (reconnect #${reconnect_count})"
    > /tmp/bore.log

    bore local 22 --to "$BORE_SERVER" 2>&1 | tee /tmp/bore.log &
    BORE_PID=$!

    local port=""
    local i=0
    while [ $i -lt 30 ]; do
      sleep 1; i=$((i+1))
      port=$(grep -oP 'listening at [^:]+:\K[0-9]+' /tmp/bore.log 2>/dev/null | head -1)
      [ -n "$port" ] && break
    done

    if [ -n "$port" ]; then
      log "Bore aktif! Port: $port (reconnect #${reconnect_count})"

      if [ "$reconnect_count" -eq 0 ]; then
        # Boot pertama — notif lengkap dengan tombol Restart
        notify_ssh "VPS ONLINE - Devops" \
"▓▓▓ DEVOPS VPS ONLINE ▓▓▓
c2026 devculture linux

SSH (tidak perlu install apapun):
ssh root@${BORE_SERVER} -p ${port}

Password: ${ROOT_PASS}

Klik [Restart VPS] untuk restart cepat!
Atau kirim pesan: restart" \
        "high" "tada,key,computer"
      else
        # Reconnect — notif singkat dengan port baru + tombol Restart
        notify_ssh "Bore Reconnected - Port Baru!" \
"Bore tunnel reconnected!

Port baru: ${port}
SSH: ssh root@${BORE_SERVER} -p ${port}

Password: ${ROOT_PASS}

Reconnect #${reconnect_count}" \
        "high" "arrows_counterclockwise,key"
      fi

      reconnect_count=$((reconnect_count+1))
    else
      log "Bore gagal konek. Log:"
      head -5 /tmp/bore.log | while read -r l; do log "  $l"; done
      if [ "$reconnect_count" -eq 0 ]; then
        notify "Bore Gagal" "Gagal konek bore.pub. Retry 15s..." "low" "warning"
      fi
    fi

    wait $BORE_PID 2>/dev/null || true
    log "Bore disconnect. Reconnect 15s..."
    sleep 15
  done
}

# ── Monitor setiap 5 menit ────────────────
monitor_loop() {
  while true; do
    sleep 300
    local UPTIME PORT
    UPTIME=$(uptime -p 2>/dev/null || echo 'n/a')
    PORT=$(grep -oP 'listening at [^:]+:\K[0-9]+' /tmp/bore.log 2>/dev/null | tail -1 || echo '?')
    notify_ssh "Devops VPS Status" \
"c2026 devculture linux

Uptime : $UPTIME
SSH    : ssh root@${BORE_SERVER} -p $PORT

Klik [Restart VPS] atau kirim: restart" \
    "min" "bar_chart"
  done
}

# ── Boot ──────────────────────────────────
print_banner
log "ntfy topic : $NTFY_TOPIC"
log "bore server: $BORE_SERVER"
log "Restart    : kirim 'restart' ke ntfy/${NTFY_TOPIC}"

notify "Devops VPS Starting..." \
"c2026 devculture linux

VPS sedang boot...
SSH via bore segera tersedia!

Untuk restart: kirim pesan 'restart'
ke ntfy topic: ${NTFY_TOPIC}" \
"default" "rocket"

echo "root:${ROOT_PASS}" | chpasswd 2>/dev/null || true
/usr/sbin/sshd && log "SSH daemon started"

# ── Supervisord untuk hermes-gateway ─────
start_supervisor() {
  log "=== Supervisord (service manager) ==="

  # Set env vars agar hermes.conf bisa baca
  export HERMES_CMD="${HERMES_CMD:-echo 'HERMES_CMD belum diset. Set di Railway env vars.'}"
  export HERMES_AUTOSTART="${HERMES_AUTOSTART:-false}"

  # Mulai supervisord sebagai daemon
  supervisord -c /etc/supervisord.conf
  log "supervisord started."

  if [ -n "${HERMES_CMD}" ] && [ "${HERMES_CMD}" != "echo 'HERMES_CMD belum diset. Set di Railway env vars.'" ]; then
    log "Hermes: HERMES_CMD=${HERMES_CMD}"
    log "Hermes autostart: ${HERMES_AUTOSTART}"
    if [ "${HERMES_AUTOSTART}" = "true" ]; then
      log "Hermes akan autostart via supervisord"
    else
      log "Hermes TIDAK autostart. SSH lalu: supervisorctl start hermes-gateway"
    fi
  else
    log "HERMES_CMD belum diset. Set di Railway env vars:"
    log "  HERMES_CMD=<command untuk jalankan hermes>"
    log "  HERMES_AUTOSTART=true  (agar autostart)"
  fi

  log "Manage hermes via SSH:"
  log "  supervisorctl status hermes-gateway"
  log "  supervisorctl start hermes-gateway"
  log "  supervisorctl stop hermes-gateway"
  log "  supervisorctl restart hermes-gateway"
  log "  supervisorctl tail -f hermes-gateway"
}

start_supervisor

# HTTP placeholder
python3 -c "
import http.server, socketserver, threading, time
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        self.send_response(200); self.end_headers()
        self.wfile.write(b'Devops VPS Online - c2026 devculture linux')
threading.Thread(target=lambda: socketserver.TCPServer(('',80),H).serve_forever(), daemon=True).start()
time.sleep(86400)
" &

sleep 2

# Jalankan semua loop paralel
watch_restart &
start_bore &
monitor_loop &

log "Health check port 8080"
exec python3 -c "
import http.server, socketserver
h = http.server.SimpleHTTPRequestHandler
h.log_message = lambda *a: None
socketserver.TCPServer(('', 8080), h).serve_forever()
"
