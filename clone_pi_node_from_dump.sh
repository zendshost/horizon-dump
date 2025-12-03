#!/bin/bash
# ==========================================
# Clone Pi Node from Horizon dump
# ==========================================
# Usage: ./clone_pi_node_from_dump.sh <SOURCE_USER>@<SOURCE_IP>
SOURCE="$1"
DUMP_PATH="/tmp/horizon.dump"

if [ -z "$SOURCE" ]; then
    echo "Usage: $0 <SOURCE_USER>@<SOURCE_IP>"
    exit 1
fi

echo "==> Mengambil dump dari server sumber..."
scp $SOURCE:$DUMP_PATH $DUMP_PATH
if [ $? -ne 0 ]; then
    echo "❌ Gagal menyalin dump!"
    exit 1
fi
echo "✅ Dump tersalin, memeriksa ukuran..."
ls -lh $DUMP_PATH

echo "==> Stop Pi Node..."
docker exec -it mainnet supervisorctl stop horizon || true
docker exec -it mainnet supervisorctl stop stellar-core || true
sleep 5

echo "==> Drop & recreate DB..."
docker exec -it mainnet bash -c "su - postgres -c 'dropdb horizon || true; createdb horizon'"

echo "==> Hapus cache Horizon..."
docker exec -it mainnet bash -c "rm -rf /root/.local/share/horizon/*"

echo "==> Restore dump (tunggu beberapa menit)..."
cat $DUMP_PATH | docker exec -i mainnet su - postgres -c "pg_restore -d horizon"

echo "==> Set permission PostgreSQL data (jika diperlukan)"
docker exec -it mainnet bash -c "chown -R postgres:postgres /var/lib/postgresql"
docker exec -it mainnet bash -c "chmod -R 700 /var/lib/postgresql"

echo "==> Start Stellar-core & Horizon..."
docker exec -it mainnet supervisorctl start stellar-core
sleep 10
docker exec -it mainnet supervisorctl start horizon

echo "==> Status Node Target:"
pi-node status
