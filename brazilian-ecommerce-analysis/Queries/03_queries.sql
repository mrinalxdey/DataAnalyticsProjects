set search_path to 'analytics';

-- inserting cleaned data using transactions

BEGIN;

-- insert into analytics.customers 
-- select 
-- 	customer_id,
--     customer_unique_id,
--     customer_zip_code_prefix,
--     customer_city,
--     customer_state
-- from staging.customers;

COMMIT;

-- intentional error
BEGIN;

INSERT INTO analytics.customers(invalid_column)
VALUES ('test');

ROLLBACK;

-- orphan records: order_items that reference non-existent products or orders
SELECT
    oi.order_id,
    oi.product_id,
    CASE
        WHEN o.order_id IS NULL THEN 'Missing Order'
        WHEN p.product_id IS NULL THEN 'Missing Product'
    END AS orphan_type
FROM analytics.order_items oi
LEFT JOIN analytics.orders o
    ON oi.order_id = o.order_id
LEFT JOIN analytics.products p
    ON oi.product_id = p.product_id
WHERE o.order_id IS NULL
   OR p.product_id IS NULL; -- no orphans

-- customers who registered but never placed an order (conversion funnel leak analysis)
select
	c.customer_id,
	c.customer_unique_id, 
	customer_city,
	customer_state
from analytics.customers c
left join analytics.orders o
on c.customer_id = o.customer_id
where o.order_id is null;

-- potential fraud detection: orders where payment_value != order total
with order_total as	(
	select
		order_id,
		sum(price + freight_value) as total_bill
	from analytics.order_items
	group by order_id
),
payment_total as (
	select
		order_id,
		sum(payment_value) as total_paid
	from analytics.payments
	group by order_id
)
select 
	ot.*,
	pt.total_paid
from order_total ot
join payment_total pt
on ot.order_id = pt.order_id
where ot.total_bill <> pt.total_paid and abs(ot.total_bill - pt.total_paid) > 1
order by abs(ot.total_bill - pt.total_paid) desc;

-- monthly revenue with Month-over-Month (MoM) growth percentage
with monthly_revenue as (
	select 
		date_trunc('month', o.order_purchase_timestamp) as month,
		sum(p.payment_value) as revenue
	from analytics.orders o
	join analytics.payments p
	on o.order_id = p.order_id
	where order_status = 'delivered'
	group by 1
	order by 1
),
revenue_growth as (
	select
		month,
		revenue,
		lag(revenue) over (order by month) as prev_month_rev
	from monthly_revenue
)
select 
	*,
	round(((revenue-prev_month_rev)/prev_month_rev)*100,2) as mom_growth
from revenue_growth;

-- top 10 products by revenue in each category 
with product_revenue as (	
	select 
		p.product_id, 
		pcnt.product_category_name_english,
		sum(oi.price) as revenue
	from analytics.products p
	join analytics.order_items oi
	on p.product_id = oi.product_id
	join product_category_name_translation pcnt
	on p.product_category_name = pcnt.product_category_name
	group by p.product_id, pcnt.product_category_name_english
),
ranked_product as (
	select 
		*,
		rank() over (partition by product_category_name_english order by revenue desc) as ranked,
		dense_rank() over (partition by product_category_name_english order by revenue desc) as dense_ranked
	from product_revenue
)
select * from ranked_product
where dense_ranked <= 10;

-- Customer Lifetime Value (CLV) = SUM(payment_value) per customer, categorized as Bronze/Silver/Gold
with clv as (
select
	c.customer_id,
	sum(p.payment_value) as CLV
from analytics.customers c
join analytics.orders o
on c.customer_id = o.customer_id
join analytics.payments p
on p.order_id = o.order_id
where o.order_status = 'delivered'
group by c.customer_id
),
ntiles as (
select
	customer_id,
	clv,
	ntile(3) over (order by clv desc) clv_segment
from clv
)
select
	customer_id,
	clv,
	case
		when clv_segment = 1 then 'Gold'
		when clv_segment = 2 then 'Silver'
		when clv_segment = 3 then 'Bronze'
	end as customer_tier
from ntiles;

-- a sales report with daily, weekly, monthly subtotals using ROLLUP
select
	date_trunc('month', o.order_purchase_timestamp) as monthly,
	date_trunc('week', o.order_purchase_timestamp) as weekly,
	date_trunc('day', o.order_purchase_timestamp) as daily,
	sum(p.payment_value) as revenue
from analytics.orders o
join analytics.payments p
on o.order_id = p.order_id
where o.order_status = 'delivered'
group by rollup(
	date_trunc('month', o.order_purchase_timestamp),
	date_trunc('week', o.order_purchase_timestamp),
	date_trunc('day', o.order_purchase_timestamp)
)
order by monthly, weekly, daily;

-- seasonal patterns: which product categories sell best in which months?
with revenue_by_category as (
select 
	date_trunc('month', o.order_purchase_timestamp) as month,
	pcnt.product_category_name_english,
	sum(oi.price) as revenue
from analytics.orders o
join analytics.order_items oi
on o.order_id = oi.order_id
join analytics.products p
on p.product_id = oi.product_id
join analytics.product_category_name_translation pcnt
on pcnt.product_category_name = p.product_category_name
where o.order_status = 'delivered'
group by 1, 2
),
ranking as (
	select 
		*,
		dense_rank() over (partition by month order by revenue desc) as ranking
	from revenue_by_category 
)
select * from ranking 
where ranking <= 3
order by month, ranking;

-- a complete customer 360-degree view joining 5+ tables
select
	c.customer_id,
	c.customer_zip_code_prefix,
	c.customer_city,
	c.customer_state,
	count(distinct o.order_id) as total_orders,
	count(oi.product_id) as products_purchased,
	sum(oi.price+oi.freight_value) as total_spending,
	avg(oi.price) as avg_order_value,
	round(avg(r.review_score),2) as avg_review,
	min(o.order_purchase_timestamp) as first_purchase_date,
	max(o.order_purchase_timestamp) as last_purchase_date
from analytics.customers c
join analytics.orders o on c.customer_id = o.customer_id
join analytics.order_items oi on o.order_id = oi.order_id
join analytics.products p on p.product_id = oi.product_id
join analytics.reviews r on r.order_id = o.order_id
join analytics.product_category_name_translation pcnt
	on pcnt.product_category_name = p.product_category_name
group by 1,2,3,4;

-- customers who bought products from category 'electronics' but never from 'books'
with electronic_customers as (
	select
		distinct c.customer_id
	from analytics.order_items oi
	join analytics.orders o on oi.order_id = o.order_id
	join analytics.customers c on c.customer_id = o.customer_id
	join analytics.products p on oi.product_id = p.product_id
	where p.product_category_name in ('eletronicos')
	and o.order_status = 'delivered'
),
book_customers as (
	select
		distinct c.customer_id
	from analytics.order_items oi
	join analytics.orders o on oi.order_id = o.order_id
	join analytics.customers c on c.customer_id = o.customer_id
	join analytics.products p on oi.product_id = p.product_id
	where p.product_category_name in ('livros_tecnicos', 'livros_interesse_geral', 'livros_importados')
	and o.order_status = 'delivered'
)
select * from electronic_customers 
except
select * from book_customers

-- sellers and their best-selling product in each category they sell
with best_seller_product as (
select 
	oi.seller_id,
	oi.product_id,
	p.product_category_name,
	sum(oi.price) as revenue,
	row_number() over (partition by oi.seller_id, p.product_category_name order by sum(oi.price) desc) as top_product
from analytics.order_items oi
join analytics.products p
on oi.product_id = p.product_id
where product_category_name is not null
group by 1,2,3
)
select *
from best_seller_product
where top_product = 1
order by seller_id, revenue desc;

-- products frequently bought together
select
	oi1.product_id as product_1,
	oi2.product_id as product_2,
	count(*) as bought_together_count
from analytics.order_items oi1
join analytics.order_items oi2
	on oi1.order_id = oi2.order_id
	and oi1.product_id < oi2.product_id
group by
	oi1.product_id,
	oi2.product_id
order by bought_together_count desc;

-- orders with shipping delays: expected_delivery_date < actual_delivery_date, show customer and seller info
select
	o.order_id,
	s.seller_id,
	c.customer_id,
	s.seller_zip_code_prefix,
	c.customer_zip_code_prefix,
	s.seller_city,
	c.customer_city,
	s.seller_state,
	c.customer_state,
	o.order_estimated_delivery_date,
	o.order_delivered_customer_date,
	o.order_delivered_customer_date - o.order_estimated_delivery_date as delay
from analytics.order_items oi
join analytics.sellers s on oi.seller_id = s.seller_id
join analytics.orders o on o.order_id = oi.order_id
join analytics.customers c on o.customer_id = c.customer_id
where o.order_delivered_customer_date - o.order_estimated_delivery_date > interval '24 hours';
	
-- Find customers who spent more than the average customer in their state
with customer_spending as (
	select
		c.customer_id,
		c.customer_state,
		sum(p.payment_value) as total_spent
	from analytics.customers c
	join analytics.orders o on c.customer_id = o.customer_id
	join analytics.payments p on o.order_id = p.order_id
	where o.order_status = 'delivered'
	group by c.customer_id, c.customer_state
)
select 
	customer_id,
	customer_state,
	total_spent,
	round(state_avg, 2)
from (
	select
		customer_id,
		customer_state,
		total_spent,
		avg(total_spent) over (partition by customer_state) as state_avg
	from customer_spending
) t
where total_spent > state_avg;

-- 2nd highest revenue-generating product in each category
select * from (
	select 
		p.product_id,
		pcnt.product_category_name_english,
		sum(oi.price) as revenue,
		dense_rank() over (partition by pcnt.product_category_name_english order by sum(oi.price) desc) as ranked
	from analytics.products p
	join analytics.order_items oi
	on oi.product_id = p.product_id
	join analytics.product_category_name_translation pcnt
	on pcnt.product_category_name = p.product_category_name
	group by p.product_id, pcnt.product_category_name_english
)
where ranked = 2 and product_category_name_english is not null

-- customers who made purchases in 3+ consecutive months using CTE with window functions
with customer_months as (
	select
		customer_id,
		date_trunc('month', order_purchase_timestamp) as purchase_month
	from analytics.orders
	where order_status = 'delivered'
),
numbered_months as (
	select
		customer_id,
		purchase_month,
		row_number() over (partition by customer_id order by purchase_month) as rn
	from customer_months
),
grouped_months as (
	select
		customer_id,
		purchase_month,
		purchase_month - (rn * interval '1 month') as grp
	from numbered_months
)
select
	customer_id,
	min(purchase_month) as streak_start,
	max(purchase_month) as streak_end,
	count(*) as consecutive_months
from grouped_months
group by customer_id, grp
having count(*) >= 3
order by consecutive_months desc;

-- 7-day moving average of daily order count
with daily_order_count as (
select 
	date_trunc('day',order_purchase_timestamp) as order_date,
	count(*) as total_orders
from analytics.orders
group by 1
)
select
	*,
	round(avg(total_orders) over (order by order_date rows between 6 preceding and current row),2) as weekly_moving_avg
from daily_order_count
order by order_date;

-- the gap (in days) between consecutive orders for each customer
with customer_orders as (
	select 
		customer_id,
		order_id,
		order_purchase_timestamp,
		lag(order_purchase_timestamp) over (partition by customer_id order by order_purchase_timestamp) as prev_order
	from analytics.orders
)
select 
	customer_id,
	order_id,
	order_purchase_timestamp,
	prev_order,
	order_purchase_timestamp - prev_order as order_gap
from customer_orders;

-- ranking sellers by revenue within each state, top 3 per state
with seller_revenue as (
	select
		s.seller_id,
		s.seller_state,
		sum(oi.price) as revenue
	from analytics.sellers s
	join analytics.order_items oi
	on s.seller_id = oi.seller_id
	group by s.seller_id, s.seller_state
),
seller_rank as (
	select
		seller_id,
		seller_state,
		revenue,
		dense_rank() over (partition by seller_state order by revenue desc) as seller_ranking
	from seller_revenue
)
select
	seller_id,
	seller_state,
	revenue,
	seller_ranking
from seller_rank
where seller_ranking <= 3;

-- running total of revenue by date with percentage of grand total
with daily_revenue as (
	select
		date_trunc('day', o.order_purchase_timestamp) as order_date,
		sum(oi.price) as revenue
	from analytics.order_items oi
	join analytics.orders o
	on o.order_id = oi.order_id
	where o.order_status = 'delivered'
	group by 1
)
select
	order_date,
	revenue,
	sum(revenue) over (order by order_date) as running_total,
	round((sum(revenue) over (order by order_date) / sum(revenue) over ())*100,2) as grand_total_percentage
from daily_revenue;

-- a stored procedure to calculate dynamic discount based on rules:
-- 1. New customer (first order): 15% off
-- 2. Order value > $500: 10% off
-- 3. Loyal customer (5+ previous orders): 5% off
-- 4. Apply maximum one discount per order

create or replace procedure analytics.calculate_dynamic_discount (
	in p_customer_id varchar,
	in p_order_value numeric(10,2),
	out discount_percent numeric(10,2),
	out final_amount numeric(10,2)
)
language plpgsql
as $$
declare 
	previous_orders int;
begin

select 
	count(*)
into previous_orders
from analytics.orders
where customer_id = p_customer_id
and order_status = 'delivered';

if previous_orders = 0 then discount_percent := 15;
elsif p_order_value > 500 then discount_percent := 10;
elsif previous_orders >= 5 then discount_percent := 5;
else discount_percent := 0;
end if;

final_amount := p_order_value - (p_order_value * discount_percent/100);
end;
$$;

-- new customer scenario
call analytics.calculate_dynamic_discount(
	'testid01',
	10,
	null,
	null
);
-- returning customer with payment_value > 500
call analytics.calculate_dynamic_discount(
	'9ef432eb6251297304e76186b10a928d',
	520,
	null,
	null
);
-- returning customer with payment_value < 500
call analytics.calculate_dynamic_discount(
	'9ef432eb6251297304e76186b10a928d',
	67,
	null,
	null
);







