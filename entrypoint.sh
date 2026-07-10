#!/bin/bash

NTFY_TOPIC="${NTFY_TOPIC:-yans-proton}"
BORE_SERVER="${BORE_SERVER:-bore.pub}"
ROOT_PASS="${ROOT_PASS:-craxid}"

# ── ANSI Colors ─────────────────────────
CY='\033[1;36m'   # Cyan bold
PK='\033[1;35m'   # Pink/Magenta bold
WH='\033[1;37m'   # White bold
RS='\033[0m'      # Reset

# ── Mobile-Friendly Banner ───────────────
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

notify() {
  local title="$1" body="$2" priority="${3:-default}" tags="${4:-computer}"
  curl -s --max-time 10 --retry 2 \
    -X POST "https://ntfy.sh/$NTFY_TOPIC" \
    -H "Title: $title" -H "Priority: $priority" \
    -H "Tags: $tags" -H "Content-Type: text/plain" \
    -d "$body" >/dev/null 2>&1 || true
}

# ── Bore Tunnel ──────────────────────────
start_bore() {
  log "=== Bore Tunnel ==="
  while true; do
    log "Menghubungkan ke $BORE_SERVER..."
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
      log "Bore aktif! Port: $port"
      notify "SSH SIAP - Devops VPS" \
"▓▓▓ DEVOPS VPS ONLINE ▓▓▓
c2026 devculture linux

SSH (tidak perlu install apapun):
ssh root@${BORE_SERVER} -p ${port}

Password: ${ROOT_PASS}

Catatan: port berubah jika VPS restart" \
      "high" "tada,key,computer"
    else
      log "Bore gagal konek. Log: $(head -5 /tmp/bore.log 2>/dev/null)"
      notify "Bore Gagal" "Gagal konek bore. Retry 30s..." "low" "warning"
    fi

    wait $BORE_PID 2>/dev/null || true
    log "Bore disconnect. Reconnect 15s..."
    sleep 15
  done
}

# ── Monitor Loop ─────────────────────────
monitor_loop() {
  while true; do
    sleep 300
    local UPTIME PORT
    UPTIME=$(uptime -p 2>/dev/null || echo 'n/a')
    PORT=$(grep -oP 'listening at [^:]+:\K[0-9]+' /tmp/bore.log 2>/dev/null | tail -1 || echo '?')
    notify "Devops VPS Status" \
"c2026 devculture linux

Up: $UPTIME
SSH: ssh root@${BORE_SERVER} -p $PORT" \
    "min" "bar_chart"
  done
}

# ── Boot ─────────────────────────────────
print_banner
log "ntfy topic : $NTFY_TOPIC"
log "bore server: $BORE_SERVER"

notify "Devops VPS Starting..." \
"c2026 devculture linux

VPS sedang boot...
SSH via bore segera tersedia!" \
"default" "rocket"

echo "root:${ROOT_PASS}" | chpasswd 2>/dev/null || true
/usr/sbin/sshd && log "SSH daemon started"

# HTTP placeholder port 80
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

start_bore &
monitor_loop &

log "Health check port 8080"
exec python3 -c "
import http.server, socketserver
h = http.server.SimpleHTTPRequestHandler
h.log_message = lambda *a: None
socketserver.TCPServer(('', 8080), h).serve_forever()
"
