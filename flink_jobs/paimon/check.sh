#!/bin/bash

# 配置路径 (请确保末尾有 /)
S3_PATH="s3://home-dongyang/paimon/chbench_sf10k.db/"

# 推荐范围 (单位: Bytes)
MIN_SIZE=$((200 * 1024 * 1024))   # 200MB
MAX_SIZE=$((1024 * 1024 * 1024))  # 1GB

echo "正在扫描路径: $S3_PATH"
echo "目标范围: 200MB - 1GB"
echo "------------------------------------------------------------"
printf "%-70s | %-15s | %-10s\n" "Bucket Path" "Size (MB)" "Status"
echo "------------------------------------------------------------"

# 1. 获取所有包含 'bucket-' 的目录列表
# 使用 s3api list-objects-v2 获取所有对象，然后通过 awk 聚合 bucket 目录的大小
aws s3api list-objects-v2 --bucket $(echo $S3_PATH | cut -d'/' -f3) --prefix $(echo $S3_PATH | cut -d'/' -f4-) --query "Contents[?contains(Key, 'bucket-')].[Key, Size]" --output text | \
awk -v min=$MIN_SIZE -v max=$MAX_SIZE '
{
    # 提取 bucket 目录路径 (匹配到 bucket-X/ 为止)
    match($1, /.*bucket-[0-9]+\//);
    bucket_path = substr($1, RSTART, RLENGTH);
    
    # 累加每个 bucket 的大小
    sizes[bucket_path] += $2;
}
END {
    for (path in sizes) {
        size_bytes = sizes[path];
        size_mb = size_bytes / 1024 / 1024;
        
        status = "OK";
        if (size_bytes < min) status = "TOO_SMALL";
        if (size_bytes > max) status = "TOO_LARGE";
        
        printf "%-70s | %-15.2f | %-10s\n", path, size_mb, status;
    }
}' | sort

echo "------------------------------------------------------------"
echo "检查完成。"
