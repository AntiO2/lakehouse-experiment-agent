# Hudi 测试流程

## 架构

```
CSV → Spark batch (bulk_insert) → Hudi (S3 + Hive Metastore)
                                      ↑
Pixels-Sink (RPC) → Spark Structured Streaming UPSERT (MoR)
```

与 Delta Lake 类似：Spark + Hive Metastore。
Hudi 使用 MoR（Merge on Read）模式，查询走 Spark SQL。

## 初始化

### 参考脚本

- `flink_jobs/hudi/` 目录下的已有脚本
- Spark 导入模式：`hoodie.datasource.write.operation=bulk_insert`

### CSV 导入

```bash
cd ${PIXELS_SPARK_REPO}
spark-submit \
  --packages org.apache.hudi:hudi-spark3.5-bundle_2.12:1.1.1,org.apache.hadoop:hadoop-aws:3.3.4 \
  --conf spark.sql.extensions=org.apache.spark.sql.hudi.HoodieSparkSessionExtension \
  --conf spark.sql.catalog.spark_catalog=org.apache.spark.sql.hudi.catalog.HoodieCatalog \
  your_hudi_import.py
```

建表示例（MoR 表）：

```sql
CREATE TABLE pixels_bench.customer (
  custid INT, companyid INT, ...
) USING hudi
TBLPROPERTIES (
  'type' = 'MERGE_ON_READ',
  'primaryKey' = 'custid',
  'preCombineField' = 'freshness_ts'
);
```

### 注册到 HMS（供 Spark/Trino 查询）

同 Delta Lake：Spark 跑 `CREATE TABLE ... USING hudi LOCATION 's3://...'` → HMS 注册 → Spark SQL 查询。

## CDC 接入

参照 Delta Lake 的 `run-delta-merge.sh`，换 Hudi 参数：

```bash
spark-submit \
  --conf "hoodie.datasource.write.operation=upsert" \
  --conf "hoodie.datasource.write.precombine.field=freshness_ts" \
  ...
```

使用 Hudi 的 `upsert` 写入模式。

## 备份

```bash
aws s3 sync ${S3_BUCKET}/hudi/<db>/ ${S3_BUCKET}/hudi/<db>.bak/
```

## 恢复

```bash
aws s3 sync --delete ${S3_BUCKET}/hudi/<db>.bak/ ${S3_BUCKET}/hudi/<db>/
```

HMS 已注册则无需重复注册。

## AP 查询（Spark SQL）

```bash
spark-sql --master spark://... \
  --conf spark.sql.catalog.spark_catalog=org.apache.spark.sql.hudi.catalog.HoodieCatalog \
  -e "SELECT COUNT(*) FROM hudi.pixels_bench.customer"
```

## 资源监控

Spark 导入/MERGE 期间：

```bash
./scripts/08_resource/monitor_flink.sh 5
# 或
pidstat -r -u -d 1 > hudi_resource.log &
```

## Compaction（MoR 必须）

MoR 表需要定期 compaction 合并 base + log 文件：

```bash
spark-submit --class org.apache.hudi.utilities.HoodieCompactor \
  --packages org.apache.hudi:hudi-utilities-bundle_2.12:1.1.1 \
  --base-path ${S3_BUCKET}/hudi/<db>/<table>
```

## 与 Delta Lake 对比

| | Delta Lake | Hudi |
|------|-----------|------|
| 写入模型 | MERGE (Spark) | UPSERT (Spark) |
| 表格式 | `_delta_log` | `.hoodie/` + timeline |
| 查询引擎 | Spark SQL / Trino | Spark SQL |
| 读取模式 | — | MoR (merge on read) |
| Compaction | VACUUM（手动） | 内置 compactor |
