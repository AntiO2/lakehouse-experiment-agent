#!/usr/bin/env bash
set -euo pipefail

export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export SPARK_HOME=/home/ubuntu/opt/spark
export PATH="$JAVA_HOME/bin:$SPARK_HOME/bin:$PATH"

ACTION="${1:-import}"
shift || true

AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-$(aws configure get aws_access_key_id)}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-$(aws configure get aws_secret_access_key)}"
AWS_REGION="${AWS_REGION:-$(aws configure get region || true)}"
AWS_REGION="${AWS_REGION:-us-east-2}"

if [[ -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_ACCESS_KEY" ]]; then
  echo "Missing AWS credentials in environment or aws configure" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPARK_PROPS="$SCRIPT_DIR/runtime-spark-defaults.conf"
umask 077
{
  printf 'spark.sql.catalog.paimon.s3.access-key %s\n' "$AWS_ACCESS_KEY_ID"
  printf 'spark.sql.catalog.paimon.s3.secret-key %s\n' "$AWS_SECRET_ACCESS_KEY"
  printf 'spark.sql.catalog.paimon.s3.region %s\n' "$AWS_REGION"
} > "$SPARK_PROPS"

PACKAGES=(
  "org.apache.paimon:paimon-spark-3.5_2.12:1.4.1"
  "org.apache.paimon:paimon-s3:1.4.1"
  "org.apache.hadoop:hadoop-aws:3.3.4"
  "com.amazonaws:aws-java-sdk-bundle:1.12.262"
)

exec "$SPARK_HOME/bin/spark-submit" \
  --properties-file "$SPARK_PROPS" \
  --master local[13] \
  --driver-memory 72g \
  --conf spark.local.dir=/home/ubuntu/disk1/spark-tmp \
  --conf spark.sql.shuffle.partitions=512 \
  --conf spark.default.parallelism=512 \
  --conf spark.ui.showConsoleProgress=false \
  --conf spark.jars.ivy=/home/ubuntu/.ivy2 \
  --conf "spark.driver.extraJavaOptions=-Dlog4j.configurationFile=$SCRIPT_DIR/log4j2.properties" \
  --conf "spark.executor.extraJavaOptions=-Dlog4j.configurationFile=$SCRIPT_DIR/log4j2.properties" \
  --conf spark.sql.extensions=org.apache.paimon.spark.extensions.PaimonSparkSessionExtensions \
  --conf spark.sql.catalog.paimon=org.apache.paimon.spark.SparkCatalog \
  --conf spark.sql.catalog.paimon.warehouse=s3://home-dongyang/paimon \
  --conf spark.hadoop.fs.s3a.aws.credentials.provider=com.amazonaws.auth.DefaultAWSCredentialsProviderChain \
  --exclude-packages org.apache.spark:spark-hive_2.12 \
  --packages "$(IFS=,; echo "${PACKAGES[*]}")" \
  "$SCRIPT_DIR/import_hybench_sf1000_nodv_paimon.py" \
  "$ACTION" "$@"
