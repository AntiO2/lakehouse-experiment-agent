#!/bin/bash

# ================= 配置 =================
FLINK_HOME=/home/ubuntu/opt/flink
TEMP_SQL="dynamic_pixels_job.sql"

# 1. 物理分桶数量 (如果未来增加到 4, 8，只需改这里)
BUCKET_COUNT=2

# 2. 基础逻辑表名
TABLES=(
    "customer"
    "company"
    "savingaccount"
    "checkingaccount"
    "transfer"
    "checking"
    "loanapps"
    "loantrans"
)

# 3. 并行度配置
# 建议：Source 节点总数 = TABLES数量 * BUCKET_COUNT
# Sink 写入并行度建议设为集群总 Slot 数或 BUCKET_COUNT 的倍数
TOTAL_PARALLELISM=8
# =======================================

echo ">>> 正在动态生成 SQL 脚本 (Buckets: $BUCKET_COUNT)..."

# 按 bucket 生成并提交独立任务
for ((b=0; b<BUCKET_COUNT; b++)); do
    CUR_SQL="${TEMP_SQL%.sql}_b${b}.sql"
    echo ">>> 正在为 bucket ${b} 生成脚本: ${CUR_SQL}"

    # 清空当前 bucket 的脚本
    > "$CUR_SQL"

    # --- 第一部分：创建 CATALOG ---
    cat <<EOF >> "$CUR_SQL"
CREATE CATALOG iceberg WITH (
    'type' = 'iceberg',
    'catalog-impl' = 'org.apache.iceberg.aws.glue.GlueCatalog',
    'warehouse' = 's3://home-dongyang/iceberg/',
    'io-impl' = 'org.apache.iceberg.aws.s3.S3FileIO',
    'format-version' = '2',
    's3.multipart.num-threads' = '1'
);

EOF

    # --- 第二部分：当前 bucket 的 Source 表 DDL (Pixels) ---
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
-- Source 分片: $TABLE 桶 $b
CREATE TABLE \`${TABLE}_source_b${b}\` (
    $FIELDS
) WITH (
    'connector' = 'pixels-sink',
    'format' = 'pixels-rowrecord',
    'pixels.host' = 'pixels-sink',
    'pixels.port' = '9091',
    'pixels.database' = 'pixels_bench_sf100x',
    'pixels.table' = '$TABLE',
    'pixels.buckets' = '$b'
);

EOF
    done

    # --- 第三部分：当前 bucket 的 DML ---
    cat <<EOF >> "$CUR_SQL"

-- 设置运行参数
SET 'parallelism.default' = '$TOTAL_PARALLELISM';
SET 'table.exec.iceberg.upsert-mode' = 'true';

BEGIN STATEMENT SET;
EOF

    for TABLE in "${TABLES[@]}"; do
        echo "  -- 逻辑表 $TABLE: bucket $b 写入 Iceberg Sink" >> "$CUR_SQL"
        cat <<EOF >> "$CUR_SQL"
  INSERT INTO \`iceberg\`.\`hybench_sf100\`.\`$TABLE\` 
    /*+ OPTIONS('write-parallelism'='$TOTAL_PARALLELISM') */ 
    SELECT * FROM \`${TABLE}_source_b${b}\`;
EOF
    done

    echo "END;" >> "$CUR_SQL"

    echo ">>> bucket ${b} 的脚本生成完毕: $CUR_SQL"
    echo ">>> 提交 bucket ${b} 的 Iceberg 任务..."
    "$FLINK_HOME/bin/sql-client.sh" -f "$CUR_SQL"

    if [ $? -eq 0 ]; then
        echo ">>> Bucket ${b} 的 Iceberg 任务提交成功！"
    else
        echo ">>> Bucket ${b} 提交失败，请检查 $CUR_SQL"
    fi

    echo "============================================================"
done

echo ">>> 逻辑表数量: ${#TABLES[@]}"
echo ">>> Bucket 数量: $BUCKET_COUNT"
echo ">>> 每个 bucket 的 ${#TABLES[@]} 个表共用一个 Flink 任务"
