#!/bin/bash
# ============================================================
# Check TiDB / TiFlash environment
# Usage: ./scripts/01_environment/setup_tidb.sh
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../env.sh"

mysql_exec() {
    MYSQL_PWD="${TIDB_PASSWORD}" mysql \
        -h "${TIDB_HOST}" -P "${TIDB_PORT}" -u "${TIDB_USER}" \
        --batch --raw --skip-column-names "$@"
}

echo ">>> TiDB endpoint: ${TIDB_USER}@${TIDB_HOST}:${TIDB_PORT}"
echo ">>> expected TiDB/TiUP version: v8.5.4"
echo ">>> TiFlash S3 root: ${S3_TIFLASH}"

command -v mysql >/dev/null || { echo "mysql client not found"; exit 1; }
command -v tiup >/dev/null || echo "warning: tiup not found; Lightning import will not run on this host"

echo "=== TiDB version ==="
mysql_exec -e "SELECT VERSION();"

echo "=== MPP variables ==="
mysql_exec -e "SHOW VARIABLES LIKE 'tidb_allow_mpp'; SHOW VARIABLES LIKE 'tidb_enforce_mpp'; SHOW VARIABLES LIKE 'tidb_isolation_read_engines';"

echo "=== TiFlash stores ==="
mysql_exec -e "SELECT store_id, address, store_state_name, engine, labels FROM information_schema.tikv_store_status WHERE engine = 'tiflash';" || true

echo ">>> environment check done"
