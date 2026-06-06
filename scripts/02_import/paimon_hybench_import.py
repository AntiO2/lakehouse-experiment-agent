#!/usr/bin/env python3
import argparse
import os
import subprocess
import sys
import time

from pyspark.sql import SparkSession
from pyspark.sql.types import (
    DateType,
    FloatType,
    IntegerType,
    LongType,
    StringType,
    StructField,
    StructType,
    TimestampType,
)


BASE = os.environ.get("HYBENCH_SPLITS", "/home/ubuntu/disk1/Data_1000x/splits")
CATALOG = "paimon"
DB = os.environ.get("PAIMON_DB", "hybench_sf1000_nodv")
ENABLE_DV = os.environ.get("PAIMON_ENABLE_DV", "false").lower() in ("1", "true", "yes")


TABLES = {
    "customer": {
        "pk": "custID",
        "schema": StructType(
            [
                StructField("custID", IntegerType(), True),
                StructField("companyID", IntegerType(), True),
                StructField("gender", StringType(), True),
                StructField("name", StringType(), True),
                StructField("age", IntegerType(), True),
                StructField("phone", StringType(), True),
                StructField("province", StringType(), True),
                StructField("city", StringType(), True),
                StructField("loan_balance", FloatType(), True),
                StructField("saving_credit", IntegerType(), True),
                StructField("checking_credit", IntegerType(), True),
                StructField("loan_credit", IntegerType(), True),
                StructField("Isblocked", IntegerType(), True),
                StructField("created_date", DateType(), True),
                StructField("last_update_timestamp", TimestampType(), True),
                StructField("freshness_ts", TimestampType(), True),
            ]
        ),
    },
    "company": {
        "pk": "companyID",
        "schema": StructType(
            [
                StructField("companyID", IntegerType(), True),
                StructField("name", StringType(), True),
                StructField("category", StringType(), True),
                StructField("staff_size", IntegerType(), True),
                StructField("loan_balance", FloatType(), True),
                StructField("phone", StringType(), True),
                StructField("province", StringType(), True),
                StructField("city", StringType(), True),
                StructField("saving_credit", IntegerType(), True),
                StructField("checking_credit", IntegerType(), True),
                StructField("loan_credit", IntegerType(), True),
                StructField("Isblocked", IntegerType(), True),
                StructField("created_date", DateType(), True),
                StructField("last_update_timestamp", TimestampType(), True),
                StructField("freshness_ts", TimestampType(), True),
            ]
        ),
    },
    "savingaccount": {
        "pk": "accountID",
        "schema": StructType(
            [
                StructField("accountID", IntegerType(), True),
                StructField("userID", IntegerType(), True),
                StructField("balance", FloatType(), True),
                StructField("Isblocked", IntegerType(), True),
                StructField("ts", TimestampType(), True),
                StructField("freshness_ts", TimestampType(), True),
            ]
        ),
    },
    "checkingaccount": {
        "pk": "accountID",
        "schema": StructType(
            [
                StructField("accountID", IntegerType(), True),
                StructField("userID", IntegerType(), True),
                StructField("balance", FloatType(), True),
                StructField("Isblocked", IntegerType(), True),
                StructField("ts", TimestampType(), True),
                StructField("freshness_ts", TimestampType(), True),
            ]
        ),
    },
    "checking": {
        "pk": "id",
        "schema": StructType(
            [
                StructField("id", IntegerType(), True),
                StructField("sourceID", IntegerType(), True),
                StructField("targetID", IntegerType(), True),
                StructField("amount", FloatType(), True),
                StructField("type", StringType(), True),
                StructField("ts", TimestampType(), True),
                StructField("freshness_ts", TimestampType(), True),
            ]
        ),
    },
    "loanapps": {
        "pk": "id",
        "schema": StructType(
            [
                StructField("id", IntegerType(), True),
                StructField("applicantID", IntegerType(), True),
                StructField("amount", FloatType(), True),
                StructField("duration", IntegerType(), True),
                StructField("status", StringType(), True),
                StructField("ts", TimestampType(), True),
                StructField("freshness_ts", TimestampType(), True),
            ]
        ),
    },
    "loantrans": {
        "pk": "id",
        "schema": StructType(
            [
                StructField("id", IntegerType(), True),
                StructField("applicantID", IntegerType(), True),
                StructField("appID", IntegerType(), True),
                StructField("amount", FloatType(), True),
                StructField("status", StringType(), True),
                StructField("ts", TimestampType(), True),
                StructField("duration", IntegerType(), True),
                StructField("contract_timestamp", TimestampType(), True),
                StructField("delinquency", IntegerType(), True),
                StructField("freshness_ts", TimestampType(), True),
            ]
        ),
    },
    "transfer": {
        "pk": None,
        "schema": StructType(
            [
                StructField("id", LongType(), True),
                StructField("sourceID", IntegerType(), True),
                StructField("targetID", IntegerType(), True),
                StructField("amount", FloatType(), True),
                StructField("type", StringType(), True),
                StructField("ts", TimestampType(), True),
                StructField("freshness_ts", TimestampType(), True),
            ]
        ),
    },
}


ORDER = [
    "company",
    "customer",
    "savingaccount",
    "checkingaccount",
    "checking",
    "loanapps",
    "loantrans",
    "transfer",
]

KNOWN_SOURCE_COUNTS = {
    "company": 2666666,
    "customer": 400000000,
    "savingaccount": 402666666,
    "checkingaccount": 402666666,
    "checking": 800000000,
    "loanapps": 800000000,
    "loantrans": 800000000,
    "transfer": 8000000000,
}


def log(msg):
    print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {msg}", flush=True)


def qident(name):
    return f"`{name}`"


def sql_type(dtype):
    if isinstance(dtype, IntegerType):
        return "INT"
    if isinstance(dtype, LongType):
        return "BIGINT"
    if isinstance(dtype, FloatType):
        return "FLOAT"
    if isinstance(dtype, StringType):
        return "STRING"
    if isinstance(dtype, DateType):
        return "DATE"
    if isinstance(dtype, TimestampType):
        return "TIMESTAMP"
    raise TypeError(f"unsupported type: {dtype}")


def create_table_sql(table, spec):
    cols = ",\n  ".join(
        f"{qident(field.name)} {sql_type(field.dataType)}" for field in spec["schema"].fields
    )
    props = {
        "file.format": "parquet",
        "target-file-size": "256 MB",
    }
    if spec["pk"]:
        props.update(
            {
                "primary-key": spec["pk"],
                "merge-engine": "deduplicate",
            }
        )
        if ENABLE_DV:
            props["deletion-vectors.enabled"] = "true"
    prop_sql = ",\n  ".join(f"'{k}' = '{v}'" for k, v in props.items())
    return f"""
CREATE TABLE IF NOT EXISTS {CATALOG}.{DB}.{qident(table)} (
  {cols}
) TBLPROPERTIES (
  {prop_sql}
)
"""


def csv_paths(table):
    return os.path.join(BASE, table, "*.csv")


def source_line_count(table):
    if table in KNOWN_SOURCE_COUNTS:
        return KNOWN_SOURCE_COUNTS[table]
    cmd = f"find {os.path.join(BASE, table)!r} -maxdepth 1 -type f -name '*.csv' -print0 | xargs -0 wc -l | tail -n 1"
    out = subprocess.check_output(cmd, shell=True, text=True).strip()
    return int(out.split()[0])


def read_csv(spark, table, limit=None):
    reader = (
        spark.read.schema(TABLES[table]["schema"])
        .option("header", "false")
        .option("sep", ",")
        .option("nullValue", "")
        .option("emptyValue", "")
        .option("dateFormat", "yyyy-MM-dd")
        .option("timestampFormat", "yyyy-MM-dd HH:mm:ss.SSS")
        .option("mode", "FAILFAST")
        .csv(csv_paths(table))
    )
    if limit:
        return reader.limit(limit)
    return reader


def full_name(table):
    return f"{CATALOG}.{DB}.{qident(table)}"


def build_spark(app_name):
    return (
        SparkSession.builder.appName(app_name)
        .config("spark.sql.session.timeZone", "UTC")
        .getOrCreate()
    )


def preflight(spark, tables):
    log(f"running Spark/Paimon preflight base={BASE} db={DB} enable_dv={ENABLE_DV}")
    spark.sql(f"CREATE DATABASE IF NOT EXISTS {CATALOG}.{DB}")
    for table in tables:
        df = read_csv(spark, table, limit=1000)
        n = df.count()
        if n == 0:
            raise RuntimeError(f"{table}: sample read returned 0 rows")
        null_cols = [c for c in TABLES[table]["schema"].fieldNames() if c != "contract_timestamp"]
        bad = df.selectExpr(
            " OR ".join([f"`{c}` IS NULL" for c in null_cols]) + " AS has_null"
        ).where("has_null").limit(1).count()
        if bad:
            raise RuntimeError(f"{table}: sample contains unexpected NULL after parsing")
        log(f"{table}: sample OK ({n} rows)")
    log("preflight OK")


def import_tables(spark, tables, mode):
    spark.sql(f"CREATE DATABASE IF NOT EXISTS {CATALOG}.{DB}")
    log(f"import config base={BASE} db={DB} enable_dv={ENABLE_DV} mode={mode}")
    for table in tables:
        spec = TABLES[table]
        log(f"{table}: creating table")
        spark.sql(create_table_sql(table, spec))
        target = full_name(table)
        if mode == "overwrite":
            log(f"{table}: truncating existing target")
            spark.sql(f"TRUNCATE TABLE {target}")
        src_count = source_line_count(table)
        log(f"{table}: source rows={src_count}")
        df = read_csv(spark, table)
        df.createOrReplaceTempView(f"src_{table}")
        cols = ", ".join(qident(f.name) for f in spec["schema"].fields)
        start = time.time()
        log(f"{table}: insert started")
        spark.sql(f"INSERT INTO {target} SELECT {cols} FROM src_{table}")
        elapsed = time.time() - start
        log(f"{table}: insert finished in {elapsed:.1f}s")
        target_count = spark.sql(f"SELECT COUNT(*) AS c FROM {target}").collect()[0]["c"]
        log(f"{table}: target rows={target_count}")
        if target_count != src_count:
            raise RuntimeError(
                f"{table}: row count mismatch source={src_count} target={target_count}"
            )
        if spec["pk"]:
            distinct_pk = spark.sql(
                f"SELECT COUNT(DISTINCT {qident(spec['pk'])}) AS c FROM {target}"
            ).collect()[0]["c"]
            log(f"{table}: distinct {spec['pk']}={distinct_pk}")
            if distinct_pk != target_count:
                raise RuntimeError(
                    f"{table}: primary key duplicates target={target_count} distinct={distinct_pk}"
                )
    log("all imports finished")


def validate(spark, tables):
    for table in tables:
        src_count = source_line_count(table)
        target = full_name(table)
        target_count = spark.sql(f"SELECT COUNT(*) AS c FROM {target}").collect()[0]["c"]
        log(f"{table}: source={src_count} target={target_count}")
        if src_count != target_count:
            raise RuntimeError(f"{table}: source/target mismatch")
    log("validation OK")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "action", choices=["preflight", "import", "validate"], help="operation to run"
    )
    parser.add_argument("--tables", default=",".join(ORDER))
    parser.add_argument("--mode", choices=["append", "overwrite"], default="overwrite")
    args = parser.parse_args()

    tables = [t.strip() for t in args.tables.split(",") if t.strip()]
    unknown = sorted(set(tables) - set(TABLES))
    if unknown:
        raise ValueError(f"unknown tables: {unknown}")

    spark = build_spark(f"hybench-sf1000-paimon-{args.action}")
    spark.sparkContext.setLogLevel("WARN")
    try:
        if args.action == "preflight":
            preflight(spark, tables)
        elif args.action == "import":
            import_tables(spark, tables, args.mode)
        elif args.action == "validate":
            validate(spark, tables)
    finally:
        spark.stop()


if __name__ == "__main__":
    sys.exit(main())
