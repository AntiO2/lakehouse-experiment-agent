# Format-Specific Notes

## Iceberg

### Flume connector version
- Trino: 466 (Pixels connector compiled for 466)
- Flink: 1.20.0 + iceberg-flink-runtime 1.11.0

### Known Issues

1. **Glue StorageDescriptor NPE**: After Athena creates Iceberg tables, Glue
   only stores `metadata_location` without `StorageDescriptor.Columns`.
   Flink's IcebergStreamWriter reads `StorageDescriptor.columns()` during
   checkpoint and crashes with NPE. Fix: run `aws glue update-table` to add
   column definitions.

2. **S3 credentials**: Iceberg connector needs `fs.native-s3.enabled=true`
   in Trino catalog config. Uses EC2 IAM role, not `hive.s3.*` properties.

3. **Checkpoint frequency**: Default Flink checkpoint interval controls Iceberg
   commit frequency. 180s is typical for SF100.

### Schema mapping (Pixels → Iceberg)

| Pixels type | Iceberg type |
|-------------|-------------|
| `integer` | `int` |
| `real` | `double` |
| `char(n)` | `string` |
| `varchar(n)` | `string` |
| `timestamp(3)` | `timestamp` |

## Paimon

- Warehouse: filesystem metastore (not Hive)
- Flink `execution.runtime-mode=batch` for initial import
- Bucket config per table for primary key tables
- `deletion-vectors.enabled=true` for dv variant

## Lance

- Python client: pip install pylance
- Trino connector: deploy JAR to plugin/lance/
- No SQL DDL — create tables programmatically via pylance API
- CDC via pixels-lance parallel fetch → upsert/delete/insert

## Delta Lake

- Spark-based for both import and CDC merge
- Hive Metastore for table registration
- `_delta_log` is the version log, not snapshots like Iceberg
- Default `hard delete` semantics
