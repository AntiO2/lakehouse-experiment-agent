#!/bin/bash

# ================= 配置 =================
# 根据你的环境修改 Trino 命令行工具路径和地址
TRINO_EXEC="trino" 
TRINO_SERVER="http://trino-coordinator:8080"
CATALOG="paimon"
SCHEMA="chbench_sf10k"

# =======================================

echo ">>> 正在通过 Trino 查询 Paimon 表行数并核对 SF10k 标准数据..."

# 构造 SQL 语句
# 注意：Trino 中关键字 order 必须加双引号 "order"
QUERY=$(cat <<EOF
WITH actual_counts AS (
    SELECT 'nation' as table_name, count(*) as cnt FROM ${CATALOG}.${SCHEMA}.nation
    UNION ALL SELECT 'region', count(*) FROM ${CATALOG}.${SCHEMA}.region
    UNION ALL SELECT 'supplier', count(*) FROM ${CATALOG}.${SCHEMA}.supplier
    UNION ALL SELECT 'warehouse', count(*) FROM ${CATALOG}.${SCHEMA}.warehouse
    UNION ALL SELECT 'district', count(*) FROM ${CATALOG}.${SCHEMA}.district
    UNION ALL SELECT 'item', count(*) FROM ${CATALOG}.${SCHEMA}.item
    UNION ALL SELECT 'order', count(*) FROM ${CATALOG}.${SCHEMA}."order"
    UNION ALL SELECT 'neworder', count(*) FROM ${CATALOG}.${SCHEMA}.neworder
    UNION ALL SELECT 'history', count(*) FROM ${CATALOG}.${SCHEMA}.history
    UNION ALL SELECT 'customer', count(*) FROM ${CATALOG}.${SCHEMA}.customer
    UNION ALL SELECT 'orderline', count(*) FROM ${CATALOG}.${SCHEMA}.orderline
    UNION ALL SELECT 'stock', count(*) FROM ${CATALOG}.${SCHEMA}.stock
),
expected_counts AS (
    SELECT * FROM (VALUES 
        ('nation', 62),
        ('region', 5),
        ('supplier', 10000),
        ('warehouse', 10000),
        ('district', 100000),
        ('item', 100000),
        ('order', 300000000),
        ('neworder', 90000000),
        ('history', 300000000),
        ('customer', 300000000),
        ('orderline', 3000000000),
        ('stock', 1000000000)
    ) AS t (table_name, exp_cnt)
)
SELECT 
    a.table_name,
    a.cnt AS actual_cnt,
    e.exp_cnt AS expected_cnt,
    (a.cnt - e.exp_cnt) AS diff,
    CASE 
        WHEN a.cnt = e.exp_cnt THEN '✅ MATCH' 
        ELSE '❌ MISMATCH' 
    END AS status
FROM actual_counts a
JOIN expected_counts e ON a.table_name = e.table_name
ORDER BY e.exp_cnt ASC;
EOF
)

# 执行 Trino 查询
$TRINO_EXEC --server $TRINO_SERVER --execute "$QUERY" --output-format ALIGNED

if [ $? -eq 0 ]; then
    echo ">>> 检查完成。"
else
    echo ">>> 查询失败，请检查 Trino 连接或 Catalog 配置。"
fi