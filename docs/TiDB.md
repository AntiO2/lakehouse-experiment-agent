# TiDB / TiFlash 测试流程

本文档按 `docs/湖仓系统标准测试模板.md` 的 9 步流程组织 TiDB 接入。

## 1. 环境准备

目标环境：

- TiDB / TiUP：v8.5.4
- PD：3 节点
- TiKV：3 节点
- TiDB：3 节点
- TiFlash：1 个物理节点上部署 2 个逻辑节点，存算分离
- TiFlash mode：强制启用 MPP
- Storage：`${S3_TIFLASH}`，默认 `s3://home-haoyue/tiflash1`
- Query entry：`${TIDB_HOST}:${TIDB_PORT}`，默认 `172.31.21.238:4000`
- Data loading：TiDB Lightning
- Monitoring：PingCAP Clinic + 本仓库资源采集脚本

环境检查：

```bash
source env.sh
./scripts/01_environment/setup_tidb.sh
```

## 2. 导入初始数据

TiDB 建表和导入复用 `pixels-benchmark` 的配置文件：

```bash
source env.sh
./scripts/02_import/import_tidb_hybench_sf100.sh
```

脚本内部执行：

```bash
cd ${PIXELS_BENCHMARK_REPO}
./pixels_bench -t sql -c conf/tidb.props -f conf/ddl_mysql.sql
tiup tidb-lightning -config conf/tidb-lightning.toml
```

导入后用 `scripts/05_validate/validate_tidb.sh` 验证 8 张 HyBench 表的行数、主键唯一性、空主键和 freshness。

## 3. 版本管理与回滚方案

每轮实验固定两个库名：

- `${TIDB_BASE_DATABASE}`：干净基线库，默认 `hybench_100_base`
- `${TIDB_TEST_DATABASE}`：本轮实验库，默认 `hybench_100_test`

备份当前库到基线库：

```bash
./scripts/03_backup/backup_tidb_database.sh
```

从基线库恢复测试库：

```bash
./scripts/03_backup/restore_tidb_database.sh
```

每轮重建 TiFlash 时使用新的 S3 root，例如 `s3://home-haoyue/tiflash_1/`、`s3://home-haoyue/tiflash_2/`，避免旧 manifest、lock、cache 干扰。

## 4. 接入 CDC / 更新写入

```bash
./scripts/04_cdc/cdc_tidb_hybench_sf100.sh
```

数据来源是 `pixels-benchmark`；写入目标是 TiDB SQL endpoint；写入方式是 JDBC batch insert/update/delete。语义约定：

- INSERT -> INSERT
- UPDATE -> UPDATE / UPSERT
- DELETE -> DELETE
- 事务隔离级别：READ-COMMITTED
- 启用 pipeline DML
- `loanapps` 和 `loantrans` 建复合索引

索引：

```bash
cd ${PIXELS_BENCHMARK_REPO}
./pixels_bench -t sql -c conf/tidb.props -f conf/create_index_A2.sql
```

具体配置以 `${PIXELS_BENCHMARK_REPO}/conf/tidb.props` 和 `/home/ubuntu/pixels-sink/conf/tidb.props` 为准。

## 5. 正确性校验

```bash
./scripts/05_validate/validate_tidb.sh
```

校验项：

- row count
- distinct pk count
- duplicate pk
- null pk
- freshness min/max

SQL 模板见 `sql/hybench/validate_tidb.sql`。

## 6. 吞吐与 Freshness 测试

```bash
./scripts/06_throughput/tidb_throughput_freshness.sh
```

吞吐指标从 `pixels_bench -t runtp` 输出中记录 `WRITE ROW PER SECOND`。

Freshness 在 PingCAP Clinic 中查看：

- `Tiflash-Summary-Cluster-Clinic`
- `Raft`
- `Raft Wait Index Duration`

主实验不要与这些任务并发：

- TiFlash replica 正在同步
- ADD INDEX 正在回填
- TiDB Lightning 正在导入
- TiKV disk 接近 80%+
- TiFlash write/compute 节点不稳定

## 7. AP 查询性能测试

静态数据：

```bash
./scripts/07_ap_query/ap_tidb_static.sh
```

更新 1% 后：

```bash
./scripts/07_ap_query/ap_tidb_after_1pct.sh
```

测试前脚本会设置：

```sql
SET GLOBAL tidb_allow_mpp = 1;
SET GLOBAL tidb_enforce_mpp = 1;
SET GLOBAL tidb_isolation_read_engines = 'tiflash';
SET SESSION tidb_allow_mpp = 1;
SET SESSION tidb_enforce_mpp = 1;
SET SESSION tidb_isolation_read_engines = 'tiflash';
```

脚本使用 `SET GLOBAL` 是因为 `pixels_bench` 会新建 JDBC 连接，单独在 `mysql` 客户端里设置 `SESSION` 不会影响 benchmark 的连接。

## 8. 资源采集

最小采集：

```bash
./scripts/08_resource/monitor_tidb.sh 1
```

额外在 PingCAP Clinic 中采集：

- Overview Cluster Clinic / CPU Usage
- TiDB Runtime Dashboard / Memory Usage
- RSS、heap_inuse、heap_unused、stack_inuse、go_runtime_metadata、free_mem_reserved_by_go

## 9. 回滚并重复实验

每轮重复：

```bash
./scripts/03_backup/restore_tidb_database.sh
./scripts/04_cdc/cdc_tidb_hybench_sf100.sh
./scripts/05_validate/validate_tidb.sh
./scripts/07_ap_query/ap_tidb_after_1pct.sh
```
