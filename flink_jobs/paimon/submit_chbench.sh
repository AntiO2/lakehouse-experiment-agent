#!/bin/bash

# ================= 配置 =================
FLINK_HOME=/home/ubuntu/opt/flink-1.20.0
TEMP_SQL="chbench_paimon_ingestion.sql"

# 1. 物理分桶数量 (根据你的 Pixels Source 配置调整)
BUCKET_COUNT=2

# 2. 数据库与路径
DB_NAME="chbench_sf10k"
PAIMON_WAREHOUSE="s3a://home-dongyang/paimon"

# 3. CH-benCH 12张逻辑表
TABLES=(
    "warehouse"
    "district"
    "customer"
    "history"
    "neworder"
    "order"
    "orderline"
    "item"
    "stock"
    "nation"
    "supplier"
    "region"
)

# 4. 并行度配置
TOTAL_PARALLELISM=8
# =======================================

echo ">>> 正在动态生成 CH-benCH Paimon 导入脚本 (Buckets: $BUCKET_COUNT)..."

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
    for TABLE in "${TABLES[@]}"; do
        case "$TABLE" in
            warehouse)   FIELDS="w_id INT, w_name STRING, w_street_1 STRING, w_street_2 STRING, w_city STRING, w_state STRING, w_zip STRING, w_tax FLOAT, w_ytd FLOAT, freshness_ts TIMESTAMP(6)" ;;
            district)    FIELDS="d_id INT, d_w_id INT, d_name STRING, d_street_1 STRING, d_street_2 STRING, d_city STRING, d_state STRING, d_zip STRING, d_tax FLOAT, d_ytd FLOAT, d_next_o_id INT, freshness_ts TIMESTAMP(6)" ;;
            customer)    FIELDS="c_id INT, c_d_id INT, c_w_id INT, c_first STRING, c_middle STRING, c_last STRING, c_street_1 STRING, c_street_2 STRING, c_city STRING, c_state STRING, c_zip STRING, c_phone STRING, c_since DATE, c_credit STRING, c_credit_lim FLOAT, c_discount FLOAT, c_balance FLOAT, c_ytd_payment FLOAT, c_payment_cnt INT, c_delivery_cnt INT, c_data STRING, c_n_nationkey INT, freshness_ts TIMESTAMP(6)" ;;
            history)     FIELDS="h_c_id INT, h_c_d_id INT, h_c_w_id INT, h_d_id INT, h_w_id INT, h_date TIMESTAMP(6), h_amount FLOAT, h_data STRING, freshness_ts TIMESTAMP(6)" ;;
            neworder)    FIELDS="no_o_id INT, no_d_id INT, no_w_id INT, freshness_ts TIMESTAMP(6)" ;;
            order)       FIELDS="o_id INT, o_d_id INT, o_w_id INT, o_c_id INT, o_entry_d DATE, o_carrier_id INT, o_ol_cnt INT, o_all_local INT, freshness_ts TIMESTAMP(6)" ;;
            orderline)   FIELDS="ol_o_id INT, ol_d_id INT, ol_w_id INT, ol_number INT, ol_i_id INT, ol_supply_w_id INT, ol_delivery_d DATE, ol_quantity INT, ol_amount FLOAT, ol_dist_info STRING, freshness_ts TIMESTAMP(6)" ;;
            item)        FIELDS="i_id INT, i_im_id INT, i_name STRING, i_price FLOAT, i_data STRING, freshness_ts TIMESTAMP(6)" ;;
            stock)       FIELDS="s_i_id INT, s_w_id INT, s_quantity INT, s_dist_01 STRING, s_dist_02 STRING, s_dist_03 STRING, s_dist_04 STRING, s_dist_05 STRING, s_dist_06 STRING, s_dist_07 STRING, s_dist_08 STRING, s_dist_09 STRING, s_dist_10 STRING, s_ytd INT, s_order_cnt INT, s_remote_cnt INT, s_data STRING, s_su_suppkey INT, freshness_ts TIMESTAMP(6)" ;;
            nation)      FIELDS="n_nationkey INT, n_name STRING, n_regionkey INT, n_comment STRING, freshness_ts TIMESTAMP(6)" ;;
            supplier)    FIELDS="su_suppkey INT, su_name STRING, su_address STRING, su_nationkey INT, su_phone STRING, su_acctbal FLOAT, su_comment STRING, freshness_ts TIMESTAMP(6)" ;;
            region)      FIELDS="r_regionkey INT, r_name STRING, r_comment STRING, freshness_ts TIMESTAMP(6)" ;;
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
SET 'execution.checkpointing.unaligned.enabled' = 'false';
SET 'table.exec.sink.upsert-materialize' = 'NONE';

-- 使用 Paimon Catalog
USE CATALOG paimon;
USE \`${DB_NAME}\`;

BEGIN STATEMENT SET;
EOF

    for TABLE in "${TABLES[@]}"; do
        echo "  -- 逻辑表 $TABLE: bucket $b 写入 Paimon Sink" >> "$CUR_SQL"

        cat <<EOF >> "$CUR_SQL"
  INSERT INTO \`$TABLE\` 
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
echo ">>> 每个任务包含 12 个表的 Statement Set"