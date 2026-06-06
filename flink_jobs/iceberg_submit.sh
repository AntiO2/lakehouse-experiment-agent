#!/bin/bash
# ============================================================
# Flink CDC: Pixels-Sink → Iceberg (upsert)
# Usage: ./flink_jobs/iceberg_submit.sh
# Requires: $FLINK_HOME, Sink running on localhost:9091
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../env.sh"

BUCKET_COUNT="${BUCKET_COUNT:-2}"
TABLES=("${HYBENCH_TABLES[@]}")
TOTAL_PARALLELISM="${TOTAL_PARALLELISM:-8}"
PIXELS_DB="${PIXELS_DB:-$PIXELS_SCHEMA_SF100}"
ICEBERG_DB="${ICEBERG_DB:-$DB_HYBENCH_SF100}"
WRITE_PARALLELISM="${WRITE_PARALLELISM:-$TOTAL_PARALLELISM}"

TEMP_SQL="dynamic_pixels_job.sql"
echo ">>> generating Flink SQL (buckets: $BUCKET_COUNT, schema: $PIXELS_DB → $ICEBERG_DB)"

for ((b=0; b<BUCKET_COUNT; b++)); do
    CUR_SQL="${TEMP_SQL%.sql}_b${b}.sql"
    > "$CUR_SQL"

    cat <<EOF >> "$CUR_SQL"
CREATE CATALOG iceberg WITH (
    'type' = 'iceberg',
    'catalog-impl' = 'org.apache.iceberg.aws.glue.GlueCatalog',
    'warehouse' = '${S3_ICEBERG}/',
    'io-impl' = 'org.apache.iceberg.aws.s3.S3FileIO',
    'format-version' = '2',
    's3.multipart.num-threads' = '10'
);
SET 'parallelism.default' = '${TOTAL_PARALLELISM}';
SET 'table.exec.iceberg.upsert-mode' = 'true';
SET 'execution.attached' = 'false';

BEGIN STATEMENT SET;

EOF

    for TABLE in "${TABLES[@]}"; do
        case $TABLE in
            customer)        FIELDS="custid INT, companyid INT, gender STRING, name STRING, age INT, phone STRING, province STRING, city STRING, loan_balance FLOAT, saving_credit INT, checking_credit INT, loan_credit INT, Isblocked INT, created_date DATE, last_update_timestamp TIMESTAMP(6), freshness_ts TIMESTAMP(6)" ;;
            company)         FIELDS="companyid INT, name STRING, category STRING, staff_size INT, loan_balance FLOAT, phone STRING, province STRING, city STRING, saving_credit INT, checking_credit INT, loan_credit INT, Isblocked INT, created_date DATE, last_update_timestamp TIMESTAMP(6), freshness_ts TIMESTAMP(6)" ;;
            savingaccount)   FIELDS="accountid INT, userid INT, balance FLOAT, Isblocked INT, ts TIMESTAMP(6), freshness_ts TIMESTAMP(6)" ;;
            checkingaccount) FIELDS="accountid INT, userid INT, balance DECIMAL(15, 2), Isblocked INT, ts TIMESTAMP(6), freshness_ts TIMESTAMP(6)" ;;
            transfer)        FIELDS="id INT, sourceid INT, targetid INT, amount FLOAT, type STRING, ts TIMESTAMP(6), freshness_ts TIMESTAMP(6)" ;;
            checking)        FIELDS="id INT, sourceid INT, targetid INT, amount FLOAT, type STRING, ts TIMESTAMP(6), freshness_ts TIMESTAMP(6)" ;;
            loanapps)        FIELDS="id INT, applicantid INT, amount FLOAT, duration INT, status STRING, ts TIMESTAMP(6), freshness_ts TIMESTAMP(6)" ;;
            loantrans)       FIELDS="id INT, applicantid INT, appid INT, amount FLOAT, status STRING, ts TIMESTAMP(6), duration INT, contract_timestamp TIMESTAMP(6), delinquency INT, freshness_ts TIMESTAMP(6)" ;;
        esac

        cat <<EOF >> "$CUR_SQL"
-- Source: $TABLE bucket $b
CREATE TABLE \`${TABLE}_src_b${b}\` (
    $FIELDS
) WITH (
    'connector' = 'pixels-sink',
    'format' = 'pixels-rowrecord',
    'pixels.host' = '${SINK_HOST:-localhost}',
    'pixels.port' = '${SINK_PORT:-9091}',
    'pixels.database' = '${PIXELS_DB}',
    'pixels.table' = '${TABLE}',
    'pixels.buckets' = '${b}'
);
INSERT INTO \`iceberg\`.\`${ICEBERG_DB}\`.\`${TABLE}\`
    /*+ OPTIONS('write-parallelism'='${WRITE_PARALLELISM}') */
    SELECT * FROM \`${TABLE}_src_b${b}\`;

EOF
    done

    echo "END;" >> "$CUR_SQL"
    echo ">>> submitting bucket ${b}..."
    "${FLINK_HOME}/bin/sql-client.sh" -f "$CUR_SQL"
    if [ $? -eq 0 ]; then
        echo ">>> bucket ${b} submitted OK"
    else
        echo ">>> bucket ${b} FAILED, check $CUR_SQL"
    fi
done
echo ">>> done: ${#TABLES[@]} tables × ${BUCKET_COUNT} buckets"
