# Pixels-Sink 使用指南

## 启动

```bash
cd ${PIXELS_SINK_REPO}
./pixels-sink -c <config_file>
```

常用配置文件：

| 配置 | 说明 |
|------|------|
| `conf/pixels-sink.aws.properties` | AWS 环境，PostgreSQL + Retina 模式 |
| `conf/pixels-sink.flink.properties.hybench` | Flink 模式（CDC RPC 服务，供 Flink/Lance 拉取） |
| `conf/pixels-sink.ch.properties` | CHBenchmark 专用 |
| `conf/pixels-sink.hudi.properties` | Hudi 专用 |

## 关键配置参数

### 数据源 (`sink.datasource`)

| 值 | 说明 |
|------|------|
| `engine` | Debezium Engine 直连 PostgreSQL WAL 读 CDC |
| `storage` | 从 proto 文件读取 CDC（效率最高，论文实验用） |
| `kafka` | 从 Kafka 消费（已废弃，不推荐） |

### 写入模式 (`sink.mode`)

| 值 | 说明 |
|------|------|
| `retina` | 写入 Pixels Retina |
| `flink` | 启动 RPC 服务器（端口 9091），供 Flink/Lance 拉取 |
| `csv` | 调试模式，输出 CSV |
| `proto` | 序列化为 proto 文件 + ETCD 注册（供 `storage` 源读取） |
| `none` | 不写输出，仅观测 source 指标 |

### 限流

```properties
# 速率限制（-1 无限制）
sink.datasource.rate.limit=10000

# 限流器类型
sink.datasource.rate.limit.type=guava    # 或 semaphore
```

实验时通过调整 `sink.datasource.rate.limit` 控制 CDC 吞吐档位：

| 吞吐 | 建议值 |
|------|--------|
| 低 | 500 |
| 中 | 5000 |
| 高 | -1（不限） |

## 监控输出

### 吞吐报告

```properties
sink.monitor.report.enable=true
sink.monitor.report.interval=5000                      # 报告间隔 ms
sink.monitor.report.file=/path/to/rate_hybench.csv     # 输出文件
```

输出 CSV：行数、事务数、serdRows/serdTxs，每 5 秒一行。

示例日志：

```
Performance report: +100000 rows (+9999.13/s), +13945 transactions (+1394.38/s)
```

### 新鲜度监控

新鲜度通过 Trino JDBC 查询目标表 `max(freshness_ts)`，有三种模式：

```properties
# 模式：row | txn | embed（推荐 embed）
sink.monitor.freshness.level=embed

# embed 模式的 Trino 连接（必须配置）
trino.url=jdbc:trino://trino-coordinator:8080/iceberg/hybench_sf100
trino.user=pixels
trino.password=password
trino.parallel=4

# 输出文件
sink.monitor.freshness.file=/path/to/freshness.csv
```

**注意**：
- `level=embed` 需要表最后一列是 `freshness_ts`
- Trino URL 连接的是**目标格式的 catalog**（Iceberg/Paimon 等），不是 Pixels catalog
- 如果不需要 freshness 监控，设 `sink.monitor.freshness.level=row` 或直接注释掉 Trino 配置

### Prometheus 指标（可选）

```properties
sink.monitor.enable=true
sink.monitor.port=9464         # 默认 Prometheus metrics 端口
```

## Flink 模式 (`sink.mode=flink`)

启动 RPC 服务器，端口 9091，Flink/Lance 通过 gRPC 拉取 CDC 数据。

```properties
sink.datasource=storage
sink.mode=flink
sink.flink.server.port=9091
```

**不需要**：Trino 配置、Retina daemon、RocksDB。

Flink Source（`pixels-flink`）通过 `pixels-sink:9091` 连接拉数据。

## Retina 模式 (`sink.mode=retina`)

需要 Pixels 全套基础设施：MySQL + ETCD + Coordinator + Retina daemon。

```properties
sink.datasource=storage
sink.mode=retina
sink.retina.client=8                # Retina 客户端线程数
sink.retina.log.queue=false
sink.trans.mode=batch               # 事务模式：single | record | batch
sink.commit.batch.size=200          # Commit batch 大小
```

## Proto 模式 (`sink.mode=proto`)

将 CDC 事件序列化为 proto 文件，注册到 ETCD。生成的文件可供 `sink.datasource=storage` 读取。

```properties
sink.datasource=engine               # 从 PostgreSQL 直读
sink.mode=proto
sink.proto.dir=/path/to/proto/output
sink.proto.data=hybench100           # 数据集名（对应 ETCD registry key）
sink.proto.maxRecords=100000         # 每个 proto 文件最大记录数
```

## 三种 CDC 模式总结

```
                    ┌─ sink.mode=flink ──→ RPC :9091 → Flink/Lance 拉取
                    │
PostgreSQL ──→ Debezium ──→ Pixels-Sink ──→ sink.mode=retina → Pixels Retina
                    │
                    └─ sink.mode=proto  ──→ proto files + ETCD → sink.datasource=storage 复用
```

## 实验中的实际用法

### Iceberg/Paimon/Lance CDC

```bash
cd ${PIXELS_SINK_REPO}
# flink 模式 + configure.properties 中设定 rate.limit
./pixels-sink -c conf/pixels-sink.aws.properties
```

### Retina CDC

```bash
cd ${PIXELS_SINK_REPO}
./pixels-sink -c conf/pixels-sink.retina.properties
```

### 调整吞吐（修改配置文件后重启）

```properties
# 不限速
sink.datasource.rate.limit=-1

# 限速 500 row/sec
sink.datasource.rate.limit=500
```
