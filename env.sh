#!/bin/bash
# ============================================================
# lakehouse-experiment-agent: Master Environment Configuration
# Source: source env.sh
# NOTE: This file contains NO secrets. Copy env.local.sh.example
#       to env.local.sh and fill in your actual credentials.
# ============================================================
set -a

if [ -f "${SCRIPT_DIR:-$PWD}/env.local.sh" ]; then
  source "${SCRIPT_DIR:-$PWD}/env.local.sh"
fi

# ---- Repository Paths ----
export AGENT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# ---- S3 ----
export S3_REGION="${S3_REGION:-us-east-2}"
export S3_BUCKET="${S3_BUCKET:-}"
export S3_ICEBERG="${S3_ICEBERG:-s3://${S3_BUCKET}/iceberg}"
export S3_PAIMON="${S3_PAIMON:-s3://${S3_BUCKET}/paimon}"
export S3_LANCE="${S3_LANCE:-s3://${S3_BUCKET}/lancedb}"
export S3_DELTA="${S3_DELTA:-s3://${S3_BUCKET}/deltalake}"
export S3_HUDI="${S3_HUDI:-s3://${S3_BUCKET}/hudi}"
export S3_PIXELS="${S3_PIXELS:-s3://${S3_BUCKET}/hybench}"
export S3_RETINA_CACHE="${S3_RETINA_CACHE:-s3://${S3_BUCKET}/hybench/retinaCache}"
export S3_TIFLASH="${S3_TIFLASH:-s3://${S3_BUCKET}/tiflash1}"

# ---- CSV Data Paths (local) ----
export DATA_HYBENCH_100="${DATA_HYBENCH_100:-/home/ubuntu/disk1/Data_100x/splits}"
export DATA_HYBENCH_1000="${DATA_HYBENCH_1000:-/home/ubuntu/disk1/Data_1000x/splits}"
export DATA_CHBENCH_10000="${DATA_CHBENCH_10000:-/home/ubuntu/disk5/ch10k_pixels}"

# ---- Pixels ----
export PIXELS_HOME="${PIXELS_HOME:-$HOME/opt/pixels}"
export PIXELS_SCHEMA_SF100="${PIXELS_SCHEMA_SF100:-pixels_bench_sf100x}"
export PIXELS_SCHEMA_SF1000="${PIXELS_SCHEMA_SF1000:-pixels_bench}"
export PIXELS_SCHEMA_CHBENCH="${PIXELS_SCHEMA_CHBENCH:-pixels_bench}"

# ---- Database ----
export DB_HYBENCH_SF100="${DB_HYBENCH_SF100:-hybench_sf100}"
export DB_HYBENCH_SF1000="${DB_HYBENCH_SF1000:-hybench_sf1000}"
export DB_CHBENCH_SF10K="${DB_CHBENCH_SF10K:-chbench_sf10k}"
export TIDB_DATABASE="${TIDB_DATABASE:-hybench_100}"
export TIDB_BASE_DATABASE="${TIDB_BASE_DATABASE:-hybench_100_base}"
export TIDB_TEST_DATABASE="${TIDB_TEST_DATABASE:-hybench_100_test}"

# ---- HyBench tables ----
export HYBENCH_TABLES=(
    customer company savingaccount checkingaccount
    transfer checking loanapps loantrans
)

# ---- External Repos ----
export PIXELS_BENCHMARK_REPO="${PIXELS_BENCHMARK_REPO:-$HOME/projects/pixels-benchmark}"
export PIXELS_SINK_REPO="${PIXELS_SINK_REPO:-$HOME/pixels-sink}"
export PIXELS_LANCE_REPO="${PIXELS_LANCE_REPO:-$HOME/pixels-lance}"
export PIXELS_SPARK_REPO="${PIXELS_SPARK_REPO:-$HOME/projects/pixels-spark}"
export CH_BENCHMARK_REPO="${CH_BENCHMARK_REPO:-$HOME/projects/CH-benchmark}"

# ---- TiDB ----
export TIDB_HOST="${TIDB_HOST:-172.31.21.238}"
export TIDB_PORT="${TIDB_PORT:-4000}"
export TIDB_USER="${TIDB_USER:-pixels}"
export TIDB_PASSWORD="${TIDB_PASSWORD:-}"
export TIDB_BENCH_CONF="${TIDB_BENCH_CONF:-conf/tidb.props}"
export TIDB_BENCH_STMT="${TIDB_BENCH_STMT:-conf/stmt_tidb.toml}"
export TIDB_DDL_FILE="${TIDB_DDL_FILE:-conf/ddl_mysql.sql}"
export TIDB_LIGHTNING_CONF="${TIDB_LIGHTNING_CONF:-conf/tidb-lightning.toml}"

# ---- Flink ----
export FLINK_HOME="${FLINK_HOME:-$HOME/opt/flink-1.20.0}"

# ---- Trino ----
export TRINO_HOME="${TRINO_HOME:-$HOME/opt/trino-server}"
export TRINO_PORT="${TRINO_PORT:-8080}"
export TRINO_PIXELS_PORT="${TRINO_PIXELS_PORT:-8080}"
export TRINO_PAIMON_PORT="${TRINO_PAIMON_PORT:-9080}"

# ---- Results ----
export RESULT_DIR="${RESULT_DIR:-$AGENT_ROOT/results/$(date +%Y-%m-%d)}"
export LOG_DIR="${LOG_DIR:-$AGENT_ROOT/logs/$(date +%Y-%m-%d)}"

set +a
