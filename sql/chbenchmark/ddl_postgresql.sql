-- ============================================================
-- CHBenchmark PostgreSQL DDL
-- Source: https://github.com/AntiO2/CH-benchmark/blob/master/action/01_create_tables.sql
-- 12 tables (TPC-C schema): warehouse, district, customer, history,
--   neworder, "order", orderline, item, stock, nation, supplier, region
-- ============================================================

DROP SCHEMA IF EXISTS tpcch CASCADE;
CREATE SCHEMA tpcch;
SET search_path TO tpcch;

-- 1. Warehouse
CREATE TABLE warehouse (
    w_id integer PRIMARY KEY, w_name char(10), w_street_1 char(20),
    w_street_2 char(20), w_city char(20), w_state char(2), w_zip char(9),
    w_tax decimal(4,4), w_ytd decimal(12,2), freshness_ts timestamp
);

-- 2. District
CREATE TABLE district (
    d_id smallint, d_w_id integer, d_name char(10), d_street_1 char(20),
    d_street_2 char(20), d_city char(20), d_state char(2), d_zip char(9),
    d_tax decimal(4,4), d_ytd decimal(12,2), d_next_o_id integer,
    freshness_ts timestamp, PRIMARY KEY (d_w_id, d_id)
);

-- 3. Customer
CREATE TABLE customer (
    c_id smallint, c_d_id smallint, c_w_id integer, c_first char(16),
    c_middle char(2), c_last char(16), c_street_1 char(20), c_street_2 char(20),
    c_city char(20), c_state char(2), c_zip char(9), c_phone char(16),
    c_since DATE, c_credit char(2), c_credit_lim decimal(12,2),
    c_discount decimal(4,4), c_balance decimal(12,2),
    c_ytd_payment decimal(12,2), c_payment_cnt smallint,
    c_delivery_cnt smallint, c_data text, c_n_nationkey integer,
    freshness_ts timestamp, PRIMARY KEY(c_w_id, c_d_id, c_id)
);

-- 4. History
CREATE TABLE history (
    h_c_id smallint, h_c_d_id smallint, h_c_w_id integer, h_d_id smallint,
    h_w_id integer, h_date date, h_amount decimal(6,2), h_data text,
    freshness_ts timestamp
);

-- 5. NewOrder
CREATE TABLE neworder (
    no_o_id integer, no_d_id smallint, no_w_id integer, freshness_ts timestamp,
    PRIMARY KEY (no_w_id, no_d_id, no_o_id)
);

-- 6. Order
CREATE TABLE "order" (
    o_id integer, o_d_id smallint, o_w_id integer, o_c_id smallint,
    o_entry_d date, o_carrier_id smallint, o_ol_cnt smallint,
    o_all_local smallint, freshness_ts timestamp,
    PRIMARY KEY (o_w_id, o_d_id, o_id)
);

-- 7. Orderline
CREATE TABLE orderline (
    ol_o_id integer, ol_d_id smallint, ol_w_id integer, ol_number smallint,
    ol_i_id integer, ol_supply_w_id integer, ol_delivery_d date,
    ol_quantity smallint, ol_amount decimal(6,2), ol_dist_info varchar(32),
    freshness_ts timestamp, PRIMARY KEY (ol_w_id, ol_d_id, ol_o_id, ol_number)
);

-- 8. Item
CREATE TABLE item (
    i_id integer PRIMARY KEY, i_im_id smallint, i_name varchar(32),
    i_price decimal(5,2), i_data char(50), freshness_ts timestamp
);

-- 9. Stock
CREATE TABLE stock (
    s_i_id integer, s_w_id integer, s_quantity integer, s_dist_01 varchar(32),
    s_dist_02 varchar(32), s_dist_03 varchar(32), s_dist_04 varchar(32),
    s_dist_05 varchar(32), s_dist_06 varchar(32), s_dist_07 varchar(32),
    s_dist_08 varchar(32), s_dist_09 varchar(32), s_dist_10 varchar(32),
    s_ytd integer, s_order_cnt integer, s_remote_cnt integer, s_data char(50),
    s_su_suppkey integer, freshness_ts timestamp, PRIMARY KEY (s_w_id, s_i_id)
);

-- 10. Nation
CREATE TABLE nation (
    n_nationkey smallint PRIMARY KEY, n_name char(25), n_regionkey smallint,
    n_comment char(152), freshness_ts timestamp
);

-- 11. Supplier
CREATE TABLE supplier (
    su_suppkey smallint PRIMARY KEY, su_name char(25), su_address char(40),
    su_nationkey smallint, su_phone char(15), su_acctbal decimal(12,2),
    su_comment char(101), freshness_ts timestamp
);

-- 12. Region
CREATE TABLE region (
    r_regionkey smallint PRIMARY KEY, r_name char(55), r_comment char(152),
    freshness_ts timestamp
);
