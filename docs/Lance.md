# Lance 测试流程

## 架构

CSV → pylance Python API → Lance (S3)
                              ↑
Pixels-Sink (RPC) → pixels-lance parallel fetch → upsert/delete/insert

无 SQL DDL，所有操作通过 Python API。

参考：[pixels-lance/docs/](https://github.com/AntiO2/pixels-lance)

## 初始化

### 环境

```bash
pip install pylance
# 部署 Trino Lance connector → ${TRINO_HOME}/plugin/lance/
```

### CSV 导入

```bash
cd ${PIXELS_LANCE_REPO}
# 参见 docs/DATA_IMPORT.md — Python 批量写入
```

## CDC 接入

```bash
cd ${PIXELS_LANCE_REPO}
# 参见 docs/PARALLEL_FETCH.md
# 启动 Sink → parallel fetch → upsert/delete/insert
```

## 备份

```bash
aws s3 sync ${S3_LANCE}/<db>/ ${S3_LANCE}/<db>.bak/
```

## 恢复

```bash
aws s3 sync --delete ${S3_LANCE}/<db>.bak/ ${S3_LANCE}/<db>/
```

## AP 查询

```bash
cd ${PIXELS_BENCHMARK_REPO}
./pixels_bench -t runappower -c conf/lance.props -f conf/stmt_pixels.toml
```

## 资源监控

```bash
# 用 pidstat 监控 fetch 进程
pidstat -r -u -d 1 > lance_resource.log &
```

## 已知问题

- 无 SQL DDL，建表通过 Python API
- Trino 查询前需先注册表
- 建议先用 SF1333 数据集测试
