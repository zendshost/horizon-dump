
# Auto Backup + Restore Pi Node (Docker Compose)

Script ini digunakan untuk **backup PostgreSQL node Pi Network** dari server sumber, kemudian melakukan **restore otomatis ke server target baru** yang belum di-setup. Semua proses di-handle otomatis termasuk instalasi Docker, Pi-Node CLI, dan setup container `mainnet`.

> ⚠️ Catatan: Node target **tidak langsung bisa melakukan transaksi** sampai ledger selesai sinkron.

---

## Prasyarat

1. **Server Sumber**
   - Pi Node sudah berjalan di Docker Compose (`mainnet` container).
   - Akses root atau user dengan sudo.
   
2. **Server Target**
   - VPS baru dengan Ubuntu (20.04 / 22.04 / 23.04) atau compatible.
   - User `root` atau user dengan akses sudo.
   - Koneksi SSH dari server sumber ke server target.
   
3. **Server Sumber**
   - Docker & Pi-Node CLI sudah terinstall.

4. **Server Target**
   - Kosong, script akan otomatis install dependencies, Docker, Pi-Node CLI, dan setup container `mainnet`.

---

## Cara Pakai

1. **Clone repository**

```bash
git clone https://github.com/zendshost/horizon-dump.git
cd horizon-dump
chmod +x run.sh
````

2. **Jalankan script**

```bash
./run.sh
```

3. **Input IP server target** saat diminta:

```
Masukkan IP Server Target: 123.45.67.89
```

Script akan otomatis:

* Membuat backup PostgreSQL di server sumber.
* Mengirim backup ke server target via `scp`.
* Install dependencies, Docker, Pi-Node CLI di server target jika belum ada.
* Initialize Pi Node di server target (`--force --auto-confirm`).
* Restore database ke container `mainnet` di server target.
* Restart container dan cek status node.
* Restart container `mainnet` server sumber.

---

## Output

* Node target akan berjalan di Docker Compose (`mainnet` container).
* Status node bisa dicek:

```bash
pi-node status
pi-node protocol-status
```

* Node target akan **catching up** terlebih dahulu sebelum bisa melakukan transaksi.
* Node sumber tetap berjalan normal.

---

## Struktur Script

* `run.sh`: Script utama untuk backup + restore node.
* `/tmp/postgresql_data`: Temporary folder untuk PostgreSQL dump.
* Docker Compose di `/root/pi-node/docker-compose.yml` pada server target.

---

## Tips

* Pastikan **firewall/port** di server target membuka akses Docker dan SSH.
* Pastikan `scp` dan SSH key/password sudah bisa dari server sumber ke server target.
* Untuk otomatis update node target nanti, bisa jalankan:

```bash
pi-node enableAutoUpdate
```

---

## Lisensi

MIT License – bebas digunakan, dimodifikasi, dan dibagikan.

---

## Support

Bisa dibuka issue di repository: [https://github.com/zendshost/horizon-dump/issues](https://github.com/zendshost/horizon-dump/issues)
