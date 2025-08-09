-- 1. mencari average net revenue untuk tahun 2010 dan 2011 (YoY)
SELECT
    product_category,
    round(COALESCE(avg(
        CASE
            when invoicedate::date between '2010-01-01' and '2010-12-31'
            then quantity * unitprice 
            else null
    end), 0), 2) as avg_net_revenue_2010,
    round(COALESCE(avg(
        CASE
            when invoicedate::date between '2011-01-01' and '2011-12-31'
            then quantity * unitprice 
            else null
    end), 0), 2) as avg_net_revenue_2011
from 
    online_retail_staging
group BY
    product_category
order BY
    product_category;

-- 2. mencari min dan max dari net revenue untuk tahun 2010-2011
SELECT
    product_category,
    round(min(case
                when invoicedate between '2010-01-01' and '2010-12-31'
                then quantity::numeric * unitprice::numeric
                else null
    end), 2) as min_net_revenue_2010,
    round(max(case
                when invoicedate between '2010-01-01' and '2010-12-31'
                then quantity::numeric * unitprice::numeric
                else null
    end), 2) as max_net_revenue_2010,
    round(min(case
                when invoicedate between '2011-01-01' and '2011-12-31'
                then quantity::numeric * unitprice::numeric
                else null
    end), 2) as min_net_revenue_2011,
    round(max(case
                when invoicedate between '2011-01-01' and '2011-12-31'
                then quantity::numeric * unitprice::numeric
                else null
    end), 2) as max_net_revenue_2011

from online_retail_staging
group BY
    product_category
order BY
    product_category limit 10;


-- 3. mencari median untuk net revenue
select
    product_category,
    percentile_cont(0.5) within GROUP
    (order by (
        case
            when invoicedate between '2011-01-01' and '2011-12-31'
            then (quantity * unitprice)
     end)) as median_sales_2011

from online_retail_staging
group BY
    product_category
order BY
    product_category;

-- 4.segmenting order dari median
select
    percentile_cont(0.5) within group (order by (
        quantity * unitprice
    )) as median_sales
from online_retail_staging
where
    invoicedate between '2011-01-01' and '2011-12-31';

-- 5.low and high revenue di tahun 2011
WITH median_value AS (
    SELECT
        percentile_cont(0.5) WITHIN GROUP (ORDER BY quantity * unitprice) AS median_sales
    FROM online_retail_staging
    WHERE invoicedate BETWEEN '2011-01-01' AND '2011-12-31'
),
categorized_revenue AS (
    SELECT
        product_category,
        quantity * unitprice AS revenue,
        m.median_sales
    FROM online_retail_staging s, median_value m
    WHERE s.invoicedate BETWEEN '2011-01-01' AND '2011-12-31'
)
SELECT
    product_category,
    SUM(CASE WHEN revenue < median_sales THEN revenue END) AS low_revenue_2011,
    SUM(CASE WHEN revenue >= median_sales THEN revenue END) AS high_revenue_2011
FROM categorized_revenue
GROUP BY product_category
ORDER BY product_category;

