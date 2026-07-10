#!/bin/bash
# Notifikasi ntfy saat ada SSH login
NTFY_TOPIC="${NTFY_TOPIC:-yans-proton}"

if [ -n "$SSH_CLIENT" ]; then
  CLIENT_IP="${SSH_CLIENT%% *}"
  curl -s --max-time 8 -X POST "https://ntfy.sh/$NTFY_TOPIC" \
    -H "Title: SSH Login - Devops VPS" \
    -H "Priority: high" \
    -H "Tags: key,warning" \
    -d "User  : ${USER:-root}
IP    : ${CLIENT_IP:-unknown}
TTY   : ${SSH_TTY:-local}
Waktu : $(date '+%Y-%m-%d %H:%M:%S')
VPS   : Devops | c2026 devculture linux" > /dev/null 2>&1 || true
fi
