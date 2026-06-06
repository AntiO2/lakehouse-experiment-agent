# Retina / Pixels 测试流程

## 架构

```
coordinator (MySQL + ETCD + Pixels + Trino)
    ↕
retina-server (RocksDB + S3 flush)
    ↕
Trino workers (查询 Pixels catalog)
```

Pixels 是对照系统，与 Iceberg/Paimon 平级。变量定义见 `env.sh`。

## 不同 Benchmark / 数据规模

### HyBench SF100

```bash
# 建表
./pixels_bench -r -t sql -c conf/pixels.props -f conf/ddl_pixels_aws_100.sql

# LOAD
parallel_executor conf/pixels_hybench_100.ctl 4

# 备份
meta-tool.sh dump          # → hybench_sf100.etcd + hybench_sf100_stat.sql
aws s3 sync ${S3_PIXELS}/sf100_v2/ ${S3_PIXELS}/sf100_v2.bak/
stop-retina → compact_rocksdb → collect_retina_indexes_parallel → start-retina

# 恢复
meta-tool.sh restore -e hybench_sf100.etcd -m hybench_sf100_stat.sql
dispatch_retina_indexes_parallel /home/ubuntu/disk1/hybench_index_sf100
aws s3 sync --delete ${S3_PIXELS}/sf100_v2.bak ${S3_PIXELS}/sf100_v2
```

### HyBench SF1000

```bash
# 建表
./pixels_bench -r -t sql -c conf/pixels.props -f conf/ddl_pixels_aws_1000.sql

# LOAD
parallel_executor conf/pixels_hybench_1000.ctl 2

# 备份（同上，文件名不同）
meta-tool.sh dump          # → hybench_sf1000_stat.etcd + hybench_sf1000_stat_2.sql

# 恢复
meta-tool.sh restore -e hybench_sf1000_stat.etcd -m hybench_sf1000_stat_2.sql
dispatch_retina_indexes_parallel /home/ubuntu/disk1/hybench_index_sf1000
```

### HyBench SF1200（SF1000 子集）

```bash
meta-tool.sh restore -e hybench_sf1000_stat.etcd -m hybench_sf1000_stat_2.sql
dispatch_retina_indexes_parallel /home/ubuntu/disk1/hybench_index_sf1000
```

### CHBenchmark WH10000

```bash
# 建表
./pixels_bench -r -t sql -c conf/pixels.props -f conf/chbenchmark/ddl_pixels.sql

# LOAD（参照 HyBench CTL + CHBenchmark 数据路径）

# 备份 → 产生 ch_10k_4.etcd + ch_10k_4.db
meta-tool.sh dump

# 恢复
meta-tool.sh restore -e ch_10k_4.etcd -m ch_10k_4.db
dispatch_retina_indexes_parallel /home/ubuntu/disk2/ch10k_index_2
clean_retina_checkpoints
```

### CHBenchmark Proto 注册

Proto registry key 是 `CH10K_2`，含 7 个 proto 文件（00000～00006）：

```bash
etcdctl put /sink/proto/registry/CH10K_2/files/00000.proto \
  '{"path":"file:///home/ubuntu/disk2/chbench/CH10K_2/00000.proto","created_at":"...","status":"completed"}'
# ... 00001 ~ 00006 同理
```

### 各 Benchmark 对比

| | HyBench SF100 | HyBench SF1000 | CHBenchmark WH10000 |
|------|:---:|:---:|:---:|
| Schema | `pixels_bench_sf100x` | `pixels_bench` | `pixels_bench` |
| DDL | `ddl_pixels_aws_100.sql` | `ddl_pixels_aws_1000.sql` | `chbenchmark/ddl_pixels.sql` |
| Backup etcd | `hybench_sf100.etcd` | `hybench_sf1000_stat.etcd` | `ch_10k_4.etcd` |
| Backup sql | `hybench_sf100_stat.sql` | `hybench_sf1000_stat_2.sql` | `ch_10k_4.db` |
| Index dir | `hybench_index_sf100` | `hybench_index_sf1000` | `ch10k_index_2` |
| Proto key | `hybench100` | `hybench1000` | `CH10K_2` |
| Proto count | 2 files | 1 file | 7 files |

## 初始化

### 环境启动

```bash
source scripts/01_environment/setup_retina.sh

# 启动 coordinator
cd ${PIXELS_HOME} && ./sbin/start-coordinator.sh

# 启动 retina
ssh ${RETINA_HOST} "cd ${PIXELS_HOME} && ./sbin/start-retina.sh"
```

### 元数据恢复

```bash
./sbin/meta-tool.sh restore -e <backup>.etcd -m <backup>.sql
clean_retina_checkpoints
dispatch_retina_indexes_parallel <index_dir>
```

### S3 数据

```bash
aws s3 sync --delete ${S3_PIXELS}/sf100_v2.bak ${S3_PIXELS}/sf100_v2
aws s3 rm --recursive ${S3_RETINA_CACHE}
```

## LOAD 数据

```bash
cd ${PIXELS_BENCHMARK_REPO}
parallel_executor conf/pixels_hybench_100.ctl 4
```

## 备份流程（三步）

```bash
# 1. 元数据
./sbin/meta-tool.sh dump

# 2. S3 数据
aws s3 sync ${S3_PIXELS}/sf100_v2/ ${S3_PIXELS}/sf100_v2.bak/

# 3. 索引（需先停 Retina）
./sbin/stop-retina.sh
./scripts/01_environment/compact_rocksdb.sh /path/to/rocksdb
collect_retina_indexes_parallel
./sbin/start-retina.sh
```

**注意**：`meta-tool.sh dump` / `restore` 的 etcd/sql 文件是 LOAD 完数据后自己创建的（不是预先存在的），所以每次 LOAD 新数据后都要做一次完整备份。

## 恢复流程

```bash
clean_retina_checkpoints
./sbin/meta-tool.sh restore -e <backup>.etcd -m <backup>.sql
dispatch_retina_indexes_parallel <index_dir>
aws s3 sync --delete <backup_path> <live_path>
```

## CDC 接入

详见 `docs/00_Pixels-Sink使用.md`。

Retina 模式需要 Pixels 全套基础设施：

```bash
cd ${PIXELS_SINK_REPO}
./pixels-sink -c conf/pixels-sink.retina.properties
```

关键：`sink.mode=retina`，`sink.trans.mode=batch`。

## AP 查询

```bash
cd ${PIXELS_BENCHMARK_REPO}
./pixels_bench -t runappower -c conf/pixels.props -f conf/stmt_pixels.toml
```

CHBenchmark 需设 `benchmark_type=chbenchmark`。

## 资源监控

```bash
# Flink CDC 期间
./scripts/08_resource/monitor_flink.sh 5

# Sink 期间
pidstat -r -u -d 1 > sink_resource.log &

# S3 请求
aws cloudwatch get-metric-statistics --namespace AWS/S3 --metric-name AllRequests ...
```

## 工具函数

定义在 `scripts/01_environment/setup_retina.sh`（source 后可用）：

| 函数 | 用途 |
|------|------|
| `parallel_executor <ctl> [N]` | 并行执行 CTL |
| `clean_retina_checkpoints` | 清理所有节点 checkpoint |
| `collect_retina_indexes_parallel` | 收集 RocksDB+SQLite |
| `dispatch_retina_indexes_parallel` | 分发索引到节点 |
| `etcd_watermark_update` | 更新 ETCD 水位 |

## PostgreSQL 数据源（可选）

如需 OLTP 负载 + Debezium CDC：

```bash
# WAL 设 replica, 然后
./pixels_bench -t gendata -c conf/pg.props -f conf/stmt_postgres.toml
./pixels_bench -t sql -c conf/pixels.props -f conf/ddl_pg.sql
psql -f conf/load_data_pg.sql
./pixels_bench -t sql -c conf/pixels.props -f conf/create_index_pg.sql
# OLTP
./pixels_bench -t runtp -r -c conf/pixels.props -f conf/stmt_postgres.toml
```
