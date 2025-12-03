#!/bin/bash
# ==========================================
# Clone Pi Node from server sumber (PostgreSQL data copy)
# ==========================================

# ======================
# CONFIGURATION
# ======================
SOURCE_USER="root"
SOURCE_HOST="146.190.193.103"   # IP server sumber
SOURCE_TMP_DIR="/tmp/postgresql_data"

TARGET_TMP_DIR="/tmp/postgresql_data"
CONTAINER_NAME="mainnet"

# ======================
# STEP 1: Ambil data dari server sumber
# ======================
echo "==> Mengambil PostgreSQL data dari server sumber ($SOURCE_HOST)..."
scp -r ${SOURCE_USER}@${SOURCE_HOST}:${SOURCE_TMP_DIR} $TARGET_TMP_DIR
if [ $? -ne 0 ]; then
    echo "❌ Gagal mengambil data dari server sumber!"
    exit 1
fi
echo "✅ Data berhasil diambil: $TARGET_TMP_DIR"

# ======================
# STEP 2: Stop Node di target
# ======================
echo "==> Stop Horizon & Stellar-core..."
docker exec -it $CONTAINER_NAME supervisorctl stop horizon || true
docker exec -it $CONTAINER_NAME supervisorctl stop stellar-core || true
sleep 5

# ======================
# STEP 3: Hapus data PostgreSQL lama di container
# ======================
echo "==> Hapus data PostgreSQL lama di container..."
docker exec -it $CONTAINER_NAME bash -c "rm -rf /var/lib/postgresql/*"

# ======================
# STEP 4: Copy PostgreSQL data baru ke container
# ======================
echo "==> Copy PostgreSQL data baru ke container..."
docker cp $TARGET_TMP_DIR/. $CONTAINER_NAME:/var/lib/postgresql

# ======================
# STEP 5: Set permission
# ======================
echo "==> Set permission untuk PostgreSQL..."
docker exec -it $CONTAINER_NAME bash -c "chown -R postgres:postgres /var/lib/postgresql"
docker exec -it $CONTAINER_NAME bash -c "chmod -R 700 /var/lib/postgresql"

# ======================
# STEP 6: Bersihkan cache Horizon
# ======================
echo "==> Bersihkan cache Horizon..."
docker exec -it $CONTAINER_NAME bash -c "rm -rf /root/.local/share/horizon/*"

# ======================
# STEP 7: Start Node
# ======================
echo "==> Start Stellar-core..."
docker exec -it $CONTAINER_NAME supervisorctl start stellar-core
sleep 10

echo "==> Start Horizon..."
docker exec -it $CONTAINER_NAME supervisorctl start horizon

# ======================
# STEP 8: Tampilkan status node
# ======================
echo "==> Status Node:"
pi-node status
