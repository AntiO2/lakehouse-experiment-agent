# Paimon 测试流程

## 导入方式

**优先推荐 Spark 批量导入**（从 CSV 直导，可选 DV/No-DV）。
次选 Flink batch 从 Iceberg 导入。

## Spark 批量导入（推荐）

### 一键导入

```bash
# SF1000 No-DV
export HYBENCH_SPLITS=${DATA_HYBENCH_1000}
export PAIMON_DB=hybench_sf1000_nodv
export PAIMON_ENABLE_DV=false
cd ${PIXELS_BENCHMARK_REPO}
./scripts/02_import/import_paimon_spark.sh import --mode overwrite --tables customer,company,savingaccount,checkingaccount,checking,loanapps,loantrans,transfer
```

脚本自动：建库 → 建表（DV/No-DV） → 读 CSV → 写 Paimon → 校验。

### DV 表 vs No-DV 表

DV 表：`'deletion-vectors.enabled'='true'` + `'merge-engine'='deduplicate'`
No-DV 表：`'merge-engine'='deduplicate'` 不设 deletion-vectors

### transfer 表规则

不建主键，不设 merge-engine，不设 DV（append only）。

### 导入后校验

```sql
SELECT COUNT(*) FROM paimon.${DB}.customer;
SELECT COUNT(DISTINCT custID) FROM paimon.${DB}.customer;
```

```bash
aws s3 ls ${S3_PAIMON}/${DB}.db/customer/ --recursive --summarize
```

## Flink 批量导入（备选）

从已有 Iceberg 表迁移：

```bash
./scripts/02_import/import_paimon_hybench_sf100.sh
```

内部：`execution.runtime-mode=batch`，每表独立 bucket 配置。

## CDC 接入

同 Iceberg 流程，Flink 改用 Paimon Sink。

## 备份

```bash
aws s3 sync ${S3_PAIMON}/${DB}.db/ ${S3_PAIMON}/${DB}.db.bak/
```

## 恢复

```bash
aws s3 sync --delete ${S3_PAIMON}/${DB}.db.bak/ ${S3_PAIMON}/${DB}.db/
```

恢复后 Paimon 表自动可用，不需要额外注册。

## AP 查询

```bash
cd ${PIXELS_BENCHMARK_REPO}
./pixels_bench -t runappower -c conf/paimon.props -f conf/stmt_pixels.toml
```

## 资源监控

Spark 导入期间：

```bash
top -b -d 5 -p $(pgrep -f spark) > spark_cpu.log
# 或
./scripts/08_resource/monitor_flink.sh 5  # Flink CDC 期间
```

## Trino 配置（如需查询）

```properties
connector.name=paimon
metastore=filesystem
warehouse=${S3_PAIMON}
fs.native-s3.enabled=true
s3.max-connections=5000
```

## 单表重新导入（清理 orphan 文件）

```bash
aws s3 rm ${S3_PAIMON}/${DB}.db/customer/ --recursive
export PAIMON_DB=<db> PAIMON_ENABLE_DV=<true/false>
./scripts/02_import/import_paimon_spark.sh import --mode overwrite --tables customer
```
