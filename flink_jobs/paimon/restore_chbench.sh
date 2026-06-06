#!/bin/bash

# --- 基础配置 ---
SOURCE_S3="s3://home-dongyang/paimon/chbench_sf10k.db.nodv.bak/"
DEST_S3="s3://home-dongyang/paimon/chbench_sf10k.db/"

set -e

# --- SF100 深度性能调优 ---
ulimit -n 100000

# 激进的并发配置：cp 操作比 sync 更依赖并发请求数
echo "正在针对 SF100 优化 AWS CLI 参数..."
aws configure set default.s3.max_concurrent_requests 200
aws configure set default.s3.max_queue_size 20000
aws configure set default.s3.multipart_threshold 128MB
aws configure set default.s3.multipart_chunksize 128MB
# 强制使用虚拟托管风格，有时能减少请求延迟
aws configure set default.s3.addressing_style virtual

# 表清单
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
echo "-------------------------------------------------------"
echo "开始【彻底替换式】恢复任务 (SF100)"
echo "源: $SOURCE_S3"
echo "目标: $DEST_S3"
echo "策略: 先删除目标表目录，再完整拷贝 (rm + cp)"
echo "-------------------------------------------------------"

# 4. 替换函数
replace_table() {
    local table=$1
    local start_t=$(date +%s)
    
    echo "[$(date +%H:%M:%S)] [1/2 清理] 正在删除旧表数据: $table"
    # 先彻底删除目标目录，防止旧文件残留
    aws s3 rm "${DEST_S3}${table}/" --recursive --quiet

    echo "[$(date +%H:%M:%S)] [2/2 拷贝] 正在从备份完整拷贝: $table"
    # 使用 cp 而不是 sync，确保所有文件重新写入，不进行时间戳对比
    if aws s3 cp "${SOURCE_S3}${table}/" "${DEST_S3}${table}/" --recursive --quiet; then
        local end_t=$(date +%s)
        local diff=$((end_t - start_t))
        echo "[$(date +%H:%M:%S)] [完成] 表: $table | 总耗时: $((diff / 60)) 分 $((diff % 60)) 秒"
    else
        echo "[$(date +%H:%M:%S)] [错误] 表: $table 拷贝失败！"
        exit 1
    fi
}

export -f replace_table
export SOURCE_S3 DEST_S3

# 5. 并行执行策略
# SF100 建议保持 4 个表并行，每个表内部 200 并发，总计 800 并发请求
MAX_TABLE_PARALLEL=4

echo "正在并行执行替换 (最大表并发: $MAX_TABLE_PARALLEL)"

printf "%s\n" "${TABLES[@]}" | xargs -I {} -P $MAX_TABLE_PARALLEL bash -c 'replace_table "{}"'

echo "-------------------------------------------------------"
echo "SF100 数据库【替换式】恢复全部完成！"
date
