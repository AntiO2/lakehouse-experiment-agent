#!/bin/bash
# ============================================================
# Check CDC progress by querying Iceberg table row counts
# Usage: ./scripts/04_cdc/check_progress.sh
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../env.sh"

TRINO="${TRINO_CLI:-$TRINO_HOME/bin/trino}"
SERVER="${HOST_TRINO:-localhost}:${TRINO_PORT}"
CATALOG="${1:-iceberg}"
DB="${DB_HYBENCH_SF100}"

echo ">>> CDC progress for ${CATALOG}.${DB}"
for TABLE in "${HYBENCH_TABLES[@]}"; do
    COUNT=$("$TRINO" --server "$SERVER" --catalog "$CATALOG" --schema "$DB" \
        --execute "SELECT COUNT(*) FROM ${TABLE}" 2>/dev/null | tail -1)
    echo "  $TABLE: $COUNT"
done
