#!/bin/bash
# ============================================================
# Static import: HyBench SF100 -> TiDB via pixels_bench + TiDB Lightning
# Usage: ./scripts/02_import/import_tidb_hybench_sf100.sh
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../env.sh"

mysql_exec() {
    MYSQL_PWD="${TIDB_PASSWORD}" mysql \
        -h "${TIDB_HOST}" -P "${TIDB_PORT}" -u "${TIDB_USER}" \
        --batch --raw "$@"
}

echo ">>> importing HyBench SF100 -> TiDB ${TIDB_DATABASE}"
echo ">>> pixels benchmark repo: ${PIXELS_BENCHMARK_REPO}"

mysql_exec -e "CREATE DATABASE IF NOT EXISTS ${TIDB_DATABASE};"

cd "${PIXELS_BENCHMARK_REPO}" || exit 1
./pixels_bench -t sql -c "${TIDB_BENCH_CONF}" -f "${TIDB_DDL_FILE}"

if [ "${RUN_TIDB_LIGHTNING:-true}" = "true" ]; then
    tiup tidb-lightning -config "${TIDB_LIGHTNING_CONF}"
else
    echo ">>> RUN_TIDB_LIGHTNING=false, skipped TiDB Lightning"
fi

echo ">>> validating imported row counts"
"${SCRIPT_DIR}/../05_validate/validate_tidb.sh" "${TIDB_DATABASE}"

echo ">>> import done"
