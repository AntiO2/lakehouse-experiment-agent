-- ============================================================
-- CHBenchmark Pixels-Retina DDL (S3 storage, RocksDB PK)
-- Source: https://github.com/AntiO2/pixels-benchmark/tree/master/conf/chbenchmark
-- Variables: ${S3_PIXELS}, ${DB_CHBENCH}
-- 12 tables: warehouse, district, customer, history, neworder,
--            "order", orderline, item, stock, nation, supplier, region
-- ============================================================

CREATE TABLE IF NOT EXISTS warehouse (
    w_id integer, w_name char(10), w_street_1 char(20), w_street_2 char(20),
    w_city char(20), w_state char(2), w_zip char(9), w_tax real, w_ytd real,
    freshness_ts timestamp
) WITH (
    storage='s3',
    paths='${S3_PIXELS}/tpcch/warehouse/',
    pk='w_id',
    pk_scheme='rocksdb'
);

CREATE TABLE IF NOT EXISTS district (
    d_id integer, d_w_id integer, d_name char(10), d_street_1 char(20),
    d_street_2 char(20), d_city char(20), d_state char(2), d_zip char(9),
    d_tax real, d_ytd real, d_next_o_id integer, freshness_ts timestamp
) WITH (
    storage='s3',
    paths='${S3_PIXELS}/tpcch/district/',
    pk='d_w_id,d_id',
    pk_scheme='rocksdb'
);

CREATE TABLE IF NOT EXISTS customer (
    c_id integer, c_d_id integer, c_w_id integer, c_first char(16), c_middle char(2),
    c_last char(16), c_street_1 char(20), c_street_2 char(20), c_city char(20),
    c_state char(2), c_zip char(9), c_phone char(16), c_since date, c_credit char(2),
    c_credit_lim real, c_discount real, c_balance real, c_ytd_payment real,
    c_payment_cnt integer, c_delivery_cnt integer, c_data char(500),
    c_n_nationkey integer, freshness_ts timestamp
) WITH (
    storage='s3',
    paths='${S3_PIXELS}/tpcch/customer/',
    pk='c_w_id,c_d_id,c_id',
    pk_scheme='rocksdb'
);

CREATE TABLE IF NOT EXISTS history (
    h_c_id integer, h_c_d_id integer, h_c_w_id integer, h_d_id integer, h_w_id integer,
    h_date timestamp, h_amount real, h_data char(500), freshness_ts timestamp
) WITH (
    storage='s3',
    paths='${S3_PIXELS}/tpcch/history/',
    pk='h_c_id,h_c_d_id,h_c_w_id,h_d_id,h_w_id,h_date',
    pk_scheme='rocksdb'
);

CREATE TABLE IF NOT EXISTS neworder (
    no_o_id integer, no_d_id integer, no_w_id integer, freshness_ts timestamp
) WITH (
    storage='s3',
    paths='${S3_PIXELS}/tpcch/neworder/',
    pk='no_w_id,no_d_id,no_o_id',
    pk_scheme='rocksdb'
);

CREATE TABLE IF NOT EXISTS "order" (
    o_id integer, o_d_id integer, o_w_id integer, o_c_id integer,
    o_entry_d date, o_carrier_id integer, o_ol_cnt integer, o_all_local integer,
    freshness_ts timestamp
) WITH (
    storage='s3',
    paths='${S3_PIXELS}/tpcch/order/',
    pk='o_w_id,o_d_id,o_id',
    pk_scheme='rocksdb'
);

CREATE TABLE IF NOT EXISTS orderline (
    ol_o_id integer, ol_d_id integer, ol_w_id integer, ol_number integer,
    ol_i_id integer, ol_supply_w_id integer, ol_delivery_d date, ol_quantity integer,
    ol_amount real, ol_dist_info char(32), freshness_ts timestamp
) WITH (
    storage='s3',
    paths='${S3_PIXELS}/tpcch/orderline/',
    pk='ol_w_id,ol_d_id,ol_o_id,ol_number',
    pk_scheme='rocksdb'
);

CREATE TABLE IF NOT EXISTS item (
    i_id integer, i_im_id integer, i_name char(32), i_price real, i_data char(50),
    freshness_ts timestamp
) WITH (
    storage='s3',
    paths='${S3_PIXELS}/tpcch/item/',
    pk='i_id',
    pk_scheme='rocksdb'
);

CREATE TABLE IF NOT EXISTS stock (
    s_i_id integer, s_w_id integer, s_quantity integer,
    s_dist_01 char(32), s_dist_02 char(32), s_dist_03 char(32), s_dist_04 char(32),
    s_dist_05 char(32), s_dist_06 char(32), s_dist_07 char(32), s_dist_08 char(32),
    s_dist_09 char(32), s_dist_10 char(32), s_ytd integer, s_order_cnt integer,
    s_remote_cnt integer, s_data char(50), s_su_suppkey integer, freshness_ts timestamp
) WITH (
    storage='s3',
    paths='${S3_PIXELS}/tpcch/stock/',
    pk='s_w_id,s_i_id',
    pk_scheme='rocksdb'
);

CREATE TABLE IF NOT EXISTS nation (
    n_nationkey integer, n_name char(25), n_regionkey integer, n_comment char(152),
    freshness_ts timestamp
) WITH (
    storage='s3',
    paths='${S3_PIXELS}/tpcch/nation/',
    pk='n_nationkey',
    pk_scheme='rocksdb'
);

CREATE TABLE IF NOT EXISTS supplier (
    su_suppkey integer, su_name char(25), su_address char(40), su_nationkey integer,
    su_phone char(15), su_acctbal real, su_comment char(101), freshness_ts timestamp
) WITH (
    storage='s3',
    paths='${S3_PIXELS}/tpcch/supplier/',
    pk='su_suppkey',
    pk_scheme='rocksdb'
);

CREATE TABLE IF NOT EXISTS region (
    r_regionkey integer, r_name char(55), r_comment char(152), freshness_ts timestamp
) WITH (
    storage='s3',
    paths='${S3_PIXELS}/tpcch/region/',
    pk='r_regionkey',
    pk_scheme='rocksdb'
);
