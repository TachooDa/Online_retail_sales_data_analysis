select * from online_retail_staging limit 10;
-- 1. Change over time analysis
select
    extract(year from invoicedate) as order_year,
    extract(month from invoicedate) as order_month,
    round(sum(quantity::numeric * unitprice::numeric),0) as total_revenue,
    count(distinct customerid) as total_customers,
    sum(quantity) as total_units
from online_retail_staging
group by  extract(year from invoicedate), extract(month from invoicedate)
order by order_year, order_month;

-- 2. cumulative analysis
select
    order_month,
    total_sales,
    sum(total_sales) over(order by order_month) as running_total_sales,
    round(avg(avg_price) over(order by order_month),2) as moving_avg_price
from (
select
    to_char(date_trunc('month', invoicedate), 'yyyy-mm') as order_month,
    sum(unitprice) as total_sales,
    round(avg(unitprice::numeric),2) as avg_price
from online_retail_staging
group by to_char(date_trunc('month', invoicedate), 'yyyy-mm')
)t
order by order_month;

-- 3. Performance onlince retail sales analysis
/*
    Purpose:
        - Analyze the yearly performance of product by comparing their sales and
        both the average sales performance of the product end the previous year
*/
with yearly_product_sales as (
select
    extract(year from invoicedate) as order_year,
    description,
    round(sum(unitprice::numeric),0) as current_sales
from online_retail_staging
group by extract(year from invoicedate), description
), sales_with_flag as (
select
    order_year,
    description,
    current_sales,
    round(avg(current_sales) over(order by order_year),2) as avg_sales,
    round((current_sales - avg(current_sales) over(order by order_year)),2) as diff_avg,
    case
        when (current_sales - avg(current_sales) over(order by order_year)) > 0 then 'above_average'
        when (current_sales - avg(current_sales) over(order by order_year)) < 0 then 'below_average'
        else 'average'
    end as avg_flage,
    lag(current_sales) over(partition by description order by order_year) as pv_year_sales,
    case
        when current_sales - lag(current_sales) over(partition by description order by order_year) > 0 then 'Increase'
        when current_sales - lag(current_sales) over(partition by description order by order_year) < 0 then 'Decrease'
        else 'No change'
    end as diff_py_flag
from yearly_product_sales 
order by description, order_year
)
select * from sales_with_flag
where pv_year_sales is not null
order by description, order_year;

-- 4. Part to whole analysis
-- whixh categories contribute total reveneu the most overall sales
with category_sales as (
select
    product_category,
    round(sum(quantity * unitprice),0) as total_revenue
from online_retail_staging
group by product_category
)
select 
    product_category,
    total_revenue,
    round(sum(total_revenue::numeric) over(), 0) as overall_revenue,
    concat(round((total_revenue::numeric / sum(total_revenue)over())*100,2),'%') as pct_of_total
from category_sales
order by pct_of_total desc;


-- 5. data(procduk or customer) segmentation
-- Segment product or customer into cost rangea 
-- and count how many  prodcut fall into each segment
/*
Low : < 2.500
Medium : 2.500 – 5000
High : > 5000
*/
with product_segment as (
select 
    invoiceno,
    description,
    sum(unitprice * 0.7) as estimated_cost, -- estimasi kan cost yg diguunakan(sesuai jenis usaha)
    case
        when sum(unitprice * 0.7) < 2.500 then 'below 2500'
        when sum(unitprice*0.7) between 2.500 and 5.000 then '2500 - 5000'
        else 'above 5000'
    end as cost_range
from online_retail_staging
group by invoiceno, description
)
select
    cost_range,
    count(invoiceno) as total_product,
    concat(ROUND(
        COUNT(invoiceno) * 100.0 / SUM(COUNT(invoiceno)) OVER (), 2
    ), '%') AS percentage_product
from product_segment
group by cost_range
order BY total_product desc;

/*Group customer into three segments base on ther spending behavioor:
    - VIP : customer with at least 12 month of history and spending more than
    - regular : customer with at least 12 month of history and spending between or less
    - new : customer with less than 12 month of history
and find the total number of customer by each group
*/
with customer_spending as (
select
    customerid,
    sum(quantity * unitprice) as total_spending,
    min(invoicedate::date) as first_order,
    max(invoicedate::date) as last_order,
    ROUND(EXTRACT(DAY FROM (MAX(invoicedate) - MIN(invoicedate))) / 30.0, 0) AS lifespan_in_months
from online_retail_staging
group by customerid
)
select
    customer_segment,
    count(customerid) as total_customer,
    concat(round(count(customerid) *100 /sum(count(customerid)) over(),2),'%') as percent_customer
from (
select
    customerid,
    case
        when lifespan_in_months >= 12 and total_spending > 5000 then 'VIP'
        when lifespan_in_months >= 12 and total_spending BETWEEN 0 AND 5000 then 'Regular'
        else 'New'
    end as customer_segment
from customer_spending
)t
group by customer_segment
order by total_customer desc;


-- 6. Customer Report
/*
    Highlight Kebutuhan:
    1. Mengambil field penting dari tabel transaksi (invoiceno, stockcode, tanggal, quantity, unitprice, customerid, country).
    2. Melakukan agregasi per customer untuk menghitung:
       - total_orders   : jumlah order unik per customer
       - total_sales    : total penjualan (quantity * unitprice)
       - total_qty      : total kuantitas produk yang dibeli
       - total_products : jumlah produk unik yang pernah dibeli
       - last_order_date: tanggal transaksi terakhir
       - lifespan       : umur customer dalam bulan (selisih order pertama dan terakhir)
    3. Segmentasi customer:
       - VIP     : lifespan ≥ 12 bulan dan total_sales > 5000
       - Regular : lifespan ≥ 12 bulan dan total_sales 0–5000
       - New     : selain kondisi di atas (baru / belum 12 bulan)
    4. Menghitung recency (recency_months):
       - Selisih dalam bulan antara tanggal hari ini (CURRENT_DATE) dengan last_order_date.
    5. Menghitung metrik tambahan untuk analisis:
       - avg_order_value   : rata-rata nilai order (total_sales / total_orders)
       - avg_monthly_spend : rata-rata spending bulanan (total_sales / lifespan)
    6. Filter customer yang valid:
       - hanya menampilkan customer dengan total_sales > 0 (agar fokus pada pembeli yang benar-benar melakukan transaksi).
*/

with base_query as (
-- 1. base query to get essential fields
select 
    invoiceno,
    stockcode,
    invoicedate::date as invoicedate,
    quantity,
    unitprice,
    customerid,
    country
from online_retail_staging
where invoicedate is not null
), customer_aggregation as (
select
    customerid,
    country,
    count(distinct invoiceno) as total_orders,
    sum(quantity * unitprice) as total_sales,
    sum(quantity) as total_qty,
    count(distinct stockcode::text) as total_products,
    max(invoicedate::date) as last_order_date,
    ROUND((MAX(invoicedate) - MIN(invoicedate))::numeric / 30.0, 0) AS lifespan
from base_query
group by customerid, country
)
select
    customerid,
    country,
    total_orders,
    case
        when lifespan >= 12 and total_sales > 5000 then 'VIP'
        when lifespan >= 12 and total_sales  BETWEEN 0 AND 5000 then 'Regular'
        else 'New'
    end as customer_segment,
    last_order_date,
    DATE_PART('month', AGE(CURRENT_DATE, last_order_date)) AS recency_months,
    total_sales,
    total_qty,
    total_products,
    lifespan,
    -- hitung average order valu (AVO/AOV)
    case
        when total_orders = 0 then 0
        else round(total_sales / total_orders,0)
    end as avg_order_value,
    -- hitung average monthly spend
    case
        when lifespan = 0 then total_sales
        else round(total_sales / lifespan,0)
    end as avg_monthly_spend
from customer_aggregation
where
    total_sales > 0