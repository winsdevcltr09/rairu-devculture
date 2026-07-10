# rairu-devculture — Devops VPS

VPS Docker yang berjalan di Railway dengan SSH via bore tunnel.  
Notifikasi SSH dan status dikirim ke **ntfy** topic `yans-proton`.

---

## 🚀 Cara SSH Masuk

**1. Tunggu notifikasi di ntfy (`yans-proton`)**  
Setiap kali VPS online atau bore reconnect, kamu dapat notifikasi dengan port SSH terbaru.

**2. Koneksi SSH:**
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

## 💾 Data Persisten (Railway Volume)

> **Tanpa Volume**, semua file yang dibuat via SSH akan **hilang saat redeploy**.  
> Dengan **Railway Volume** yang di-mount ke `/data`, data kamu **aman**.

### Setup Volume (1x saja)

1. Buka Railway → project `rairu-devculture` → klik service
2. Klik tab **"Volumes"** → **"Add Volume"**
3. Isi:
   - **Mount Path**: `/data`
   - **Size**: sesuai kebutuhan (default 1GB)
4. Klik **Create** → Railway akan redeploy otomatis

Setelah itu, `/data` tidak pernah hilang meski redeploy berkali-kali.

### Struktur `/data`

```
/data/
├── hermes/          ← simpan config + data hermes di sini
│   ├── config.yaml  ← contoh config hermes
│   └── ...
├── ssh-keys/
│   └── authorized_keys  ← SSH key kamu (otomatis terhubung ke ~/.ssh/)
├── supervisor/      ← tambah file .conf supervisord di sini
└── logs/            ← log persisten (opsional)
```

### Tips penggunaan `/data`

```bash
# Simpan config hermes ke volume (tidak hilang saat redeploy)
nano /data/hermes/config.yaml

# Tambah SSH key agar tidak perlu password lagi
echo "ssh-ed25519 AAAA..." >> /data/ssh-keys/authorized_keys

# Tambah service supervisord baru (persisten)
nano /data/supervisor/myservice.conf
supervisorctl reread && supervisorctl update
```

---

## ⚙️ Hermes Gateway Telegram

Hermes dikelola oleh **supervisord** (process manager standar Docker).

### Setup Awal

**Langkah 1 — Simpan file hermes ke `/data/hermes/`:**
```bash
# SSH masuk, lalu taruh binary/config hermes di sini
cp /path/to/hermes-binary /data/hermes/
chmod +x /data/hermes/hermes-binary

# Config hermes
nano /data/hermes/config.yaml
```

**Langkah 2 — Set env var di Railway:**

Buka Railway → `rairu-devculture` → Variables, tambah:

| Variable | Nilai | Keterangan |
|----------|-------|------------|
| `HERMES_CMD` | `/data/hermes/hermes-binary --config /data/hermes/config.yaml` | Command hermes (pakai path /data agar tidak hilang) |
| `HERMES_AUTOSTART` | `true` | `true` = autostart saat boot |

> **Penting:** Pakai path `/data/hermes/...` agar command tetap valid setelah redeploy.

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

# Reload config setelah edit
supervisorctl reread && supervisorctl update
```

### Log Hermes

```bash
# Log realtime
tail -f /tmp/hermes.log        # stdout
tail -f /tmp/hermes-error.log  # stderr

# Log persisten (simpan manual ke /data)
cp /tmp/hermes.log /data/logs/hermes-$(date +%Y%m%d).log
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
| `HERMES_CMD` | *(kosong)* | Command untuk jalankan hermes (gunakan path `/data/`) |
| `HERMES_AUTOSTART` | `false` | Auto-start hermes saat boot |

---

## 📁 Struktur File

```
# Di dalam container (reset saat redeploy)
entrypoint.sh           ← startup script utama
supervisord.conf         ← config supervisord
hermes.conf             ← service unit hermes-gateway
crash-notifier.sh       ← kirim ntfy saat service crash
/tmp/hermes.log          ← log hermes stdout (sementara)
/tmp/hermes-error.log    ← log hermes stderr (sementara)

# Persisten di Railway Volume (tidak hilang)
/data/hermes/            ← binary + config hermes
/data/ssh-keys/          ← authorized_keys SSH
/data/supervisor/        ← config supervisord tambahan
/data/logs/              ← log persisten
```

---

## 🛠️ Troubleshooting

**Data hilang setelah redeploy?**  
→ Pastikan Railway Volume sudah dibuat dan di-mount ke `/data`. Cek: `mountpoint -q /data && echo "OK" || echo "TIDAK TERPASANG"`

**Hermes tidak mau start:**
```bash
supervisorctl status hermes-gateway   # cek state
tail -20 /tmp/hermes-error.log        # cek error
echo $HERMES_CMD                       # pastikan env var terisi
ls -la /data/hermes/                   # cek binary ada di /data
```

**Port SSH berubah (bore reconnect):**  
Cek notifikasi ntfy terbaru — port baru dikirim otomatis.

**VPS tidak bisa di-SSH:**  
Kirim `restart` ke ntfy topic `yans-proton` untuk restart Railway container.

**SSH key tidak dikenali setelah redeploy:**  
Authorized keys disimpan di `/data/ssh-keys/authorized_keys` — cek volume sudah terpasang.

---

*c2026 devculture linux*
