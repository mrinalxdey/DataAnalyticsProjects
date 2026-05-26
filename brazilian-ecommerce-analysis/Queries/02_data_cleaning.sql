-- Creating staging tables for data cleaning
create table staging.customers as select * from raw.customers where 1=0;
create table staging.orders as select * from raw.orders where 1=0;
create table staging.order_items as select * from raw.order_items where 1=0;
create table staging.payments as select * from raw.payments where 1=0;
create table staging.reviews as select * from raw.reviews where 1=0;
create table staging.geolocation as select * from raw.geolocation where 1=0;
create table staging.products as select * from raw.products where 1=0;
create table staging.sellers as select * from raw.sellers where 1=0;
create table staging.product_category_name_translation as select * from raw.product_category_name_translation where 1=0;

-- Clean and insert into their respective tables
-- Confirm the data types of columns
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'raw'
AND table_name = 'customers';

-- orders -----------------------------------------------------------
INSERT INTO staging.orders
SELECT
    TRIM(order_id),
    TRIM(customer_id),
    LOWER(TRIM(order_status)),
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
FROM raw.orders;

-- clean orders
UPDATE staging.orders
SET order_status = LOWER(order_status);

UPDATE staging.orders
SET order_approved_at = NULL
WHERE order_approved_at = '';

-- check for duplicates
SELECT order_id, COUNT(*)
FROM staging.orders
GROUP BY order_id
HAVING COUNT(*) > 1; -- no duplicates

-- orders without customers
SELECT o.*
FROM staging.orders o
LEFT JOIN staging.customers c
ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL; -- no orphan orders

-- delivered before purchased errors?
SELECT *
FROM staging.orders
WHERE order_delivered_customer_date < order_purchase_timestamp; -- no errors

-- approved before purchase
SELECT *
FROM staging.orders
WHERE order_approved_at < order_purchase_timestamp; -- no errors

-- customers ------------------------------------------------------
INSERT INTO staging.customers
SELECT
	TRIM(customer_id),
	TRIM(customer_unique_id),
	customer_zip_code_prefix,
	TRIM(customer_city),
	TRIM(customer_state)
FROM raw.customers;

-- check duplicates
SELECT customer_id, COUNT(*)
FROM staging.customers
GROUP BY customer_id
HAVING COUNT(*) > 1; -- no duplicates

-- Write a SQL script to detect and remove duplicate customers while keeping the most recent record
select 
	customer_unique_id,
	count(*) as duplicates
from staging.customers
group by customer_unique_id
having count(*) > 1;

with ranked_customer_unique_id as (
	select 
		ctid,
		customer_id,
		customer_unique_id,
		row_number() over (partition by customer_unique_id order by customer_id desc) as rn
	from staging.customers
)
delete from staging.customers cid
using ranked_customer_unique_id rcid
where cid.ctid = rcid.ctid
and rcid.rn > 1; -- removed 3345 duplicate rows

-- difference 
select 
	count(*) as original_count,
	(select count(*) from staging.customers) as new_count 
from raw.customers;

-- products ---------------------------------------------------------
INSERT INTO staging.products
SELECT 
	TRIM(product_id),
    NULLIF(TRIM(product_category_name), ''),
    product_name_length,
    product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
FROM raw.products;

-- check duplicates
SELECT product_id, COUNT(*)
FROM staging.products
GROUP BY product_id
HAVING COUNT(*) > 1; -- no duplicates

-- negative product dimensions
SELECT *
FROM staging.products
WHERE product_weight_g < 0
   OR product_length_cm < 0
   OR product_height_cm < 0
   OR product_width_cm < 0; -- no invalid dimensions

-- weightless products
SELECT *
FROM staging.products
WHERE product_weight_g = 0; -- 4 found

-- converting them to null so they don't affect aggregates
UPDATE staging.products
set product_weight_g = NULL
where product_weight_g = 0;

-- find outliers or unusually large products
SELECT *
FROM staging.products
WHERE product_weight_g > 50000;

SELECT *
FROM staging.products
WHERE product_length_cm > 300
   OR product_height_cm > 300
   OR product_width_cm > 300;  -- no outliers

-- product_category_name_translation ------------------------------------------
INSERT INTO staging.product_category_name_translation
SELECT 
	trim(product_category_name),
	trim(product_category_name_english)
from raw.product_category_name_translation;

-- check which values in product_category_name are missing from parent table
SELECT DISTINCT product_category_name
FROM staging.products
WHERE product_category_name NOT IN (
    SELECT product_category_name
    FROM staging.product_category_name_translation
); -- 2 missing

-- add the missing values (no translations since we might have a lot of values leading to manual entries)
INSERT INTO staging.product_category_name_translation (product_category_name, product_category_name_english)
SELECT DISTINCT
	p.product_category_name,
	p.product_category_name
FROM staging.products as p
where p.product_category_name IS NOT NULL
and p.product_category_name NOT IN (
	SELECT product_category_name
    FROM staging.product_category_name_translation
); -- new total is 73 records excluding null

-- reviews ------------------------------------------------------------------
INSERT INTO staging.reviews
select 
	trim(review_id),
	trim(order_id),
	review_score,
	nullif(trim(review_comment_title), ''),
    nullif(trim(review_comment_message), ''),
	review_creation_date,
	review_answer_timestamp
from raw.reviews;

-- check invalid review_score
SELECT *
FROM staging.reviews
WHERE review_score NOT BETWEEN 1 AND 5; -- no invalid scores

-- check duplicates
SELECT review_id, COUNT(*)
FROM staging.reviews
GROUP BY review_id
HAVING COUNT(*) > 1; -- identical duplicates

SELECT order_id, COUNT(*)
FROM staging.reviews
GROUP BY order_id
HAVING COUNT(*) > 1; -- unique

-- remove identical duplicates
DELETE FROM staging.reviews a
USING staging.reviews b
WHERE a.ctid < b.ctid
AND a.review_id = b.review_id; -- deleted 814 duplicates

-- reviews without matching orders (orphaned records)
SELECT r.*
FROM staging.reviews r
left JOIN staging.orders o
ON r.order_id = o.order_id
WHERE o.order_id IS NULL; -- no orphans

-- check orphan reviews
SELECT r.*
FROM staging.reviews r
LEFT JOIN staging.orders o
ON r.order_id = o.order_id
WHERE o.order_id IS NULL; -- no orphans

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'staging'
AND table_name = 'reviews';

-- order_items -------------------------------------------------------------
INSERT INTO staging.order_items
select
	trim(order_id),
	order_item_id,
	trim(product_id),
	trim(seller_id),
	shipping_limit_date,
	price,
	freight_value
from raw.order_items;

-- check duplicates
select
	order_id, order_item_id, count(*)
from staging.order_items
group by order_id, order_item_id
having count(*) > 1; -- no duplicates

-- check for negative values or zero
SELECT freight_value, price
FROM staging.order_items
WHERE freight_value <= 0 or price <= 0
order by price; -- no negatives

-- check orphan order
select oi.*, o.order_id
from staging.order_items oi
left join staging.orders o
on oi.order_id = o.order_id
where o.order_id is null; -- no orphans

-- payments ----------------------------------------------------------------
INSERT INTO staging.payments
select 
	trim(order_id),
	payment_sequential,
	lower(trim(payment_type)),
	payment_installments,
	payment_value
from raw.payments;

-- check duplicates
select
	order_id, payment_sequential, count(*)
from staging.payments
group by order_id, payment_sequential
having count(*) > 1; -- no duplicates

-- check invalid values and convert them to nulls
select *
from staging.payments
where payment_installments is null; -- 2 records found

update staging.payments
set payment_installments = NULL
where payment_installments = 0;

-- sellers -----------------------------------------------------------------
INSERT INTO staging.sellers
select
	trim(seller_id),
	seller_zip_code_prefix,
	lower(trim(seller_city)),
	seller_state
from raw.sellers;

-- check duplicates
select seller_id, count(*)
from staging.sellers
group by seller_id
having count(*) > 1; -- no duplicates

-- check nulls/zeros
select *
from staging.sellers
where seller_zip_code_prefix is null 
or seller_zip_code_prefix = 0
or seller_city is null
or seller_state is null;

-- check orphans
select oi.*
from staging.order_items oi
left join staging.sellers s
on oi.seller_id = s.seller_id
where s.seller_id is null; -- no orphans

-- check same seller_id at multiple locations
SELECT
    seller_id,
    COUNT(DISTINCT seller_city),
    COUNT(DISTINCT seller_state)
FROM staging.sellers
GROUP BY seller_id
HAVING COUNT(DISTINCT seller_city) > 1
    OR COUNT(DISTINCT seller_state) > 1; -- 0 records

-- reformatting zip codes from 4 digit to 5 digit
ALTER TABLE staging.sellers
ALTER COLUMN seller_zip_code_prefix TYPE TEXT
USING LPAD(seller_zip_code_prefix::text, 5, '0');

-- geolocation -------------------------------------------------------------
alter table staging.geolocation
alter column geolocation_zip_code_prefix type text;

insert into staging.geolocation 
select
	LPAD(geolocation_zip_code_prefix::text, 5, '0'),
	geolocation_lat,
	geolocation_lng,
	trim(geolocation_city),
	trim(geolocation_state)
from raw.geolocation;

-- check nulls
SELECT
    COUNT(*) FILTER (WHERE geolocation_zip_code_prefix IS NULL) AS missing_zip,
    COUNT(*) FILTER (WHERE geolocation_lat IS NULL) AS missing_lat,
    COUNT(*) FILTER (WHERE geolocation_lng IS NULL) AS missing_lng,
    COUNT(*) FILTER (WHERE geolocation_city IS NULL) AS missing_city,
    COUNT(*) FILTER (WHERE geolocation_state IS NULL) AS missing_state
FROM staging.geolocation; -- no nulls

-- numeric city or number in name
SELECT DISTINCT geolocation_city
FROM staging.geolocation
WHERE geolocation_city ~ '\d'; -- exists

-- remove duplicates in geolocation as it is needed to join
select geolocation_zip_code_prefix, count(*)
from staging.geolocation
group by geolocation_zip_code_prefix
having count(*) > 1
order by geolocation_zip_code_prefix; 

-- keep 1 zipcode by aggregating the latitude and longitude
create table staging.clean_geolocation as
select *
from (
	SELECT
    geolocation_zip_code_prefix,
    AVG(geolocation_lat) AS latitude,
    AVG(geolocation_lng) AS longitude,
    MAX(geolocation_city) AS city,
    MAX(geolocation_state) AS state
	FROM staging.geolocation
	GROUP BY geolocation_zip_code_prefix
) as staging_geo;

-- remove the accents in city name
CREATE EXTENSION IF NOT EXISTS unaccent;

SELECT DISTINCT city
FROM staging.clean_geolocation
WHERE city ~ '[^\x00-\x7F]'; -- 2025 records

UPDATE staging.clean_geolocation
SET city =
    LOWER(
        UNACCENT(
            TRIM(city)
        )
    );

-- create tables in analytics schema
create table analytics.customers as select * from staging.customers where 1=0;
create table analytics.orders as select * from staging.orders where 1=0;
create table analytics.order_items as select * from staging.order_items where 1=0;
create table analytics.payments as select * from staging.payments where 1=0;
create table analytics.reviews as select * from staging.reviews where 1=0;
create table analytics.geolocation as select * from staging.clean_geolocation where 1=0;
create table analytics.products as select * from staging.products where 1=0;
create table analytics.sellers as select * from staging.sellers where 1=0;
create table analytics.product_category_name_translation as select * from staging.product_category_name_translation where 1=0;

