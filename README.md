
# Pi Node Backup & Restore (Docker Compose) 🟢

Script ini memudahkan **backup dan restore node Pi Network** menggunakan **Docker Compose**, termasuk setup server target baru.

---

## Fitur

- Backup PostgreSQL dari container `mainnet` server sumber
- Kirim data ke server target via SCP
- Install otomatis Docker & Pi-Node CLI jika belum ada
- Restore data PostgreSQL ke server target
- Inisialisasi node baru / overwrite node lama
- Restart container node dan cek status

---

## Flowchart Proses Backup & Restore

```mermaid
flowchart TD
    A[Mulai: Jalankan run.sh di server sumber] --> B[Membuat backup PostgreSQL dari container mainnet]
    B --> C[Kirim data backup ke server target via SCP]
    C --> D{Apakah Docker & Pi-Node CLI terinstall di server target?}
    D -- Tidak --> E[Install Docker & Pi-Node CLI di server target]
    D -- Ya --> F[Lanjut]
    E --> F
    F --> G{Apakah node lama ada di server target?}
    G -- Ya --> H[Backup node lama di server target]
    G -- Tidak --> I[Lanjut]
    H --> I
    I --> J[Initialize Pi Node di server target (--force --auto-confirm)]
    J --> K[Restore data PostgreSQL ke server target]
    K --> L[Restart container mainnet di server target]
    L --> M[Tampilkan status node target]
    M --> N[Restart node server sumber]
    N --> O[Selesai ✅]
````

---

## Cara Menggunakan

1. **Clone repository**

```bash
git clone https://github.com/zendshost/horizon-dump.git
cd horizon-dump
```

2. **Jalankan script di server sumber**

```bash
chmod +x run.sh
./run.sh
```

3. **Ikuti prompt**

* Masukkan **IP server target**
* Script akan melakukan backup, transfer, restore, dan inisialisasi node target.

---

## Catatan Penting

* Server target **harus fresh / kosong** untuk hasil maksimal.
* Jika node target sudah ada, script akan membuat **backup node lama**.
* Pi Node CLI versi terbaru harus tersedia dari repository resmi: `https://apt.minepi.com`
* Semua perintah Docker dijalankan dalam container `mainnet`.
* Pastikan SSH key atau password root server target siap digunakan.

---

## Troubleshooting

* **Pi-Node CLI tidak ditemukan**
  Pastikan `pi-node` terinstall dengan benar dan berada di PATH (`/usr/local/bin` atau `/opt/pi-node/bin`).

* **Container mainnet tidak muncul**
  Periksa dengan:

  ```bash
  docker ps -a | grep mainnet
  ```

* **SSH gagal ke server target**
  Pastikan server target bisa diakses dan user memiliki hak root atau sudo.

---

## Lisensi

MIT License © 2025

---

## Repository

[https://github.com/zendshost/horizon-dump](https://github.com/zendshost/horizon-dump)
