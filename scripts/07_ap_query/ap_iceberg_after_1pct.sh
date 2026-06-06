#!/bin/bash
# ============================================================
# Run AP queries after 1% CDC update on Iceberg
# Usage: ./scripts/07_ap_query/ap_iceberg_after_1pct.sh
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../env.sh"

RUN="${1:-1}"
CONFIG="${PIXELS_BENCHMARK_REPO}/conf/iceberg.props"
OUTPUT="${RESULT_DIR}/ap_iceberg_1pct_run${RUN}.csv"
mkdir -p "${RESULT_DIR}"

echo ">>> running AP benchmark (Iceberg, after 1% CDC, run ${RUN})"
echo ">>> output: ${OUTPUT}"

cd "${PIXELS_BENCHMARK_REPO}" || exit 1
./pixels_bench -t runappower -c "$CONFIG" -f conf/stmt_pixels.toml

echo ">>> done"
