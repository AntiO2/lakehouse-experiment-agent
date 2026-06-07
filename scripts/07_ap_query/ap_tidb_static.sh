#!/bin/bash
# ============================================================
# Run AP queries on static TiDB data (baseline, pre-CDC)
# Usage: ./scripts/07_ap_query/ap_tidb_static.sh [run_id]
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../env.sh"

RUN="${1:-1}"
mkdir -p "${RESULT_DIR}" "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/ap_tidb_static_run${RUN}_$(date +%Y%m%d_%H%M%S).log"

echo ">>> running AP benchmark (TiDB/TiFlash, static, run ${RUN})"
echo ">>> log: ${LOG_FILE}"

MYSQL_PWD="${TIDB_PASSWORD}" mysql -h "${TIDB_HOST}" -P "${TIDB_PORT}" -u "${TIDB_USER}" --database "${TIDB_DATABASE}" \
    -e "SET GLOBAL tidb_allow_mpp = 1; SET GLOBAL tidb_enforce_mpp = 1; SET GLOBAL tidb_isolation_read_engines = 'tiflash'; SET SESSION tidb_allow_mpp = 1; SET SESSION tidb_enforce_mpp = 1; SET SESSION tidb_isolation_read_engines = 'tiflash';"

cd "${PIXELS_BENCHMARK_REPO}" || exit 1
./pixels_bench -t runappower -c "${TIDB_BENCH_CONF}" -f "${TIDB_BENCH_STMT}" 2>&1 | tee "${LOG_FILE}"

echo ">>> done"
