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


-- 6. Top 15 kategori produk berdasarkan total revenue
select
    product_category,
    sum(quantity * unitprice) as total_revenue
from 
    online_retail_staging
group by
    product_category
order BY
    total_revenue desc
limit 15;


-- 7. A/B Testing Workflow
-- Step 1 - Aggregate metrics per group
select * from online_retail_staging limit 10;
WITH base_data AS (
    SELECT
        *,
        CASE
            WHEN country = 'Netherlands' THEN 'A'
            ELSE 'B'
        END AS variant,
        CASE
            WHEN quantity > 0 THEN 1 ELSE 0
        END AS conversion,
        (quantity * unitprice) AS revenue
    FROM online_retail_staging
),
agg AS (
    SELECT
        variant,
        COUNT(DISTINCT customerid)::float AS total_customer,
        SUM(conversion)::float AS total_conversions,
        AVG(conversion)::float AS avg_conversions,
        AVG(revenue)::float AS avg_order_value
    FROM base_data
    where variant is not null
    GROUP BY variant
),
pooled AS (
    SELECT
        MAX(CASE WHEN variant = 'A' THEN total_customer END) AS n1,
        MAX(CASE WHEN variant = 'A' THEN total_conversions END) AS x1,
        MAX(CASE WHEN variant = 'B' THEN total_customer END) AS n2,
        MAX(CASE WHEN variant = 'B' THEN total_conversions END) AS x2
    FROM agg
)
SELECT
    p1,
    p2,
    p_pooled,
    CASE 
        WHEN p_pooled > 0 AND p_pooled < 1
             AND (1.0/n1 + 1.0/n2) > 0
        THEN (p1 - p2) / SQRT(p_pooled * (1 - p_pooled) * (1.0/n1 + 1.0/n2))
        ELSE NULL
    END AS z_score
FROM (
    SELECT
        (x1/n1) AS p1,
        (x2/n2) AS p2,
        ((x1 + x2) / (n1 + n2)) AS p_pooled,
        n1, n2
    FROM pooled
) t
WHERE n1 > 0 AND n2 > 0
LIMIT 10;
