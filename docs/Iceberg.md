# Iceberg 测试流程

## 架构

```
CSV(S3) → Athena INSERT SELECT → Iceberg (Glue + S3)
                                      ↑
Pixels-Sink (RPC :9091) → Flink Source → UPSERT
```

Catalog：Glue，warehouse `${S3_ICEBERG}`。

## 初始化

### 静态导入

```bash
./scripts/00_data_generation/sync_csv_to_s3.sh sf100
./scripts/02_import/import_iceberg_hybench_sf100.sh
```

### SF1000

```bash
./scripts/00_data_generation/sync_csv_to_s3.sh sf1000
# Athena INSERT，目标库 hybench_sf1000
```

## CDC 接入

详见 `docs/00_Pixels-Sink使用.md`。

```bash
cd ${PIXELS_SINK_REPO} && ./pixels-sink -c conf/pixels-sink.aws.properties
# sink.mode=flink, 端口 9091
```

限流（控制 CDC 吞吐）：

```properties
sink.datasource.rate.limit=500    # 低 / 5000 中 / -1 高
```

## 备份

```bash
./scripts/03_backup/backup_iceberg_s3.sh sf100
```

## 恢复

```bash
./scripts/03_backup/restore_iceberg_s3.sh sf100
```

S3 路径：`${S3_ICEBERG}/${DB}.db → ${DB}.db.bak`。恢复后 metadata_location 不变，Iceberg 表自动读取最新 metadata.json。

## AP 查询

```bash
./scripts/07_ap_query/ap_iceberg_static.sh    # 基线
./scripts/07_ap_query/ap_iceberg_after_1pct.sh # CDC 1% 后
```

## 资源监控

```bash
./scripts/08_resource/monitor_flink.sh 5
```

## 校验

```bash
./scripts/05_validate/validate_iceberg.sh
```

## 已知问题

1. **Glue StorageDescriptor NPE**：Flink icebergStreamWriter checkpoint 崩，需 `aws glue update-table` 补列
2. **Checkpoint**：默认 180s，`flink-conf.yaml` 控制
3. **S3 凭证**：Trino 需 `fs.native-s3.enabled=true`
4. **BIGINT/INT**：Pixels integer vs Iceberg long → Flink deserializer 兼容 4 字节 INT
