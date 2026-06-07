#!/bin/bash
# ============================================================
# Logical restore: clone TiDB base database to test database
# Usage: ./scripts/03_backup/restore_tidb_database.sh [base_db] [test_db]
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../env.sh"

SRC_DB="${1:-${TIDB_BASE_DATABASE}}"
DST_DB="${2:-${TIDB_TEST_DATABASE}}"

mysql_exec() {
    MYSQL_PWD="${TIDB_PASSWORD}" mysql \
        -h "${TIDB_HOST}" -P "${TIDB_PORT}" -u "${TIDB_USER}" \
        --batch --raw "$@"
}

echo ">>> restoring TiDB ${SRC_DB} -> ${DST_DB}"
mysql_exec -e "DROP DATABASE IF EXISTS ${DST_DB}; CREATE DATABASE ${DST_DB};"

for TABLE in "${HYBENCH_TABLES[@]}"; do
    echo "[$(date +%H:%M:%S)] ${TABLE} ..."
    mysql_exec -e "CREATE TABLE ${DST_DB}.${TABLE} LIKE ${SRC_DB}.${TABLE}; INSERT INTO ${DST_DB}.${TABLE} SELECT * FROM ${SRC_DB}.${TABLE};"
done

echo ">>> restore complete: ${DST_DB}"
