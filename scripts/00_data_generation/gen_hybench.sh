#!/bin/bash
# ============================================================
# Generate HyBench data using pixels-benchmark
# Usage: ./scripts/00_data_generation/gen_hybench.sh sf100
# Scales: sf100, sf1000, sf1333
# Requires: \$PIXELS_BENCHMARK_REPO cloned and built
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../env.sh"

SCALE="${1:-sf100}"
BENCH_DIR="${PIXELS_BENCHMARK_REPO}"
echo ">>> generating HyBench $SCALE using $BENCH_DIR"

case $SCALE in
    sf1)    SF="1"; ROWS=300000 ;;
    sf10)   SF="10"; ROWS=3000000 ;;
    sf100)  SF="100"; ROWS=3000000 ;;
    sf1000) SF="1000"; ROWS=3000000 ;;
    sf1333) SF="1333"; ROWS=3000000 ;;
    *) echo "unknown scale $SCALE"; exit 1 ;;
esac

cd "$BENCH_DIR" || exit 1
# See pixels-benchmark README for exact data generation command
# This script wraps the actual gen command from the repo
echo ">>> run: pixels-benchmark gen for HyBench SF${SF}"
echo ">>> TODO: fill in actual command from pixels-benchmark README"

OUT_DIR="${DATA_HYBENCH_100:-/tmp/hybench_sf${SF}}"
echo ">>> output dir: $OUT_DIR"
echo ">>> done"
