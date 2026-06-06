#!/bin/bash
# ============================================================
# Validate Iceberg data: row counts, PK uniqueness
# Usage: ./scripts/05_validate/validate_iceberg.sh
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../env.sh"

TRINO="${TRINO_CLI:-$TRINO_HOME/bin/trino}"
SERVER="${HOST_TRINO:-localhost}:${TRINO_PORT}"
DB="${DB_HYBENCH_SF100}"

echo ">>> validating Iceberg ${DB}"
echo "=== row counts ==="
for TABLE in "${HYBENCH_TABLES[@]}"; do
    COUNT=$("$TRINO" --server "$SERVER" --catalog iceberg --schema "$DB" \
        --execute "SELECT COUNT(*) FROM ${TABLE}" 2>/dev/null | tail -1)
    echo "  $TABLE: $COUNT"
done

echo "=== PK checks ==="
# customer: custid, company: companyid, savingaccount: accountid,
# checkingaccount: accountid, transfer: id, checking: id,
# loanapps: id, loantrans: id
declare -A PKS=(
    [customer]=custid [company]=companyid [savingaccount]=accountid
    [checkingaccount]=accountid [transfer]=id [checking]=id
    [loanapps]=id [loantrans]=id
)

for TABLE in "${!PKS[@]}"; do
    PK="${PKS[$TABLE]}"
    DUPES=$("$TRINO" --server "$SERVER" --catalog iceberg --schema "$DB" \
        --execute "SELECT COUNT(*) FROM (SELECT ${PK}, COUNT(*) AS c FROM ${TABLE} GROUP BY ${PK} HAVING COUNT(*) > 1)" 2>/dev/null | tail -1)
    echo "  $TABLE ($PK): duplicates=$DUPES"
done
echo ">>> validation done"
