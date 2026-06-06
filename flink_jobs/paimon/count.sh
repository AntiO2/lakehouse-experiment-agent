#!/bin/bash

# ================= 配置区 =================
TRINO_SERVER="http://trino-coordinator:8080"
CATALOG="paimon"
SCHEMA="hybench_sf1000"
USER="ubuntu"

# 定义期望的 Iceberg 数值 (硬编码)
declare -A EXPECTED_COUNTS
EXPECTED_COUNTS["customer"]=30000000
EXPECTED_COUNTS["company"]=200000
EXPECTED_COUNTS["savingaccount"]=30200000
EXPECTED_COUNTS["checkingaccount"]=30200000
EXPECTED_COUNTS["transfer"]=600000000
EXPECTED_COUNTS["checking"]=60000000
EXPECTED_COUNTS["loanapps"]=60000000
EXPECTED_COUNTS["loantrans"]=60000000

# 定义表查询顺序
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

# 检查 trino 客户端是否存在
if [ ! -f "./trino" ]; then
    echo "错误: 当前目录下未找到 ./trino 客户端。"
    exit 1
fi

echo ">>> 开始验证 Paimon 数据量 (对比基准: Iceberg 固定值)..."
echo "--------------------------------------------------------------------------------------------"
printf "%-20s | %-15s | %-15s | %-10s\n" "Table Name" "Paimon Count" "Iceberg (Ref)" "Result"
echo "--------------------------------------------------------------------------------------------"

for TABLE in "${TABLES[@]}"; do
    # 获取 Paimon 的实时 count
    COUNT_P=$(./trino --server "${TRINO_SERVER}" \
                   --catalog "${CATALOG}" \
                   --schema "${SCHEMA}" \
                   --user "${USER}" \
                   --execute "SELECT count(*) FROM \"${TABLE}\"" \
                   --output-format CSV 2>/dev/null | tr -d '"')

    # 获取预设的 Iceberg 数值
    COUNT_I=${EXPECTED_COUNTS[$TABLE]}

    # 容错处理：如果查询失败
    if [[ ! $COUNT_P =~ ^[0-9]+$ ]]; then
        DISPLAY_P="Error"
        RESULT="ERROR"
    else
        DISPLAY_P=$COUNT_P
        # 对比逻辑
        if [ "$COUNT_P" -eq "$COUNT_I" ]; then
            RESULT="MATCH"
        else
            RESULT="MISMATCH"
        fi
    fi

    printf "%-20s | %-15s | %-15s | %-10s\n" "$TABLE" "$DISPLAY_P" "$COUNT_I" "$RESULT"
done

echo "--------------------------------------------------------------------------------------------"
echo ">>> 验证完成。"
