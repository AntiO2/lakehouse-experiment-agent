#!/bin/bash
# ============================================================
# Static import: CSV (S3) → Iceberg (via Athena INSERT SELECT)
# Usage: ./scripts/02_import/import_iceberg_hybench_sf100.sh
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../env.sh"

SCALE="sf100"
DB="${DB_HYBENCH_SF100}"
CSV_DB="${DB}"
CSV_S3="s3://${S3_BUCKET}/data/hybench/${SCALE}/csv"
echo ">>> importing HyBench ${SCALE} → Iceberg ${DB}"

TABLES=("${HYBENCH_TABLES[@]}")

for TABLE in "${TABLES[@]}"; do
    echo ">>> $TABLE ..."

    # Drop and recreate CSV external table
    echo "DROP TABLE IF EXISTS ${TABLE}_csv;" | \
        aws athena start-query-execution \
            --query-string "DROP TABLE IF EXISTS ${TABLE}_csv" \
            --query-execution-context "Database=${CSV_DB}" \
            --work-group primary \
            --output text --query 'QueryExecutionId' 2>/dev/null

    # Create CSV external table
    echo "CREATE EXTERNAL TABLE ${TABLE}_csv (...) LOCATION '${CSV_S3}/${TABLE}/';" | \
        aws athena start-query-execution \
            --query-execution-context "Database=${CSV_DB}" \
            --work-group primary \
            --output text --query 'QueryExecutionId' 2>/dev/null

    # INSERT data
    echo "INSERT INTO ${TABLE} SELECT ... FROM ${TABLE}_csv;" | \
        aws athena start-query-execution \
            --query-execution-context "Database=${CSV_DB}" \
            --work-group primary \
            --output text --query 'QueryExecutionId' 2>/dev/null
done
echo ">>> import done"

# Validate
echo ">>> validating row counts..."
echo "SELECT '${TABLE}' AS tbl, COUNT(*) FROM ${DB}.${TABLE};" | \
    aws athena start-query-execution \
        --query-execution-context "Database=${DB}" \
        --work-group primary \
        --output text --query 'QueryExecutionId' 2>/dev/null
