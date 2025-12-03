#!/bin/bash
set -euo pipefail

echo -e "\e[1;34m[INFO] Clone Pi Node dari server sumber ke target\e[0m"

# ==========================
# Input IP target
# ==========================
read -p "Masukkan IP server target: " TARGET_HOST
TARGET_USER="root"
SOURCE_CONTAINER="mainnet"
TARGET_CONTAINER="mainnet"
PG_PATH="/var/lib/postgresql"
TMP_DIR="/tmp/postgresql_data"

# ==========================
# 1. Backup PostgreSQL dari server sumber
# ==========================
echo -e "\e[1;32m[1/5] Membuat backup PostgreSQL dari container sumber...\e[0m"
mkdir -p $TMP_DIR
docker cp $SOURCE_CONTAINER:$PG_PATH/. $TMP_DIR
echo -e "✅ Backup PostgreSQL dibuat di $TMP_DIR"

# ==========================
# 2. Kirim backup ke server target
# ==========================
echo -e "\e[1;32m[2/5] Mengirim backup ke server target $TARGET_HOST...\e[0m"
scp -r $TMP_DIR ${TARGET_USER}@${TARGET_HOST}:/tmp/
echo -e "✅ Backup dikirim ke $TARGET_HOST"

# ==========================
# 3. Instalasi Pi Node & Docker di server target + Restore
# ==========================
echo -e "\e[1;32m[3/5] Menjalankan instalasi Pi Node & restore di server target...\e[0m"

ssh ${TARGET_USER}@${TARGET_HOST} bash -s <<'ENDSSH'
set -euo pipefail

TARGET_CONTAINER="mainnet"
PG_PATH="/var/lib/postgresql"

echo -e "\e[1;32m[INFO] 1. Install dependencies + Docker + Pi Node\e[0m"

# --------- Dependencies ----------
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release

# --------- Docker ----------
if ! command -v docker &> /dev/null; then
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io
    sudo systemctl enable --now docker
fi

# --------- Pi Node ----------
if [ ! -f /etc/apt/sources.list.d/pinetwork.list ]; then
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://apt.minepi.com/repository.gpg.key \
      | sudo gpg --dearmor -o /etc/apt/keyrings/pinetwork-archive-keyring.gpg
    sudo chmod a+r /etc/apt/keyrings/pinetwork-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/pinetwork-archive-keyring.gpg] https://apt.minepi.com stable main" \
      | sudo tee /etc/apt/sources.list.d/pinetwork.list > /dev/null
fi

sudo apt update
sudo apt install -y pi-node

# --------- Stop Node ----------
docker exec $TARGET_CONTAINER supervisorctl stop horizon || true
docker exec $TARGET_CONTAINER supervisorctl stop stellar-core || true

# --------- Hapus PostgreSQL lama ----------
docker exec $TARGET_CONTAINER bash -c "rm -rf $PG_PATH/*"

# --------- Copy PostgreSQL baru ----------
docker cp /tmp/postgresql_data/. $TARGET_CONTAINER:$PG_PATH
docker exec $TARGET_CONTAINER bash -c "chown -R postgres:postgres $PG_PATH && chmod -R 700 $PG_PATH"

# --------- Bersihkan Horizon ----------
docker exec $TARGET_CONTAINER bash -c "rm -rf /root/.local/share/horizon/*"

# --------- Restart Node ----------
docker exec $TARGET_CONTAINER supervisorctl restart stellar-core
sleep 5
docker exec $TARGET_CONTAINER supervisorctl restart horizon
sleep 10

# --------- Status Node ----------
docker exec $TARGET_CONTAINER supervisorctl status

echo -e "\e[1;32m✅ Restore selesai! Node siap digunakan.\e[0m"
ENDSSH

# ==========================
# 4. Selesai
# ==========================
echo -e "\e[1;34m[INFO] Semua proses selesai, node target siap!\e[0m"
