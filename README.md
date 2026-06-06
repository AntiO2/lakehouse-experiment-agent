# lakehouse-experiment-agent

统一的湖仓格式（Iceberg / Paimon / Lance / Delta Lake / Retina）测试工具，
基于 [湖仓系统标准测试模板](docs/湖仓系统标准测试模板.md) 的 9 步标准流程。

## 支持的格式与数据集

| 格式 | HyBench SF100 | HyBench SF1000 | CHBenchmark WH10000 |
|------|:---:|:---:|:---:|
| Iceberg | ✓ | ✓ | ✓ |
| Paimon | ✓ | ✓ | |
| Lance | ✓ | | |
| Delta Lake | ✓ | | |
| Hudi | ✓ | ✓ | |
| Retina / Pixels | ✓ | ✓ | ✓ |

## 快速开始

### 1. 克隆并配置

```bash
cd ~/Projects
git clone <repo-url> lakehouse-experiment-agent
cd lakehouse-experiment-agent
cp env.local.sh.example env.local.sh
# 编辑 env.local.sh，填入你的密钥、S3 bucket、集群 IP
vim env.local.sh
```

### 2. 准备仓库

```bash
source env.sh
./bin/prepare_repos.sh
```

### 3. 跑一个完整实验

```bash
# 例如：Iceberg + HyBench SF100
source env.sh
./scripts/02_import/import_iceberg_hybench_sf100.sh    # 初始导入
./scripts/03_backup/backup_iceberg_s3.sh               # 备份
./scripts/04_cdc/cdc_iceberg_hybench_sf100.sh           # 启动 CDC
./scripts/07_ap_query/ap_iceberg_static.sh              # AP baseline
./scripts/07_ap_query/ap_iceberg_after_1pct.sh          # AP after 1% CDC
```

## 目录结构

```
├── env.sh                    # 变量定义（无密钥）
├── env.local.sh.example      # 密钥模板
├── bin/                      # 顶层脚本
│   └── prepare_repos.sh      # 克隆外部仓库
├── config/trino/             # Trino catalog 模板
├── sql/                      # DDL / 校验 SQL
├── scripts/                  # 按 00-09 编号的测试步骤
│   ├── 00_data_generation/   # 数据生成
│   ├── 01_environment/       # 环境准备
│   ├── 02_import/            # 初始导入
│   ├── 03_backup/            # 备份恢复
│   ├── 04_cdc/               # CDC 接入
│   ├── 05_validate/          # 正确性校验
│   ├── 06_throughput/        # 吞吐新鲜度
│   ├── 07_ap_query/          # AP 查询性能
│   ├── 08_resource/          # 资源采集
│   └── 09_rollback/          # 回滚重复
├── flink_jobs/               # Flink SQL 提交脚本
├── docs/                     # 参考文档
├── results/                  # 实验结果（git-ignored）
└── logs/                     # 运行日志（git-ignored）
```

## 添加新格式

1. `scripts/01_environment/setup_<format>.sh` — 环境准备
2. `sql/<dataset>/ddl_<format>.sql` — 建表 DDL
3. `scripts/02_import/import_<format>_<dataset>_<scale>.sh` — 静态导入
4. `scripts/03_backup/backup_<format>_s3.sh` — 备份
5. `scripts/04_cdc/cdc_<format>_<dataset>_<scale>.sh` — CDC 接入
6. `scripts/07_ap_query/ap_<format>_static.sh` — AP 测试

## 安全说明

`env.sh` 不包含任何密钥。所有密码、IP、Access Key 都在 `env.local.sh` 中配置，
该文件已被 `.gitignore` 排除。
