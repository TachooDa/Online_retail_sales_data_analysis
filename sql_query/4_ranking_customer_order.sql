select * from online_retail_staging limit 10;
-- 1. window function & group by
with customer_order as (
SELECT
    customerid,
    quantity * unitprice as sales,
    count(*) over(partition by customerid) as total_order
from online_retail_staging
)
SELECT
    customerid,
    total_order,
    round(avg(sales),2) as avg_sales_revenue
from customer_order
group by customerid, total_order;

-- 2. customer life time value and average ltv
with yearly_cohort as (
SELECT
    customerid,
    extract(year from min(invoicedate)) as cohort_year,
    round(sum(quantity * unitprice),2) as customer_ltv
from online_retail_staging
group by customerid
)
select *,
    round(avg(customer_ltv) over(partition by cohort_year),2) as avg_cohort_ltv
from yearly_cohort;

-- 3. Running order count
select
    customerid,
    invoicedate::date,
    (quantity * unitprice) as revenue,
    count(*) over(
        partition by customerid
        order by invoicedate
    ) as running_order_count,
    round(avg(quantity * unitprice) over (
        partition by customerid
        order by invoicedate
    ),2) as running_avg_revenue
from online_retail_staging;

-- 4. row numbering order
with row_numbering as (
select
    row_number() over(
        partition by invoicedate
        order by
            invoiceno,
            invoiceno || '-' || stockcode
    ) as row_num,
     invoiceno || '-' || stockcode as order_line_number,
    *
from online_retail_staging
)
select *
from row_numbering
where invoicedate > '2011-01-01';

-- 5. rank() dense_rank()
select 
    customerid,
    count(*) as total_order,
    row_number() over(order by count(*) desc) as total_order_row_num,
    rank() over(order by count(*) desc) as total_order_rank,
    dense_rank() over(order by count(*) desc) as total_order_dr
from online_retail_staging
group by customerid
limit 10;

-- 6. first_value(), last_value(), nth_value()
with monthly_revenue as (
select
    to_char(invoicedate, 'YYYY-MM') as month,
    sum(quantity * unitprice) as revenue
from online_retail_staging
where
    extract(year from invoicedate) = 2011
group by month
order by month
)
select *,
    first_value(revenue) over(order by month) as f_month_rev,
    -- include unbounded preceding dan unbounded following
    last_value(revenue) over(order by month rows between unbounded preceding and unbounded following) as last_month_rev,
    -- include unbounded preceding dan unbounded following
    nth_value(revenue, 3) over(order by month rows between unbounded preceding and unbounded following) as third_month_rev
from monthly_revenue

-- 7. lag() & lead() untuk mencari MOM growth
with monthly_revenue as (
select
    to_char(invoicedate, 'YYYY-MM') as month,
    sum(quantity * unitprice) as revenue
from online_retail_staging
where
    extract(year from invoicedate) = 2011
group by month
order by month
)
select *,
    lag(revenue) over(order by month) as previous_month_revenue,
    -- to find a monthly revenue growth in percentage ( round to 2 decimal places)
    round(100 * (revenue -   lag(revenue) over(order by month)) /
      lag(revenue) over(order by month), 2)as monthly_rev_growth
from monthly_revenue;

-- 8. Yearly Cohort
with yearly_cohort as (
select
    customerid,
    extract(year from min(invoicedate)) as cohort_year,
    sum(quantity * unitprice) as customer_ltv
from online_retail_staging
group by customerid
), cohort_summary as (
    select
        cohort_year,
        customerid,
        customer_ltv,
        round(avg(customer_ltv) over(partition by cohort_year),2) as avg_cohort_ltv
    from yearly_cohort
    order by
        cohort_year,
        customerid
), cohort_final as (
    select distinct
        cohort_year,
        avg_cohort_ltv
    from cohort_summary
    order by cohort_year
)
select *,
    round(lag(avg_cohort_ltv) over(order by cohort_year), 2) as prev_cohort_ltv,
    -- find percentage of LTV change ( life time value change)
    round(100 * (avg_cohort_ltv - lag(avg_cohort_ltv) over(order by cohort_year)) /
    lag(avg_cohort_ltv) over(order by cohort_year), 2 
    ) as ltv_change
from cohort_final;