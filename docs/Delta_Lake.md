# Delta Lake 测试流程

## 架构

```
CSV → Spark batch → Delta Lake (S3 + Hive Metastore)
                        ↑
Pixels-Sink (RPC) → pixels-spark Structured Streaming MERGE
```

基础设施：Spark 3.5.x, Hive Metastore (thrift://127.0.0.1:9083), Trino Delta connector。

参考：[pixels-spark/docs/DELTA_LAKE_*](https://github.com/AntiO2/pixels-spark)

## 初始化

```bash
cd ${PIXELS_SPARK_REPO}
./scripts/import-benchmark-csv-to-delta.sh \
  /path/to/Data_1x /tmp/deltalake/data_1x local[1]

# 注册到 HMS（供 Trino 查询）
spark-sql --master 'local[1]' --packages io.delta:delta-spark_2.12:3.3.2,... \
  --conf spark.hadoop.hive.metastore.uris=thrift://127.0.0.1:9083 \
  -e "CREATE TABLE pixels_bench.customer USING delta LOCATION 's3://.../customer';"
```

## CDC 接入

```bash
./scripts/run-delta-merge.sh \
  --database pixels_bench --table savingaccount \
  --buckets 0 --rpc-host localhost --rpc-port 9091 \
  --metadata-host localhost --metadata-port 18888 \
  --target-path ${S3_DELTA}/savingaccount_merge \
  --checkpoint-location /tmp/savingaccount-ckpt \
  --trigger-mode once
```

Delete 语义：默认 `hard delete`。

## 备份

```bash
aws s3 sync ${S3_DELTA}/<db>/ ${S3_DELTA}/<db>.bak/
```

## 恢复

```bash
aws s3 sync --delete ${S3_DELTA}/<db>.bak/ ${S3_DELTA}/<db>/
```

恢复后 `_delta_log` 自动指向最新版本，HMS 元数据不变。

## AP 查询

```bash
cd ${PIXELS_BENCHMARK_REPO}
./pixels_bench -t runappower -c conf/delta.props -f conf/stmt_pixels.toml
```

## 资源监控

```bash
./scripts/collect-update-metrics.sh \
  --output-dir /tmp/delta-metrics/run-001 \
  --bucket ${S3_BUCKET} --region ${S3_REGION} \
  -- ./scripts/run-delta-merge.sh ...
```

输出：`sar_cpu.log, sar_mem.log, iostat.log, pidstat.log, aws/s3_requests.json`

## 已知问题

- `_delta_log` 是事务日志，不是 Iceberg 那种 snapshot
- 表需通过 Spark 注册到 HMS 后 Trino 才能查询
- Spark MERGE 对 Delta 比 Flink UPSERT 更契合
