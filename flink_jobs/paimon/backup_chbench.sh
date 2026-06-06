#!/bin/bash

# --- 配置 ---
SOURCE_S3="s3://home-dongyang/paimon/chbench_sf10k.db/"
# 建议备份路径带上时间戳或固定版本号
BACKUP_S3="s3://home-dongyang/paimon/chbench_sf10k.db.dv.bak/"

# --- 性能调优 ---
ulimit -n 100000

# 1. 核心加速参数
# 增加并发请求到 200，增大分片大小以提升大文件传输效率
echo "正在优化备份引擎参数..."
aws configure set default.s3.max_concurrent_requests 200
aws configure set default.s3.max_queue_size 20000
aws configure set default.s3.multipart_threshold 128MB
aws configure set default.s3.multipart_chunksize 128MB

# 2. 定义表清单 (按数据量从大到小排序)
TABLES=(
    "orderline"
    "stock"
    "order"
    "history"
    "customer"
    "neworder"
    "district"
    "item"
    "supplier"
    "warehouse"
    "nation"
    "region"
)

echo "开始 SF10k 级别备份..."
echo "源: $SOURCE_S3"
echo "目标: $BACKUP_S3"

# 3. 备份函数
backup_table() {
    local table=$1
    local start_t=$(date +%s)
    
    echo "[备份中] 表: $table ..."
    
    # 使用 sync 进行备份
    # S3 内部同步会自动触发 Server-Side Copy，数据不经过你的本地机器流量
    aws s3 sync "${SOURCE_S3}${table}/" "${BACKUP_S3}${table}/" --quiet
    
    local end_t=$(date +%s)
    echo "[已完成] 表: $table | 耗时: $(( (end_t - start_t) / 60 )) 分钟"
}

export -f backup_table
export SOURCE_S3 BACKUP_S3

# 4. 多进程并行备份 (同时备份 4 张表)
echo "-------------------------------------------------------"
printf "%s\n" "${TABLES[@]}" | xargs -I {} -P 4 bash -c 'backup_table "{}"'
echo "-------------------------------------------------------"

echo "所有表备份完成！"
date
