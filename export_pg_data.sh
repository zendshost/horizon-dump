#!/bin/bash
set -euo pipefail

echo "=============================================="
echo "    AUTO BACKUP + RESTORE PI NODE (FULL)"
echo "=============================================="
echo
read -p "Masukkan IP Server Target: " TARGET_HOST

SOURCE_CONTAINER="mainnet"
TARGET_USER="root"
TARGET_CONTAINER="mainnet"
PG_PATH="/var/lib/postgresql"
TMP_DIR="/tmp/postgresql_data"

echo
echo "==> 1. Membuat dump PostgreSQL dari server sumber..."
docker exec $SOURCE_CONTAINER mkdir -p /tmp/postgresql_data || true
rm -rf /tmp/postgresql_data
docker cp $SOURCE_CONTAINER:$PG_PATH/. /tmp/postgresql_data
echo "✅ Dump selesai: /tmp/postgresql_data"

echo "==> 2. Mengirim data ke server target $TARGET_HOST..."
scp -r /tmp/postgresql_data ${TARGET_USER}@${TARGET_HOST}:/tmp/
echo "✅ Data dikirim."

echo
echo "=============================================="
echo "==> 3. Menjalankan proses otomatis di server target..."
echo "=============================================="

ssh -t ${TARGET_USER}@${TARGET_HOST} bash -s <<'ENDSSH'
set -euo pipefail

echo "==> Update paket..."
apt update -y

echo "==> Install dependencies..."
apt install -y ca-certificates curl gnupg lsb-release

echo "==> Install Docker jika belum ada..."
if ! command -v docker &>/dev/null; then
    apt install -y docker.io
    systemctl enable --now docker
else
    echo "Docker sudah terinstall"
fi

echo "==> Install Pi-Node CLI jika belum ada..."
if ! command -v pi-node &>/dev/null; then
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://apt.minepi.com/repository.gpg.key \
      | gpg --dearmor --batch -o /etc/apt/keyrings/pinetwork-archive-keyring.gpg

    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/pinetwork-archive-keyring.gpg] https://apt.minepi.com stable main" \
      > /etc/apt/sources.list.d/pinetwork.list

    apt update -y
    apt install -y pi-node
else
    echo "pi-node sudah terinstall"
fi

echo "==> Hentikan container mainnet jika ada..."
docker stop mainnet 2>/dev/null || true
docker rm mainnet 2>/dev/null || true

echo "==> Jalankan pi-node initialize..."
pi-node initialize

echo "==> Stop Horizon & Core..."
docker exec mainnet supervisorctl stop horizon || true
docker exec mainnet supervisorctl stop stellar-core || true

echo "==> Hapus data PostgreSQL lama..."
docker exec mainnet bash -c 'rm -rf /var/lib/postgresql/*'

echo "==> Copy data PostgreSQL baru..."
docker cp /tmp/postgresql_data/. mainnet:/var/lib/postgresql
docker exec mainnet bash -c 'chown -R postgres:postgres /var/lib/postgresql && chmod -R 700 /var/lib/postgresql'

echo "==> Bersihkan data Horizon lama..."
docker exec mainnet bash -c 'rm -rf /root/.local/share/horizon/*'

echo "==> Restart stellar-core..."
docker exec mainnet supervisorctl restart stellar-core
sleep 8

echo "==> Restart horizon..."
docker exec mainnet supervisorctl restart horizon
sleep 8

echo "==> Status node target:"
docker exec mainnet supervisorctl status

echo "==> Proses restore server target selesai."
ENDSSH

echo "=============================================="
echo "==> 4. Restart node server sumber..."
echo "=============================================="

docker start mainnet >/dev/null 2>&1 || true
sleep 5
echo
docker ps -a | grep mainnet || echo "⚠ mainnet tidak muncul — cek container"
echo
echo "==> Logs server sumber:"
docker logs --tail=50 mainnet

echo
echo "=============================================="
echo " RESTORE SELESAI TANPA ERROR! "
echo "=============================================="
