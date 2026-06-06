#!/bin/bash
# ============================================================
# Sync CSV splits from local machine to S3
# Usage: ./scripts/00_data_generation/sync_csv_to_s3.sh sf100
# Expects: $DATA_HYBENCH_* local dir with one subdir per table
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../env.sh"

SCALE="${1:-sf100}"
case $SCALE in
    sf100) SRC="${DATA_HYBENCH_100}"; DST_SUFFIX="sf100" ;;
    sf1000) SRC="${DATA_HYBENCH_1000}"; DST_SUFFIX="sf1000" ;;
    sf1333) SRC="${DATA_HYBENCH_100:-/tmp/hybench_sf1333}"; DST_SUFFIX="sf1333" ;;
    *) echo "unknown scale $SCALE"; exit 1 ;;
esac

DST="${DATA_S3:-s3://${S3_BUCKET}/data/hybench}/${DST_SUFFIX}/csv"
echo ">>> syncing $SRC → $DST"

for TABLE in "${HYBENCH_TABLES[@]}"; do
    if [ -d "${SRC}/${TABLE}" ]; then
        echo "  $TABLE ..."
        aws s3 sync "${SRC}/${TABLE}/" "${DST}/${TABLE}/" --exclude "*" --include "*.csv"
    else
        echo "  $TABLE: skipping (not found)"
    fi
done
echo ">>> done"
