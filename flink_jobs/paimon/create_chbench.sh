#!/bin/bash

# ================= 配置区 =================
FLINK_HOME=/home/ubuntu/opt/flink-1.20.0
DB_NAME="chbench_sf10k"

# Paimon 配置 (Flink 使用 s3a 协议)
PAIMON_WAREHOUSE="s3a://home-dongyang/paimon"
PAIMON_S3_CLEAN_PATH="s3://home-dongyang/paimon/${DB_NAME}.db"

# Iceberg 配置
ICEBERG_WAREHOUSE="s3://home-dongyang/iceberg"

# CH-benCH 业务表清单
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
# ==========================================

echo ">>> [步骤 1/3] 物理清理 Paimon 旧数据 (S3)..."
aws s3 rm --recursive "${PAIMON_S3_CLEAN_PATH}"

echo ">>> [步骤 2/3] 开始从 Iceberg 导入数据到 Paimon..."

# 记录开始总时间
START_TIME=$(date +%s)

for TABLE in "${TABLES[@]}"; do
    echo "---------------------------------------------------------------"
    echo ">>> 正在处理表: $TABLE (开始时间: $(date '+%Y-%m-%d %H:%M:%S'))"
    echo "---------------------------------------------------------------"

    # 1. 定义字段、主键和桶数 (针对 SF10k 优化)
    case $TABLE in
        warehouse)
            FIELDS="w_id INT, w_name STRING, w_street_1 STRING, w_street_2 STRING, w_city STRING, w_state STRING, w_zip STRING, w_tax FLOAT, w_ytd FLOAT, freshness_ts TIMESTAMP(6), PRIMARY KEY (w_id) NOT ENFORCED"
            B_NUM=1 ;;
        district)
            FIELDS="d_id INT, d_w_id INT, d_name STRING, d_street_1 STRING, d_street_2 STRING, d_city STRING, d_state STRING, d_zip STRING, d_tax FLOAT, d_ytd FLOAT, d_next_o_id INT, freshness_ts TIMESTAMP(6), PRIMARY KEY (d_w_id, d_id) NOT ENFORCED"
            B_NUM=1 ;;
        customer)
            FIELDS="c_id INT, c_d_id INT, c_w_id INT, c_first STRING, c_middle STRING, c_last STRING, c_street_1 STRING, c_street_2 STRING, c_city STRING, c_state STRING, c_zip STRING, c_phone STRING, c_since DATE, c_credit STRING, c_credit_lim FLOAT, c_discount FLOAT, c_balance FLOAT, c_ytd_payment FLOAT, c_payment_cnt INT, c_delivery_cnt INT, c_data STRING, c_n_nationkey INT, freshness_ts TIMESTAMP(6), PRIMARY KEY (c_w_id, c_d_id, c_id) NOT ENFORCED"
            B_NUM=128 ;;
        history)
            FIELDS="h_c_id INT, h_c_d_id INT, h_c_w_id INT, h_d_id INT, h_w_id INT, h_date TIMESTAMP(6), h_amount FLOAT, h_data STRING, freshness_ts TIMESTAMP(6), PRIMARY KEY (h_c_id, h_c_d_id, h_c_w_id, h_d_id, h_w_id, h_date) NOT ENFORCED"
            B_NUM=16 ;;
        neworder)
            FIELDS="no_o_id INT, no_d_id INT, no_w_id INT, freshness_ts TIMESTAMP(6), PRIMARY KEY (no_w_id, no_d_id, no_o_id) NOT ENFORCED"
            B_NUM=1 ;;
        order)
            FIELDS="o_id INT, o_d_id INT, o_w_id INT, o_c_id INT, o_entry_d DATE, o_carrier_id INT, o_ol_cnt INT, o_all_local INT, freshness_ts TIMESTAMP(6), PRIMARY KEY (o_w_id, o_d_id, o_id) NOT ENFORCED"
            B_NUM=4 ;;
        orderline)
            FIELDS="ol_o_id INT, ol_d_id INT, ol_w_id INT, ol_number INT, ol_i_id INT, ol_supply_w_id INT, ol_delivery_d DATE, ol_quantity INT, ol_amount FLOAT, ol_dist_info STRING, freshness_ts TIMESTAMP(6), PRIMARY KEY (ol_w_id, ol_d_id, ol_o_id, ol_number) NOT ENFORCED"
            B_NUM=256 ;;
        item)
            FIELDS="i_id INT, i_im_id INT, i_name STRING, i_price FLOAT, i_data STRING, freshness_ts TIMESTAMP(6), PRIMARY KEY (i_id) NOT ENFORCED"
            B_NUM=1 ;;
        stock)
            FIELDS="s_i_id INT, s_w_id INT, s_quantity INT, s_dist_01 STRING, s_dist_02 STRING, s_dist_03 STRING, s_dist_04 STRING, s_dist_05 STRING, s_dist_06 STRING, s_dist_07 STRING, s_dist_08 STRING, s_dist_09 STRING, s_dist_10 STRING, s_ytd INT, s_order_cnt INT, s_remote_cnt INT, s_data STRING, s_su_suppkey INT, freshness_ts TIMESTAMP(6), PRIMARY KEY (s_w_id, s_i_id) NOT ENFORCED"
            B_NUM=256 ;;
        nation)
            FIELDS="n_nationkey INT, n_name STRING, n_regionkey INT, n_comment STRING, freshness_ts TIMESTAMP(6), PRIMARY KEY (n_nationkey) NOT ENFORCED"
            B_NUM=1 ;;
        supplier)
            FIELDS="su_suppkey INT, su_name STRING, su_address STRING, su_nationkey INT, su_phone STRING, su_acctbal FLOAT, su_comment STRING, freshness_ts TIMESTAMP(6), PRIMARY KEY (su_suppkey) NOT ENFORCED"
            B_NUM=1 ;;
        region)
            FIELDS="r_regionkey INT, r_name STRING, r_comment STRING, freshness_ts TIMESTAMP(6), PRIMARY KEY (r_regionkey) NOT ENFORCED"
            B_NUM=1 ;;
    esac

    # 2. 生成该表专用的临时 SQL 文件
    TMP_SQL="task_chbench_${TABLE}.sql"
    cat <<EOF > $TMP_SQL
CREATE CATALOG paimon WITH (
    'type' = 'paimon',
    'metastore' = 'filesystem',
    'warehouse' = '${PAIMON_WAREHOUSE}'
);
CREATE CATALOG iceberg WITH (
    'type' = 'iceberg',
    'catalog-impl' = 'org.apache.iceberg.aws.glue.GlueCatalog',
    'warehouse' = '${ICEBERG_WAREHOUSE}',
    'io-impl' = 'org.apache.iceberg.aws.s3.S3FileIO'
);

SET 'execution.runtime-mode' = 'batch';
SET 'table.dml-sync' = 'true';

USE CATALOG paimon;
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
USE ${DB_NAME};

-- 创建 Paimon 表
CREATE TABLE IF NOT EXISTS \`$TABLE\` ($FIELDS) WITH (
    'bucket'             = '${B_NUM}',
    'sink.parallelism'   = '${B_NUM}',
    'file.format'        = 'parquet',
    'changelog-producer' = 'none',
    'deletion-vectors.enabled' = 'true',
    'snapshot.num-retained.max' = '200',
    'snapshot.time-retained'    = '1h',
    'write-buffer-size'  = '64mb',
    'write-buffer-spillable' = 'true',
    'compaction.max-size' = '512mb',
    'num-sorted-run.compaction-trigger' = '5',
    'num-sorted-run.stop-trigger' = '30'
);

-- 执行导入 (从 Iceberg 到 Paimon)
INSERT INTO paimon.${DB_NAME}.\`$TABLE\` 
SELECT * FROM iceberg.${DB_NAME}.\`$TABLE\`;
EOF

    # 3. 调用 Flink SQL Client 执行
    $FLINK_HOME/bin/sql-client.sh -f $TMP_SQL

    # 4. 检查退出状态
    if [ $? -eq 0 ]; then
        echo ">>> [成功] 表 $TABLE 导入完成。"
        rm $TMP_SQL
    else
        echo ">>> [失败] 表 $TABLE 导入出错。"
        exit 1
    fi
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo ">>> CH-benCH SF10k 迁移总耗时: $((DURATION / 60)) 分 $((DURATION % 60)) 秒"