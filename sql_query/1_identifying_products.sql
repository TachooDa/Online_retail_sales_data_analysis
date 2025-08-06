-- 1. mencari net revenue
SELECT 
   DISTINCT product_category,
    invoicedate::date,
    stockcode,
    (quantity * unitprice) as net_revenue
from online_retail_staging
WHERE 
    invoicedate between '2011-01-01' and '2011-12-31'
    and (Quantity * UnitPrice) > 0
    and stockcode NOT IN ('S','POST','BANK CHARGES', 'AMAZONFEE', 'MANUAL', 'D', 'CRUK', 'M', 'B', 'DOT')
order by
 net_revenue desc
 limit 25;


 --2. mencari total produk terbanyak terjual top 10
 select 
    description,
    product_category,
    stockcode,
    sum(quantity) as total_sold
 from 
    online_retail_staging
WHERE
     quantity > 0
group by
    stockcode,
    product_category,
    description
order BY
    total_sold desc
limit 10;

-- 3.classification untuk high,low net revenue
WITH product_revenue_level AS (
    SELECT 
        stockcode,
        description,
        product_category,
        SUM(quantity * unitprice) AS net_revenue
    FROM online_retail_staging
    WHERE 
        description IS NOT NULL
        AND quantity > 0
        AND unitprice > 0
        AND stockcode NOT IN ('S','POST','BANK CHARGES', 'AMAZONFEE', 'MANUAL', 'D', 'CRUK', 'M', 'B', 'DOT')
    GROUP BY stockcode, product_category, description
)
SELECT
    stockcode,
    description,
    product_category,
    net_revenue,
    CASE
        WHEN net_revenue > 1000 THEN 'high'
        ELSE 'low'
    END AS revenue_level
FROM product_revenue_level
WHERE 
    product_category IS NOT NULL
    AND net_revenue > 0
ORDER BY
    product_category DESC;


-- 4. total barang yang jadi  barang return untuk setiap category
WITH barang_return AS (
    SELECT
        stockcode,
        product_category,
        SUM(quantity * unitprice) AS net_revenue
    FROM online_retail_staging
    WHERE
        quantity < 0
        AND stockcode NOT IN ('S','POST','BANK CHARGES', 'AMAZONFEE', 'MANUAL', 'D', 'CRUK', 'M', 'B', 'DOT')
    GROUP BY stockcode, product_category
)
SELECT
    product_category,
    COUNT(*) AS total_barang_direturn
FROM barang_return
WHERE
    net_revenue < 0
group by 
    product_category
order BY
    total_barang_direturn desc;


-- 5.Mencari top selling product berdasarkan country
 -- use cte buat dapetin top 1 per product dan country
WITH top_1 AS ( -- CTE: Hitung produk terlaris (berdasarkan quantity) per country
    SELECT
        country,
        stockcode,
        product_category,
        ROUND(AVG(unitprice), 2) AS avg_unitprice,
        SUM(quantity) AS total_terjual,
        SUM(quantity * unitprice) AS net_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY country 
            ORDER BY SUM(quantity) DESC
        ) AS quantity_rank
    FROM online_retail_staging
    WHERE   
        quantity > 0
        and unitprice > 0
        AND stockcode NOT IN ('S','POST','BANK CHARGES', 'AMAZONFEE', 'MANUAL', 'D', 'CRUK', 'M', 'B', 'DOT')
    GROUP BY
        country, stockcode, product_category
)
SELECT *
FROM top_1
WHERE quantity_rank = 1
ORDER BY net_revenue DESC;

 -- 6. total pendapatan bersih (net revenue) pada tahun 2011 saja
 SELECT
 description,
    product_category,
    invoicedate::date,
    sum(
        CASE
            when invoicedate between '2011-01-01' and '2011-12-31'
            then quantity * unitprice
            else 0
     end) as total_net_revenue_2011
 from online_retail_staging
 WHERE
    stockcode NOT IN ('S','POST','BANK CHARGES', 'AMAZONFEE', 'MANUAL', 'D', 'CRUK', 'M', 'B', 'DOT')
    and quantity * unitprice >= 0
 group BY
    product_category, invoicedate, description
order BY
    total_net_revenue_2011 DESC limit 15;