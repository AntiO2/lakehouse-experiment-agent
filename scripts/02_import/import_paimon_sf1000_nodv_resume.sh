#!/usr/bin/env bash
set -euo pipefail

cd /home/ubuntu/projects/paimon_hybench_sf1000_nodv

export HYBENCH_SPLITS=/home/ubuntu/disk1/Data_1000x/splits
export PAIMON_DB=hybench_sf1000_nodv
export PAIMON_ENABLE_DV=false

TABLES=customer,savingaccount,checkingaccount,checking,loanapps,loantrans

./run_paimon_import.sh import --mode overwrite --tables "$TABLES"

aws s3 sync --delete \
  s3://home-dongyang/paimon/hybench_sf1000.db/transfer/ \
  s3://home-dongyang/paimon/hybench_sf1000_nodv.db/transfer/

echo TRANSFER_COPY_DONE
