#!/bin/bash

# ================= 配置区 =================
FLINK_HOME=/home/ubuntu/opt/flink-1.20.0
DB_NAME="hybench_sf100"

# Paimon 配置
PAIMON_WAREHOUSE="s3a://home-dongyang/paimon"
PAIMON_S3_CLEAN_PATH="s3://home-dongyang/paimon/${DB_NAME}.db"

# Iceberg 配置
ICEBERG_WAREHOUSE="s3://home-dongyang/iceberg"

# 业务表清单
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
# ==========================================

# echo ">>> [步骤 1/3] 物理清理 Paimon 旧数据..."
aws s3 rm --recursive "${PAIMON_S3_CLEAN_PATH}"

echo ">>> [步骤 2/3] 开始按顺序逐个表导入数据..."

# 记录开始总时间
START_TIME=$(date +%s)

for TABLE in "${TABLES[@]}"; do
    echo "---------------------------------------------------------------"
    echo ">>> 正在处理表: $TABLE (开始时间: $(date '+%Y-%m-%d %H:%M:%S'))"
    echo "---------------------------------------------------------------"

    # 1. 根据表名定义字段和固定桶数
    case $TABLE in
        customer)        
            FIELDS="custid INT, companyid INT, gender STRING, name STRING, age INT, phone STRING, province STRING, city STRING, loan_balance float, saving_credit INT, checking_credit INT, loan_credit INT, Isblocked INT, created_date DATE, last_update_timestamp TIMESTAMP(6), freshness_ts TIMESTAMP(6), PRIMARY KEY (custid) NOT ENFORCED"
            B_NUM=2 ;;
        company)         
            FIELDS="companyid INT, name STRING, category STRING, staff_size INT, loan_balance float, phone STRING, province STRING, city STRING, saving_credit INT, checking_credit INT, loan_credit INT, Isblocked INT, created_date DATE, last_update_timestamp TIMESTAMP(6), freshness_ts TIMESTAMP(6), PRIMARY KEY (companyid) NOT ENFORCED"
            B_NUM=1 ;;
        savingaccount)   
            FIELDS="accountid INT, userid INT, balance float, Isblocked INT, ts TIMESTAMP(6), freshness_ts TIMESTAMP(6), PRIMARY KEY (accountid) NOT ENFORCED"
            B_NUM=2 ;;
        checkingaccount) 
            FIELDS="accountid INT, userid INT, balance float, Isblocked INT, ts TIMESTAMP(6), freshness_ts TIMESTAMP(6), PRIMARY KEY (accountid) NOT ENFORCED"
            B_NUM=2 ;;
        transfer)        
            FIELDS="id BIGINT, sourceid INT, targetid INT, amount float, type STRING, ts TIMESTAMP(6), freshness_ts TIMESTAMP(6), PRIMARY KEY (id) NOT ENFORCED"
            B_NUM=32 ;;
        checking)        
            FIELDS="id INT, sourceid INT, targetid INT, amount float, type STRING, ts TIMESTAMP(6), freshness_ts TIMESTAMP(6), PRIMARY KEY (id) NOT ENFORCED"
            B_NUM=4 ;;
        loanapps)        
            FIELDS="id INT, applicantid INT, amount float, duration INT, status STRING, ts TIMESTAMP(6), freshness_ts TIMESTAMP(6), PRIMARY KEY (id) NOT ENFORCED"
            B_NUM=4 ;;
        loantrans)       
            FIELDS="id INT, applicantid INT, appid INT, amount float, status STRING, ts TIMESTAMP(6), duration INT, contract_timestamp TIMESTAMP(6), delinquency INT, freshness_ts TIMESTAMP(6), PRIMARY KEY (id) NOT ENFORCED"
            B_NUM=4 ;;
    esac

    # 2. 生成该表专用的临时 SQL 文件
    TMP_SQL="task_${TABLE}.sql"
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

-- 创建 Paimon 表 (使用固定桶模式)
CREATE TABLE IF NOT EXISTS \`$TABLE\` ($FIELDS) WITH (
    'bucket'             = '${B_NUM}',      -- 使用预设的固定桶数
    'sink.parallelism' = '${B_NUM}',
    'file.format'        = 'parquet',
    'changelog-producer' = 'none',
    'deletion-vectors.enabled' = 'true',
    'snapshot.num-retained.max' = '200',
    'snapshot.time-retained'    = '1h',
    'write-buffer-size' = '64mb',
    'write-buffer-spillable' = 'true',
    'compaction.max-size' = '512mb',
    'num-sorted-run.compaction-trigger' = '5',
    'num-sorted-run.stop-trigger' = '30'
);

-- 执行导入
INSERT INTO paimon.${DB_NAME}.\`$TABLE\` SELECT * FROM iceberg.${DB_NAME}.\`$TABLE\`;
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
echo ">>> 总耗时: $((DURATION / 60)) 分 $((DURATION % 60)) 秒"
