# rairu-devculture — Devops VPS

VPS Docker yang berjalan di Railway dengan SSH via bore tunnel.  
Notifikasi SSH dan status dikirim ke **ntfy** topic `yans-proton`.

---

## 🚀 Cara SSH Masuk

**1. Tunggu notifikasi di ntfy (`yans-proton`)**  
Setiap kali VPS online atau bore reconnect, kamu dapat notifikasi dengan port SSH terbaru.

**2. Koneksi SSH (tidak perlu install apapun di client):**
```bash
ssh root@bore.pub -p <PORT_DARI_NTFY>
# Password: lihat Railway env var ROOT_PASS
```

> Port berubah setiap kali bore reconnect. Selalu cek ntfy untuk port terbaru.

---

## 🔄 Cara Restart VPS

**Cara 1 — Tombol di notifikasi ntfy:**  
Setiap notifikasi ada tombol **[Restart VPS]** — tinggal klik.

**Cara 2 — Kirim pesan ke ntfy:**
```
Topic  : yans-proton
Pesan  : restart
```
VPS akan restart dalam ~10 detik.

---

## ⚙️ Hermes Gateway Telegram

Hermes dikelola oleh **supervisord** (process manager standar Docker).

### Setup Awal

**Langkah 1 — Set env var di Railway:**

Buka Railway → `rairu-devculture` → Variables, tambah:

| Variable | Nilai | Keterangan |
|----------|-------|------------|
| `HERMES_CMD` | `/usr/local/bin/hermes --config /etc/hermes/config.yaml` | Ganti dengan command hermes yang benar |
| `HERMES_AUTOSTART` | `true` | `true` = autostart saat boot, `false` = manual |

Setelah set env var, Railway akan redeploy otomatis.

**Langkah 2 — Atau edit config langsung di VPS:**
```bash
nano /etc/supervisor/conf.d/hermes.conf
supervisorctl reread
supervisorctl update
```

### Perintah Supervisorctl

```bash
# Cek status semua service
supervisorctl status

# Jalankan hermes
supervisorctl start hermes-gateway

# Stop hermes
supervisorctl stop hermes-gateway

# Restart hermes
supervisorctl restart hermes-gateway

# Lihat log hermes secara realtime
supervisorctl tail -f hermes-gateway

# Reload config setelah edit hermes.conf
supervisorctl reread && supervisorctl update
```

### Log Hermes

```bash
# Log stdout (output normal)
tail -f /tmp/hermes.log

# Log stderr (error)
tail -f /tmp/hermes-error.log

# Log supervisord
tail -f /tmp/supervisord.log
```

### Crash Notification

Jika hermes crash, notifikasi otomatis dikirim ke ntfy `yans-proton` berisi:
- Nama service yang crash
- Port SSH saat ini
- Perintah untuk cek log

Hermes akan di-restart otomatis oleh supervisord (maks 10x percobaan).

---

## 📋 Environment Variables (Railway)

| Variable | Default | Keterangan |
|----------|---------|------------|
| `ROOT_PASS` | *(wajib diset)* | Password SSH root |
| `NTFY_TOPIC` | `yans-proton` | Topic ntfy untuk notifikasi |
| `BORE_SERVER` | `bore.pub` | Server bore tunnel |
| `HERMES_CMD` | *(kosong)* | Command untuk jalankan hermes-gateway |
| `HERMES_AUTOSTART` | `false` | Auto-start hermes saat boot |

---

## 📁 Struktur Service

```
entrypoint.sh          ← startup script utama
supervisord.conf        ← config supervisord
hermes.conf            ← service unit hermes-gateway
crash-notifier.sh      ← kirim ntfy saat service crash

/tmp/hermes.log         ← log hermes stdout
/tmp/hermes-error.log   ← log hermes stderr
/tmp/supervisord.log    ← log supervisord
/tmp/bore.log           ← log bore tunnel
```

---

## 🛠️ Troubleshooting

**Hermes tidak mau start:**
```bash
supervisorctl status hermes-gateway   # cek state
tail -20 /tmp/hermes-error.log        # cek error
echo $HERMES_CMD                       # pastikan env var terisi
```

**Port SSH berubah (bore reconnect):**  
Cek notifikasi ntfy terbaru — port baru dikirim otomatis.

**VPS tidak bisa di-SSH:**  
Kirim `restart` ke ntfy topic `yans-proton` untuk restart Railway container.

---

*c2026 devculture linux*
