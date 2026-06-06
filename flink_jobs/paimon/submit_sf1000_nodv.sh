#!/bin/bash

# ================= 配置 =================
FLINK_HOME=/home/ubuntu/opt/flink-1.20.0
TEMP_SQL="paimon_ingestion_job_nodv.sql"

# 1. 物理分桶数量 (与 Source 对应)
BUCKET_COUNT=2

# 2. 数据库与路径
DB_NAME="hybench_sf1000_nodv"
PAIMON_WAREHOUSE="s3a://home-dongyang/paimon"

# 3. 基础逻辑表名
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

# 4. 并行度配置
TOTAL_PARALLELISM=8
# =======================================

echo ">>> 正在动态生成 Paimon 导入脚本 (Buckets: $BUCKET_COUNT)..."

# 按 bucket 生成并提交独立任务
for ((b=0; b<BUCKET_COUNT; b++)); do
    CUR_SQL="${TEMP_SQL%.sql}_b${b}.sql"
    echo ">>> 正在为 bucket ${b} 生成脚本: ${CUR_SQL}"

    # 清空旧脚本
    > "$CUR_SQL"

    # --- 第一部分：创建 Paimon CATALOG ---
    cat <<EOF >> "$CUR_SQL"
CREATE CATALOG paimon WITH (
    'type' = 'paimon',
    'metastore' = 'filesystem',
    'warehouse' = '${PAIMON_WAREHOUSE}'
);

EOF

    # --- 第二部分：动态生成当前 bucket 的 Source 表 DDL (Pixels) ---
    # 严格按照你提供的 Source 字段定义，保留 FLOAT 类型
    for TABLE in "${TABLES[@]}"; do
        case "$TABLE" in
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
    'pixels.database' = 'pixels_bench',
    'pixels.table' = '$TABLE',
    'pixels.buckets' = '$b'
);

EOF
    done

    # --- 第三部分：生成当前 bucket 的 DML ---
    cat <<EOF >> "$CUR_SQL"

-- 设置运行参数
SET 'parallelism.default' = '$TOTAL_PARALLELISM';
-- Paimon 要求的特定设置
SET 'execution.checkpointing.unaligned.enabled' = 'false';
SET 'table.exec.sink.upsert-materialize' = 'NONE';

-- 使用 Paimon Catalog
USE CATALOG paimon;
USE \`${DB_NAME}\`;

BEGIN STATEMENT SET;
EOF

    for TABLE in "${TABLES[@]}"; do
        # transfer 写入 append-only 表 transfer_insert，避免 bucket index OOM
        PAIMON_TABLE="$TABLE"
        if [ "$TABLE" = "transfer" ]; then
            PAIMON_TABLE="transfer_insert"
        fi
        echo "  -- 逻辑表 $TABLE → Paimon $PAIMON_TABLE, bucket $b" >> "$CUR_SQL"

        cat <<EOF >> "$CUR_SQL"
  INSERT INTO \`${PAIMON_TABLE}\`
/*+ OPTIONS(
        'sink.parallelism' = '$TOTAL_PARALLELISM'
    ) */
    SELECT * FROM default_catalog.default_database.\`${TABLE}_source_b${b}\`;

EOF
    done

    echo "END;" >> "$CUR_SQL"

    echo ">>> bucket ${b} 的脚本生成完毕: $CUR_SQL"
    echo ">>> 提交 bucket ${b} 的 Paimon 任务..."
    "$FLINK_HOME/bin/sql-client.sh" -f "$CUR_SQL"

    if [ $? -eq 0 ]; then
        echo ">>> Bucket ${b} 的 Paimon 任务提交成功！"
    else
        echo ">>> Bucket ${b} 提交失败，请检查 $CUR_SQL"
    fi

    echo "============================================================"
done

echo ">>> 逻辑表数量: ${#TABLES[@]}"
echo ">>> Bucket 数量: $BUCKET_COUNT"
echo ">>> 每个 bucket 的 8 个表共用一个 Flink 任务"
