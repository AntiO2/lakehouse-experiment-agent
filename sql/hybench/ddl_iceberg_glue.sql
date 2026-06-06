-- ============================================================
-- Iceberg table DDL for HyBench (Glue catalog, S3 warehouse)
-- Run via: Athena or Trino
-- Variables to replace before execution:
--   ${DB_HYBENCH_SF100}, ${S3_ICEBERG}
-- ============================================================
CREATE DATABASE IF NOT EXISTS ${DB_HYBENCH_SF100};

CREATE TABLE ${DB_HYBENCH_SF100}.customer (
    custid INT, companyid INT, gender STRING, name STRING,
    age INT, phone STRING, province STRING, city STRING,
    loan_balance DECIMAL(15,2), saving_credit INT, checking_credit INT,
    loan_credit INT, Isblocked INT, created_date DATE,
    last_update_timestamp TIMESTAMP, freshness_ts TIMESTAMP
) WITH (
    format = 'PARQUET',
    location = '${S3_ICEBERG}/${DB_HYBENCH_SF100}.db/customer'
);

CREATE TABLE ${DB_HYBENCH_SF100}.company (
    companyid INT, name STRING, category STRING, staff_size INT,
    loan_balance DECIMAL(15,2), phone STRING, province STRING, city STRING,
    saving_credit INT, checking_credit INT, loan_credit INT, Isblocked INT,
    created_date DATE, last_update_timestamp TIMESTAMP, freshness_ts TIMESTAMP
) WITH (
    format = 'PARQUET',
    location = '${S3_ICEBERG}/${DB_HYBENCH_SF100}.db/company'
);

CREATE TABLE ${DB_HYBENCH_SF100}.savingaccount (
    accountid INT, userid INT, balance DECIMAL(15,2), Isblocked INT,
    ts TIMESTAMP, freshness_ts TIMESTAMP
) WITH (
    format = 'PARQUET',
    location = '${S3_ICEBERG}/${DB_HYBENCH_SF100}.db/savingaccount'
);

CREATE TABLE ${DB_HYBENCH_SF100}.checkingaccount (
    accountid INT, userid INT, balance DECIMAL(15,2), Isblocked INT,
    ts TIMESTAMP, freshness_ts TIMESTAMP
) WITH (
    format = 'PARQUET',
    location = '${S3_ICEBERG}/${DB_HYBENCH_SF100}.db/checkingaccount'
);

CREATE TABLE ${DB_HYBENCH_SF100}.transfer (
    id BIGINT, sourceid INT, targetid INT, amount DECIMAL(15,2),
    type STRING, ts TIMESTAMP, freshness_ts TIMESTAMP
) WITH (
    format = 'PARQUET',
    location = '${S3_ICEBERG}/${DB_HYBENCH_SF100}.db/transfer'
);

CREATE TABLE ${DB_HYBENCH_SF100}.checking (
    id INT, sourceid INT, targetid INT, amount DECIMAL(15,2),
    type STRING, ts TIMESTAMP, freshness_ts TIMESTAMP
) WITH (
    format = 'PARQUET',
    location = '${S3_ICEBERG}/${DB_HYBENCH_SF100}.db/checking'
);

CREATE TABLE ${DB_HYBENCH_SF100}.loanapps (
    id INT, applicantid INT, amount DECIMAL(15,2), duration INT,
    status STRING, ts TIMESTAMP, freshness_ts TIMESTAMP
) WITH (
    format = 'PARQUET',
    location = '${S3_ICEBERG}/${DB_HYBENCH_SF100}.db/loanapps'
);

CREATE TABLE ${DB_HYBENCH_SF100}.loantrans (
    id INT, applicantid INT, appid INT, amount DECIMAL(15,2),
    status STRING, ts TIMESTAMP, duration INT,
    contract_timestamp TIMESTAMP, delinquency INT, freshness_ts TIMESTAMP
) WITH (
    format = 'PARQUET',
    location = '${S3_ICEBERG}/${DB_HYBENCH_SF100}.db/loantrans'
);
