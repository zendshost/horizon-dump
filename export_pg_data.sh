#!/bin/bash
set -e

# ================================
# CONFIGURATION
# ================================
SOURCE_CONTAINER="mainnet"
TARGET_USER="root"
TARGET_HOST="178.128.97.222"
TARGET_CONTAINER="mainnet"
PG_PATH="/var/lib/postgresql"
TMP_DIR="/tmp/postgresql_data"

# ================================
# 1. Buat dump PostgreSQL dari container sumber
# ================================
echo "==> Membuat dump PostgreSQL dari container sumber..."
docker exec $SOURCE_CONTAINER bash -c "mkdir -p /tmp/postgresql_data"
docker cp $SOURCE_CONTAINER:$PG_PATH/. /tmp/postgresql_data
echo "✅ Dump PostgreSQL dibuat di /tmp/postgresql_data"

# ================================
# 2. Kirim dump ke server target
# ================================
echo "==> Mengirim data ke server target..."
scp -r /tmp/postgresql_data ${TARGET_USER}@${TARGET_HOST}:/tmp/
echo "✅ Data dikirim."

# ================================
# 3. Jalankan restore otomatis di server target
# ================================
echo "==> Menjalankan restore di server target..."
ssh ${TARGET_USER}@${TARGET_HOST} bash -c "
set -e
echo '==> Stop node target...'
docker exec $TARGET_CONTAINER supervisorctl stop horizon || true
docker exec $TARGET_CONTAINER supervisorctl stop stellar-core || true

echo '==> Hapus data PostgreSQL lama...'
docker exec $TARGET_CONTAINER bash -c 'rm -rf $PG_PATH/*'

echo '==> Copy data PostgreSQL baru ke container...'
docker cp /tmp/postgresql_data/. $TARGET_CONTAINER:$PG_PATH
docker exec $TARGET_CONTAINER bash -c 'chown -R postgres:postgres $PG_PATH && chmod -R 700 $PG_PATH'

echo '==> Bersihkan data Horizon lama...'
docker exec $TARGET_CONTAINER bash -c 'rm -rf /root/.local/share/horizon/*'

echo '==> Restart node target...'
docker exec $TARGET_CONTAINER supervisorctl restart stellar-core
sleep 5
docker exec $TARGET_CONTAINER supervisorctl restart horizon

echo '==> Menunggu beberapa detik agar Horizon siap...'
sleep 10

echo '==> Status node target:'
docker exec $TARGET_CONTAINER supervisorctl status
"
echo "✅ Restore selesai!"
