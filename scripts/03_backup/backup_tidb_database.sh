#!/bin/bash
# ============================================================
# Logical backup: clone TiDB source database to base database
# Usage: ./scripts/03_backup/backup_tidb_database.sh [source_db] [base_db]
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../env.sh"

SRC_DB="${1:-${TIDB_DATABASE}}"
DST_DB="${2:-${TIDB_BASE_DATABASE}}"

mysql_exec() {
    MYSQL_PWD="${TIDB_PASSWORD}" mysql \
        -h "${TIDB_HOST}" -P "${TIDB_PORT}" -u "${TIDB_USER}" \
        --batch --raw "$@"
}

echo ">>> backing up TiDB ${SRC_DB} -> ${DST_DB}"
mysql_exec -e "DROP DATABASE IF EXISTS ${DST_DB}; CREATE DATABASE ${DST_DB};"

for TABLE in "${HYBENCH_TABLES[@]}"; do
    echo "[$(date +%H:%M:%S)] ${TABLE} ..."
    mysql_exec -e "CREATE TABLE ${DST_DB}.${TABLE} LIKE ${SRC_DB}.${TABLE}; INSERT INTO ${DST_DB}.${TABLE} SELECT * FROM ${SRC_DB}.${TABLE};"
done

echo ">>> backup complete: ${DST_DB}"
