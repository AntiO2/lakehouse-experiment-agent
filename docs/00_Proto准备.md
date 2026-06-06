# Proto 准备

Proto 文件用于 Pixels-Sink 连接 Pixels Source 时做序列化/反序列化。

## 生成原理

Pixels-Sink 的 Embedded Debezium Engine 以 `writer=proto` 模式从 PostgreSQL CDC 读取变更数据，
自动生成 `.proto` 文件并注册到 ETCD。

## 日常使用：复用已有 Proto 文件

生成过程复杂，通常使用**预存好的 proto 文件**，只需下载并注册到 ETCD。

### 1. 获取 Proto 文件

从备份机器 rsync：

```bash
rsync -avz <source-host>:/home/ubuntu/disk1/hybench100_proto/ /home/ubuntu/disk1/hybench100_proto/
rsync -avz <source-host>:/home/ubuntu/disk1/data/hybench1000_proto/ /home/ubuntu/disk1/data/hybench1000_proto/
```

### 2. 注册到 ETCD

HyBench SF100：

```bash
ETCDCTL_API=3 etcdctl put /sink/proto/registry/hybench100/files/00000.proto \
  '{"path":"file:///home/ubuntu/disk1/hybench100_proto/00000.proto","created_at":"1766592275366","status":"completed"}'

ETCDCTL_API=3 etcdctl put /sink/proto/registry/hybench100/files/00001.proto \
  '{"path":"file:///home/ubuntu/disk1/hybench100_proto/00001.proto","created_at":"1766592275366","status":"completed"}'
```

HyBench SF1000：

```bash
ETCDCTL_API=3 etcdctl put /sink/proto/registry/hybench1000/current "00000.proto"

ETCDCTL_API=3 etcdctl put /sink/proto/registry/hybench1000/files/00000.proto \
  '{"path":"file:///home/ubuntu/disk1/data/hybench1000_proto/00000.proto","created_at":"1766592275366","status":"active"}'
```

### 3. Sink 配置

对应 `pixels-sink` 配置文件中的：

```properties
sink.proto.data=hybench100
```

## 验证

启动 Sink 后检查日志，确认 proto 文件加载成功。Sink 的 metrics log 应显示非零吞吐。

## 注意

- Proto 文件**不放在本 Agent 仓库中**（二进制大文件），由外部备份管理
- 不同 Benchmark 使用不同的 proto registry key（如 `hybench100`、`hybench1000`）
