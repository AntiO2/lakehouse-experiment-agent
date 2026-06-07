#!/bin/bash
# ============================================================
# Run Pixels Benchmark TP workload against TiDB
# Usage: ./scripts/04_cdc/cdc_tidb_hybench_sf100.sh
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../env.sh"

mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/tidb_cdc_$(date +%Y%m%d_%H%M%S).log"

echo ">>> running CDC / TP workload against TiDB ${TIDB_HOST}:${TIDB_PORT}/${TIDB_DATABASE}"
echo ">>> log: ${LOG_FILE}"

cd "${PIXELS_BENCHMARK_REPO}" || exit 1
./pixels_bench -t runtp -c "${TIDB_BENCH_CONF}" -f "${TIDB_BENCH_STMT}" 2>&1 | tee "${LOG_FILE}"

echo ">>> CDC / TP workload done"
