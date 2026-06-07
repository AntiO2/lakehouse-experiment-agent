#!/bin/bash
# ============================================================
# Run TiDB throughput workload and capture log for freshness analysis
# Usage: ./scripts/06_throughput/tidb_throughput_freshness.sh [run_id]
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../env.sh"

RUN="${1:-1}"
mkdir -p "${RESULT_DIR}" "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/tidb_throughput_run${RUN}_$(date +%Y%m%d_%H%M%S).log"

echo ">>> running TiDB throughput/freshness workload, run ${RUN}"
echo ">>> log: ${LOG_FILE}"
echo ">>> record WRITE ROW PER SECOND from this log; record Raft Wait Index Duration in PingCAP Clinic"

cd "${PIXELS_BENCHMARK_REPO}" || exit 1
./pixels_bench -t runtp -c "${TIDB_BENCH_CONF}" -f "${TIDB_BENCH_STMT}" 2>&1 | tee "${LOG_FILE}"
