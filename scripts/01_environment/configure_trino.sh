#!/bin/bash
# ============================================================
# Deploy Trino catalog configs to all nodes
# Usage: ./scripts/01_environment/configure_trino.sh
# Requires: $TRINO_WORKERS set in env.local.sh
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../env.sh"
TEMPLATE_DIR="${SCRIPT_DIR}/../../config/trino"

echo ">>> Generating catalog configs..."
for tpl in "${TEMPLATE_DIR}"/*.template; do
    name=$(basename "$tpl" .template)
    dest="${TEMPLATE_DIR}/${name}"
    sed -e "s|\${S3_BUCKET}|${S3_BUCKET}|g" \
        -e "s|\${S3_ICEBERG}|${S3_ICEBERG}|g" \
        -e "s|\${S3_PAIMON}|${S3_PAIMON}|g" \
        -e "s|\${S3_REGION}|${S3_REGION}|g" \
        "$tpl" > "$dest"
    echo "  $name generated"
done

if [ -n "${TRINO_WORKERS}" ]; then
    echo ">>> deploying to Trino workers..."
    for worker in ${TRINO_WORKERS}; do
        echo "  $worker ..."
        scp "${TEMPLATE_DIR}"/*.properties "${worker}:${TRINO_HOME}/etc/catalog/" 2>/dev/null
    done
fi
echo ">>> done. Restart Trino to apply changes."
