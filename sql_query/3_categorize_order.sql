-- 1.Categorize order untuk high value dan standard order
SELECT
    invoicedate::date,
    quantity,
    unitprice,
    CASE
        when quantity >= 2 and unitprice >=4 then 'High value order'
        else 'Standard order'
    end as order_type

from online_retail_staging
limit 10;

-- 2. median per produk untuk tahun 2011
with median_value as (
SELECT
    product_category,
    percentile_cont(0.5) within group (
        order by (quantity * unitprice)
    ) as median
from online_retail_staging
WHERE
    invoicedate between '2011-01-01' and '2011-12-31'
group BY
    product_category
)
select
    o.product_category,
    round(avg(mv.median::numeric), 2) as median,
coalesce(sum(case
    when (quantity * unitprice) < mv.median
         and invoicedate between '2011-01-01' and '2011-12-31'
    then (quantity * unitprice)
end), 0) as low_revenue_2011,
    sum(case
            when (quantity * unitprice) >= mv.median
            and invoicedate between '2011-01-01' and '2011-12-31'
            then (quantity * unitprice)
    end) as high_revenue_2011
from online_retail_staging as o
inner join median_value as mv on mv.product_category = o.product_category
group by
    o.product_category
order by
    o.product_category;

-- 3. IQR Percentile untuk quarter1-quarter3 atau (q3-q1) 
select
    percentile_cont(0.25) within group 
    (order by
        (quantity * unitprice)
    ) as rev_q1_2010_2011, -- 25th percentile (Q1)
    percentile_cont(0.75) within group 
    (order by
        (quantity * unitprice)
    ) as rev_q3_2010_2011 -- 75th percentile (Q3)

from online_retail_staging
where
    invoicedate between '2010-01-01' and '2011-12-31';

/* 4. Segmenting percentile order to analyze
    low,medium and high untuk revenue dari tahun 2010-2011
*/
with percentile as (
select
    percentile_cont(0.25) within group 
    (order by
        (quantity * unitprice)
    ) as rev_q1_2010_2011, -- 25th percentile (Q1)
    percentile_cont(0.75) within group 
    (order by
        (quantity * unitprice)
    ) as rev_q3_2010_2011 -- 75th percentile (Q3)

from online_retail_staging
where
    invoicedate between '2010-01-01' and '2011-12-31'
)
select
    o.product_category as category_name,
    case
        when (o.quantity * o.unitprice) <= pctl.rev_q1_2010_2011 THEN '3-LOW'
        when (o.quantity * o.unitprice) >= pctl.rev_q3_2010_2011 then '1-HIGH'
        else '2-MEDIUM'
    end as revenue_tier,
    sum(quantity * unitprice) as total_revenue
from online_retail_staging as o
cross join percentile as pctl
group by
    o.product_category,
    revenue_tier
order by
    category_name,
    revenue_tier;


-- 5. mencari order line number, net revenue, daily net revenue dan, purchase time_daily revenu
select *,
    round(100 * net_revenue / daily_net_revenue, 2) as pct_daily_revenue
from (
select 
    invoicedate::date,
    invoiceno || '-' || stockcode as order_line_number,
    (quantity * unitprice) as net_revenue,
    sum(quantity * unitprice)
    over(partition by invoicedate::date) as daily_net_revenue
from 
    online_retail_staging
limit 10
) as revenue_by_day;


-- 6. Cohort analysis(grouping customer order year by year)
with yearly_cohort as(
select
    distinct customerid,
    extract(YEAR FROM MIN(invoicedate) over(partition by customerid)) as cohort_year
from online_retail_staging
)
select 
    yc.cohort_year,
    extract(YEAR FROM invoicedate) as purchase_year,
    sum(o.quantity * o.unitprice) as net_revenue

from online_retail_staging as o
inner join yearly_cohort as yc on o.customerid = yc.customerid
group by
    yc.cohort_year,
    purchase_year;

-- 7. Cohort analysis(grouping customer order month by month)
with monthly_cohort as(
select
    distinct customerid,
    extract(MONTH FROM MIN(invoicedate) over(partition by customerid)) as cohort_month
from online_retail_staging
)
select 
    mc.cohort_month,
    extract(MONTH FROM invoicedate) as purchase_month,
    sum(o.quantity * o.unitprice) as net_revenue

from online_retail_staging as o
inner join monthly_cohort as mc on o.customerid = mc.customerid
group by
    mc.cohort_month,
    purchase_month;


