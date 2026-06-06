#!/bin/bash
# ============================================================
# Monitor Flink JVM resource usage (CPU, heap, managed, direct)
# Usage: ./scripts/08_resource/monitor_flink.sh [interval_sec] [output_file]
# Output: CSV with timestamp,cpu%,jvm_heap_bytes,jvm_noheap_bytes,...
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTERVAL="${1:-5}"
OUTPUT="${2:-${RESULT_DIR}/flink_metrics_$(date +%Y%m%d_%H%M%S).csv}"
mkdir -p "$(dirname "$OUTPUT")"

echo "timestamp,host,pid,role,cpu_pct,jvm_heap_bytes,jvm_noheap_bytes,jvm_managed_bytes,jvm_direct_bytes" > "$OUTPUT"
echo "[monitor] interval=${INTERVAL}s, output=$OUTPUT"

while true; do
    TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    PIDS=$(jps -l 2>/dev/null | grep -E 'TaskManagerRunner|JobManager|StandaloneSession' | awk '{print $1":"$2}')
    [ -z "$PIDS" ] && PIDS=$(ps -eo pid,comm | grep -E 'java.*flink' | grep -v grep | awk '{print $1":flink"}')

    for entry in $PIDS; do
        PID=${entry%%:*}
        NAME=${entry##*:}
        CPU=$(ps -p $PID -o pcpu= 2>/dev/null | tr -d ' ')
        JSTAT=$(jstat -gc $PID 2>/dev/null | tail -1)
        HEAP=0; NOHEAP=0
        if [ -n "$JSTAT" ]; then
            HEAP=$(( ($(echo $JSTAT | awk '{print $4+$5+$6+$8}') ) * 1024 ))
            NOHEAP=$(( ($(echo $JSTAT | awk '{print $10+$12}') ) * 1024 ))
        fi
        NMT=$(jcmd $PID VM.native_memory summary 2>/dev/null)
        MANAGED_BYTES=0; DIRECT_BYTES=0
        if echo "$NMT" | grep -q 'Internal'; then
            M=$(echo "$NMT" | awk '/Internal/{found=1} found && /committed/{sub(/.*committed=/,""); print $1; exit}')
            [ -n "$M" ] && MANAGED_BYTES=$(( M * 1048576 ))
            D=$(echo "$NMT" | awk '/- *Direct/{found=1} found && /committed/{sub(/.*committed=/,""); print $1; exit}')
            [ -n "$D" ] && DIRECT_BYTES=$(( D * 1048576 ))
        fi
        echo "$TS,$(hostname),$PID,$NAME,${CPU:-0},${HEAP:-0},${NOHEAP:-0},${MANAGED_BYTES:-0},${DIRECT_BYTES:-0}" >> "$OUTPUT"
    done
    sleep "$INTERVAL"
done
