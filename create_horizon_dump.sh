#!/bin/bash
# ==========================================
# Create Horizon dump for cloning
# ==========================================
DUMP_PATH="/tmp/horizon.dump"

echo "==> Membuat dump Horizon PostgreSQL..."
docker exec -it mainnet su - postgres -c "pg_dump -Fc horizon > $DUMP_PATH"

if [ $? -eq 0 ]; then
    echo "✅ Dump selesai di $DUMP_PATH"
    ls -lh $DUMP_PATH
else
    echo "❌ Dump gagal!"
    exit 1
fi
