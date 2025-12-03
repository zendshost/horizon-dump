#!/bin/bash
# ==========================================
# Export PostgreSQL data dari Pi Node (server sumber)
# ==========================================

CONTAINER_NAME="mainnet"
TMP_DIR="/tmp/postgresql_data"

echo "==> Hentikan sementara Horizon (opsional, jika perlu konsistensi)..."
docker exec -it $CONTAINER_NAME supervisorctl stop horizon || true
docker exec -it $CONTAINER_NAME supervisorctl stop stellar-core || true

sleep 5

echo "==> Salin data PostgreSQL dari container ke $TMP_DIR..."
rm -rf $TMP_DIR
mkdir -p $TMP_DIR
docker cp $CONTAINER_NAME:/var/lib/postgresql $TMP_DIR

echo "✅ PostgreSQL data siap di $TMP_DIR"
echo "Ukuran data:"
du -sh $TMP_DIR

echo "==> Jika ingin langsung transfer ke server target, gunakan scp:"
echo "scp -r $TMP_DIR root@TARGET_SERVER:/tmp/"
