#!/bin/bash
# ============================================================
# Retina/Pixels 环境准备工具集
# Source this file to use helper functions, or run directly
# ============================================================

# ---- parallel_executor ----
# Run commands from a CTL file with N parallel workers
# Usage: parallel_executor <ctl_file> [threads]
parallel_executor() {
    local file_path="$1"
    local threads="${2:-8}"
    if [[ -z "$file_path" ]] || [[ ! -f "$file_path" ]]; then
        echo "File '$file_path' not found" >&2; return 1
    fi
    echo "=== parallel_executor: $file_path (threads=$threads) ==="
    local fifo=$(mktemp -u)
    mkfifo "$fifo"; exec 3<>"$fifo"; rm -f "$fifo"
    for ((i=0; i<threads; i++)); do echo >&3; done
    local success=0 fail=0
    while IFS= read -r cmd || [ -n "$cmd" ]; do
        [[ -z "${cmd// }" || "$cmd" == \#* ]] && continue
        read -r -u3
        { eval "$cmd" && ((success++)) || ((fail++)); echo >&3; } &
    done < "$file_path"
    wait
    exec 3>&-
    echo "=== done: success=$success fail=$fail ==="
}

# ---- clean_retina_checkpoints ----
# Remove checkpoint dirs on all retina nodes
# Usage: clean_retina_checkpoints [retina_file]
clean_retina_checkpoints() {
    local prop="${PIXELS_HOME}/etc/pixels.properties"
    local retina_file="${1:-$PIXELS_HOME/etc/retina}"
    local raw_dir=$(grep "^retina.checkpoint.dir" "$prop" | cut -d= -f2 | tr -d ' ')
    local target_dir="${raw_dir#file://}"
    target_dir="${target_dir:-/tmp/pixels-checkpoints}"
    echo ">>> cleaning checkpoints: $target_dir"
    grep -vE '^\s*(#|$)' "$retina_file" | while read host; do
        host=$(echo "$host" | xargs); [[ -z "$host" ]] && continue
        echo "  $host: removing $target_dir"
        ssh -o StrictHostKeyChecking=no "ubuntu@${host}" "rm -rf '$target_dir'" &
    done
    wait; echo ">>> done"
}

# ---- collect_retina_indexes_parallel ----
# Pull RocksDB + sqlite indexes from all retina nodes to local
# Usage: collect_retina_indexes_parallel [retina_file] [remote_disk] [local_base] [parallel_jobs]
collect_retina_indexes_parallel() {
    local retina_file="${1:-$PIXELS_HOME/etc/retina}"
    local remote_disk="${2:-/home/ubuntu/disk1}"
    local local_base="${3:-/home/ubuntu/disk6/collected_indexes}"
    local parallel_jobs="${4:-8}"
    [[ "$remote_disk" != */ ]] && remote_disk="$remote_disk/"
    echo ">>> collecting indexes from retina nodes (remote=$remote_disk → local=$local_base)"
    grep -vE '^\s*(#|$)' "$retina_file" | while read host; do
        host=$(echo "$host" | xargs); [[ -z "$host" ]] && continue
        mkdir -p "${local_base}/${host}"
        echo "  $host ..."
        rsync -avz --partial --numeric-ids \
            -e "ssh -o StrictHostKeyChecking=no" \
            "ubuntu@${host}:${remote_disk}" "${local_base}/${host}/" &
    done
    wait; echo ">>> done"
}

# ---- dispatch_retina_indexes_parallel ----
# Push indexes from local to all retina nodes
# Usage: dispatch_retina_indexes_parallel <local_dir> [remote_disk] [parallel_jobs]
dispatch_retina_indexes_parallel() {
    local local_base="${1:?Usage: dispatch_retina_indexes_parallel <local_dir> [remote_disk] [parallel_jobs]}"
    local remote_disk="${2:-/home/ubuntu/disk1}"
    local parallel_jobs="${3:-8}"
    [[ "$remote_disk" != */ ]] && remote_disk="$remote_disk/"
    echo ">>> dispatching indexes from $local_base → retina nodes"
    for dir in "$local_base"/*/; do
        host=$(basename "$dir")
        echo "  $host ..."
        rsync -avz --delete --partial --numeric-ids \
            -e "ssh -o StrictHostKeyChecking=no" \
            "${dir}" "ubuntu@${host}:${remote_disk}" &
    done
    wait; echo ">>> done"
}

# ---- etcd_watermark_update ----
etcd_watermark_update() {
    local ts=$(${ETCD:-$HOME/opt/etcd}/etcdctl get 'trans_id' --prefix --print-value-only=true 2>/dev/null)
    [ -z "$ts" ] && { echo "no trans_id in etcd"; return 1; }
    ts=$((ts+100000))
    local ETCDCTL_API=3
    ${ETCD}/etcdctl put trans_low_watermark "$ts"
    ${ETCD}/etcdctl put trans_high_watermark "$ts"
    ${ETCD}/etcdctl put trans_ts "$ts"
    ${ETCD}/etcdctl put trans_id "$ts"
    echo "watermark updated: $ts"
}

# ---- start_pixels ----
start_pixels() {
    ${PIXELS_HOME}/sbin/start-pixels.sh || return 1
    echo "pixels started"
}

# ---- stop_pixels ----
stop_pixels() {
    ${PIXELS_HOME}/sbin/stop-pixels.sh || return 1
    echo "pixels stopped"
}

# If run directly (not sourced), show usage
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script is meant to be sourced:"
    echo "  source scripts/01_environment/setup_retina.sh"
    echo "  # then call: clean_retina_checkpoints"
    echo "  # then call: parallel_executor conf/pixels_hybench_100.ctl 4"
fi
