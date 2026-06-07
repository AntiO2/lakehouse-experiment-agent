#!/bin/bash
# ============================================================
# Collect local host resource metrics for TiDB/TiKV/TiFlash experiments
# Usage: ./scripts/08_resource/monitor_tidb.sh [interval_sec] [output_dir]
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../env.sh"

INTERVAL="${1:-1}"
OUT_DIR="${2:-${RESULT_DIR}/tidb_resource_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "${OUT_DIR}"

echo ">>> collecting TiDB resource metrics every ${INTERVAL}s"
echo ">>> output dir: ${OUT_DIR}"
echo ">>> stop with Ctrl-C after the experiment finishes"

free -h > "${OUT_DIR}/free_initial.txt"
df -h > "${OUT_DIR}/df_initial.txt"

pidstat -r -u -d "${INTERVAL}" > "${OUT_DIR}/pidstat.log" &
PIDSTAT_PID=$!

iostat -x "${INTERVAL}" > "${OUT_DIR}/iostat.log" &
IOSTAT_PID=$!

vmstat "${INTERVAL}" > "${OUT_DIR}/vmstat.log" &
VMSTAT_PID=$!

trap 'kill "${PIDSTAT_PID}" "${IOSTAT_PID}" "${VMSTAT_PID}" 2>/dev/null || true; free -h > "${OUT_DIR}/free_final.txt"; df -h > "${OUT_DIR}/df_final.txt"; echo ">>> resource collection stopped"' EXIT

wait
