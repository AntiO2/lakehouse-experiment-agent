#!/bin/bash
# ============================================================
# Restore Iceberg tables from S3 .bak/
# Usage: ./scripts/03_backup/restore_iceberg_s3.sh [sf100|sf1000]
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
BAK="${S3_ICEBERG}/${DB}.db.bak"

echo ">>> restoring ${DB} from ${BAK}"
for TABLE in "${HYBENCH_TABLES[@]}"; do
    echo "[$(date +%H:%M:%S)] ${TABLE}: removing old data ..."
    aws s3 rm "${SRC}/${TABLE}/" --recursive
    echo "[$(date +%H:%M:%S)] ${TABLE}: restoring ..."
    aws s3 sync --delete "${BAK}/${TABLE}/" "${SRC}/${TABLE}/"
done
echo ">>> restore complete"
