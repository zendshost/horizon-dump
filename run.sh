#!/bin/bash
set -euo pipefail

echo "=============================================="
echo "    AUTO BACKUP + RESTORE PI NODE (DOCKER COMPOSE)"
echo "=============================================="
echo
read -p "Masukkan IP Server Target: " TARGET_HOST

SOURCE_CONTAINER="mainnet"
TARGET_USER="root"
TARGET_CONTAINER="mainnet"
PG_PATH="/var/lib/postgresql"
TMP_DIR="/tmp/postgresql_data"

# ------------------------------
# 1. Backup PostgreSQL dari sumber
# ------------------------------
echo
echo "==> 1. Membuat dump PostgreSQL dari server sumber..."
docker exec $SOURCE_CONTAINER mkdir -p /tmp/postgresql_data || true
rm -rf /tmp/postgresql_data
docker cp $SOURCE_CONTAINER:$PG_PATH/. /tmp/postgresql_data
echo "✅ Dump selesai: /tmp/postgresql_data"

# ------------------------------
# 2. Kirim data ke server target
# ------------------------------
echo "==> 2. Mengirim data ke server target $TARGET_HOST..."
scp -r /tmp/postgresql_data ${TARGET_USER}@${TARGET_HOST}:/tmp/
echo "✅ Data dikirim."

# ------------------------------
# 3. Restore di server target via SSH
# ------------------------------
echo
echo "=============================================="
echo "==> 3. Menjalankan restore di server target..."
echo "=============================================="

ssh ${TARGET_USER}@${TARGET_HOST} bash -s <<'ENDSSH'
set -euo pipefail

echo "==> Update paket..."
apt update -y
apt install -y ca-certificates curl gnupg lsb-release tar

# ------------------------------
# Install Docker jika belum ada
# ------------------------------
if ! command -v docker &>/dev/null; then
    echo "⚡ Install Docker..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | gpg --dearmor --batch --yes -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io
    systemctl enable --now docker
else
    echo "Docker sudah terinstal."
fi

# ------------------------------
# Install / Upgrade Pi-Node CLI
# ------------------------------
if dpkg -l | grep -qw pi-node; then
    echo "⚠ Pi-Node versi apt lawas ditemukan, tetap gunakan versi ini."
else
    echo "⚡ Install Pi-Node CLI..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://apt.minepi.com/repository.gpg.key \
      | gpg --dearmor --batch --yes -o /etc/apt/keyrings/pinetwork-archive-keyring.gpg
    chmod a+r /etc/apt/keyrings/pinetwork-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/pinetwork-archive-keyring.gpg] https://apt.minepi.com stable main" \
      > /etc/apt/sources.list.d/pinetwork.list
    apt update -y
    apt install -y pi-node
fi

if ! command -v pi-node &>/dev/null; then
    echo "❌ Pi-Node binary tidak ditemukan, keluar."
    exit 1
fi
echo "✅ Pi-Node CLI siap: $(pi-node --version || echo 'unknown')"

# ------------------------------
# Backup node lama jika ada
# ------------------------------
PI_NODE_DIR="/root/pi-node"
if [ -d "$PI_NODE_DIR" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    echo "⚠ Node lama terdeteksi, backup ke ${PI_NODE_DIR}-backup-$TIMESTAMP"
    mv "$PI_NODE_DIR" "${PI_NODE_DIR}-backup-$TIMESTAMP"
fi

# ------------------------------
# Stop container lama jika ada
# ------------------------------
if docker compose -f /root/pi-node/docker-compose.yml ps -q mainnet &>/dev/null; then
    echo "⚡ Stop container lama..."
    docker compose -f /root/pi-node/docker-compose.yml down || true
fi

# ------------------------------
# Initialize node baru
# ------------------------------
echo "⚡ Jalankan pi-node initialize dengan --force --auto-confirm..."
pi-node initialize --force --auto-confirm

# ------------------------------
# Tunggu container mainnet siap
# ------------------------------
echo "⚡ Menunggu container mainnet siap..."
while ! docker compose -f /root/pi-node/docker-compose.yml ps mainnet | grep -q "Up"; do
    echo "⏳ Menunggu 5 detik..."
    sleep 5
done
echo "✅ Container mainnet sudah running."

# ------------------------------
# Restore PostgreSQL
# ------------------------------
echo "⚡ Hapus data PostgreSQL lama..."
docker cp /tmp/postgresql_data/. mainnet:/var/lib/postgresql
docker exec mainnet bash -c 'chown -R postgres:postgres /var/lib/postgresql && chmod -R 700 /var/lib/postgresql'
echo "✅ Data PostgreSQL baru sudah dicopy."

# ------------------------------
# Restart container via Docker Compose
# ------------------------------
echo "⚡ Restart container mainnet..."
docker compose -f /root/pi-node/docker-compose.yml restart mainnet
sleep 10

# ------------------------------
# Cek status node
# ------------------------------
echo "⚡ Status node target:"
pi-node status
pi-node protocol-status

echo "==> Proses restore server target selesai."
ENDSSH

# ------------------------------
# Restart node server sumber
# ------------------------------
echo "=============================================="
echo "==> 4. Restart node server sumber..."
echo "=============================================="

docker start mainnet >/dev/null 2>&1 || true
sleep 5
docker ps -a | grep mainnet || echo "⚠ mainnet tidak muncul — cek container"
echo
echo "==> Logs server sumber:"
docker logs --tail=50 mainnet

echo
echo "=============================================="
echo " RESTORE SELESAI TANPA ERROR! "
echo "=============================================="
