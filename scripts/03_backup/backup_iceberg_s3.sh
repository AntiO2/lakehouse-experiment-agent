#!/bin/bash
# ============================================================
# Backup Iceberg tables (S3 sync to .bak/)
# Usage: ./scripts/03_backup/backup_iceberg_s3.sh [sf100|sf1000]
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../env.sh"

SCALE="${1:-sf100}"
case $SCALE in
    sf100) DB="${DB_HYBENCH_SF100}" ;;
    sf1000) DB="${DB_HYBENCH_SF1000}" ;;
    *) echo "unknown scale $SCALE"; exit 1 ;;
esac

SRC="${S3_ICEBERG}/${DB}.db"
DST="${S3_ICEBERG}/${DB}.db.bak"

echo ">>> backing up ${DB} → ${DST}"
for TABLE in "${HYBENCH_TABLES[@]}"; do
    echo "[$(date +%H:%M:%S)] ${TABLE} ..."
    aws s3 sync "${SRC}/${TABLE}/" "${DST}/${TABLE}/"
    echo "[$(date +%H:%M:%S)] ${TABLE} done"
done
echo ">>> backup complete: ${DST}"
