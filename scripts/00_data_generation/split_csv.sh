#!/bin/bash
# ============================================================
# Split a single CSV into part-00000.csv ... part-NNNNN.csv
# Usage: ./scripts/00_data_generation/split_csv.sh \
#          /path/to/data.csv /path/to/output_dir [rows_per_file]
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../env.sh"

SRC_CSV="${1:?Usage: $0 <src.csv> <out_dir> [rows_per_file]}"
OUT_DIR="${2:?}"
ROWS="${3:-3000000}"

mkdir -p "$OUT_DIR"
echo ">>> splitting $SRC_CSV → $OUT_DIR (${ROWS} rows/file)"

# No header: split directly
head -1 "$SRC_CSV" | grep -q ',' && HAS_HEADER=1 || HAS_HEADER=0

if [ "$HAS_HEADER" -eq 1 ]; then
    HEADER=$(head -1 "$SRC_CSV")
    tail -n +2 "$SRC_CSV" | split -l "$ROWS" -d -a 5 --additional-suffix=.csv - "$OUT_DIR/part-"
    # Prepend header to each split file
    for f in "$OUT_DIR"/part-*.csv; do
        sed -i "1i$HEADER" "$f"
    done
else
    split -l "$ROWS" -d -a 5 --additional-suffix=.csv "$SRC_CSV" "$OUT_DIR/part-"
fi

echo ">>> done: $(ls "$OUT_DIR" | wc -l) files"
