#!/bin/bash
# ============================================================
# Run AP queries on static Iceberg data (baseline, pre-CDC)
# Usage: ./scripts/07_ap_query/ap_iceberg_static.sh
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../env.sh"

RUN="${1:-1}"
CONFIG="${PIXELS_BENCHMARK_REPO}/conf/iceberg.props"
OUTPUT="${RESULT_DIR}/ap_iceberg_static_run${RUN}.csv"
mkdir -p "${RESULT_DIR}"

echo ">>> running AP benchmark (Iceberg, static, run ${RUN})"
echo ">>> output: ${OUTPUT}"

cd "${PIXELS_BENCHMARK_REPO}" || exit 1
./pixels_bench -t runappower -c "$CONFIG" -f conf/stmt_pixels.toml

echo ">>> done"
