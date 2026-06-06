#!/bin/bash
# ============================================================
# Clone and build all external repositories
# Usage: ./bin/prepare_repos.sh
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../env.sh"

mkdir -p "$HOME/projects"

declare -A REPOS=(
    ["CH-benchmark"]="https://github.com/AntiO2/CH-benchmark.git"
    ["pixels-benchmark"]="https://github.com/AntiO2/pixels-benchmark.git"
    ["pixels-sink"]="https://github.com/AntiO2/pixels-sink.git"
    ["pixels-lance"]="https://github.com/AntiO2/pixels-lance.git"
    ["pixels-spark"]="https://github.com/AntiO2/pixels-spark.git"
)

for name in "${!REPOS[@]}"; do
    url="${REPOS[$name]}"
    target="$HOME/projects/${name}"

    if [ ! -d "$target" ]; then
        echo ">>> cloning $url → $target"
        git clone "$url" "$target"
    else
        echo ">>> updating $target"
        git -C "$target" pull --ff-only 2>/dev/null || echo "    (pull failed, skipping)"
    fi

    # Build if pom.xml exists
    if [ -f "$target/pom.xml" ]; then
        echo ">>> building $name ..."
        (cd "$target" && mvn package -DskipTests -q 2>/dev/null) || echo "    (build skipped or failed)"
    fi
done

echo ">>> all repos prepared"
