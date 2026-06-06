#!/bin/bash
# ============================================================
# RocksDB Full Compaction (before backing up retina indexes)
# Usage: ./scripts/01_environment/compact_rocksdb.sh <rocksdb_path>
#
# This runs the pixels-index testFullCompaction() method.
# Requires: PIXELS_SOURCE_DIR env var pointing to ~/projects/pixels
#
# The test at:
#   pixels-index/pixels-index-rocksdb/src/test/java/.../TestRocksDB.java
# hardcodes dbPaths in testFullCompaction(). This script patches
# the path before running the test.
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../env.sh"

DB_PATH="${1:-/home/ubuntu/disk6/collected_indexes/realtime-pixels-retina/rocksdb}"
PIXELS_DIR="${PIXELS_SOURCE_DIR:-$HOME/projects/pixels}"
TEST_CLASS="io.pixelsdb.pixels.index.rocksdb.TestRocksDB"
TEST_FILE="${PIXELS_DIR}/pixels-index/pixels-index-rocksdb/src/test/java/io/pixelsdb/pixels/index/rocksdb/TestRocksDB.java"

if [ ! -d "$DB_PATH" ]; then
    echo "ERROR: RocksDB path not found: $DB_PATH"
    exit 1
fi
if [ ! -f "$TEST_FILE" ]; then
    echo "ERROR: TestRocksDB.java not found at $TEST_FILE"
    echo "  Set PIXELS_SOURCE_DIR in env.local.sh"
    exit 1
fi

echo ">>> compacting RocksDB at: $DB_PATH"
echo ">>> test file: $TEST_FILE"
echo ""

# Patch dbPaths to point to the actual path
sed -i "s|dbPaths.add(\"/home/ubuntu/disk[0-9]/collected_indexes/realtime-pixels-retina[^\"]*/rocksdb\");|dbPaths.add(\"${DB_PATH}\");|g" "$TEST_FILE"

# Run the test
cd "${PIXELS_DIR}" || exit 1
mvn test -pl pixels-index/pixels-index-rocksdb \
    -Dtest="${TEST_CLASS}#testFullCompaction" \
    -DfailIfNoTests=false \
    -q 2>&1

RC=$?
# Restore original file
cd "${PIXELS_DIR}" && git checkout -- "$TEST_FILE" 2>/dev/null

if [ $RC -eq 0 ]; then
    echo ">>> compaction complete"
else
    echo ">>> compaction FAILED (exit code $RC)"
    exit $RC
fi
