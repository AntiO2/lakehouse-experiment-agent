#!/bin/bash
# ============================================================
# Start Flink CDC: Pixels-Sink → Iceberg (streaming upsert)
# Usage: ./scripts/04_cdc/cdc_iceberg_hybench_sf100.sh
# Prerequisites:
#   1. Pixels-Sink running (see start_sink.sh)
#   2. Flink cluster running ($FLINK_HOME/bin/start-cluster.sh)
#   3. Iceberg tables already created + backed up
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../env.sh"

echo ">>> submitting Flink CDC: Pixels → Iceberg (hybench_sf100)"

export PIXELS_DB="${PIXELS_SCHEMA_SF100}"
export ICEBERG_DB="${DB_HYBENCH_SF100}"
export TOTAL_PARALLELISM="${TOTAL_PARALLELISM:-8}"

bash "${SCRIPT_DIR}/../../flink_jobs/iceberg_submit.sh"

echo ">>> CDC job submitted. Monitor at http://${HOST_FLINK}:${FLINK_WEBUI_PORT:-8081}"
