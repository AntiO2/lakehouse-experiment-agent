#!/bin/bash
# ============================================================
# Validate TiDB data: row counts, PK uniqueness, null PK, freshness
# Usage: ./scripts/05_validate/validate_tidb.sh [database]
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../env.sh"

DB="${1:-${TIDB_DATABASE}}"

mysql_exec() {
    MYSQL_PWD="${TIDB_PASSWORD}" mysql \
        -h "${TIDB_HOST}" -P "${TIDB_PORT}" -u "${TIDB_USER}" \
        --database "${DB}" --batch --raw --skip-column-names "$@"
}

declare -A PKS=(
    [customer]=custid [company]=companyid [savingaccount]=accountid
    [checkingaccount]=accountid [transfer]=id [checking]=id
    [loanapps]=id [loantrans]=id
)

echo ">>> validating TiDB ${DB}"
echo "=== row counts ==="
for TABLE in "${HYBENCH_TABLES[@]}"; do
    COUNT=$(mysql_exec -e "SELECT COUNT(*) FROM ${TABLE};")
    echo "  ${TABLE}: ${COUNT}"
done

echo "=== PK checks ==="
for TABLE in "${HYBENCH_TABLES[@]}"; do
    PK="${PKS[$TABLE]}"
    DISTINCT_PK=$(mysql_exec -e "SELECT COUNT(DISTINCT ${PK}) FROM ${TABLE};")
    DUPES=$(mysql_exec -e "SELECT COUNT(*) FROM (SELECT ${PK} FROM ${TABLE} GROUP BY ${PK} HAVING COUNT(*) > 1) d;")
    NULLS=$(mysql_exec -e "SELECT COUNT(*) FROM ${TABLE} WHERE ${PK} IS NULL;")
    echo "  ${TABLE} (${PK}): distinct=${DISTINCT_PK}, duplicates=${DUPES}, nulls=${NULLS}"
done

echo "=== freshness ==="
for TABLE in "${HYBENCH_TABLES[@]}"; do
    FRESHNESS=$(mysql_exec -e "SELECT COALESCE(CAST(MIN(freshness_ts) AS CHAR), 'NULL'), COALESCE(CAST(MAX(freshness_ts) AS CHAR), 'NULL') FROM ${TABLE};")
    echo "  ${TABLE}: ${FRESHNESS}"
done

echo ">>> validation done"
