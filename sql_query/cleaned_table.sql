-- cek duplicate data
with duplicate as (
select *,
row_number() over(partition by invoiceno, stockcode, country, description order by invoicedate ) as rn
from online_retail_staging
)
select * from duplicate
where rn > 1;



-- standardize the data

select Description
from online_retail_staging
where description = 'USB Office Mirror Ball';

update online_retail_staging
set description = 'USB Office Mirror Ball'
where description = '*USB Office Mirror Ball';

-- delete ambigues data
delete from online_retail_staging
where description = '? sold as sets?';
DELETE FROM online_retail_staging
WHERE description IN (
    '?',
    '? sold as sets ?',
    '??',
    '?? missing',
    '???',
    '????damages????',
    '????missing',
    '???lost',
    '?sold as sets?',
    '?lost',
    '?display?',
    '?missing',
    '???missing'
);
select * FROM online_retail_staging
limit 20;

-- handling null values
SELECT *
from online_retail_staging
where       
    description is null
    and unitprice = 0.00
    and customerid is null;

delete from online_retail_staging
where description is null
and unitprice = 0.00
and customerid is null;

SELECT
    distinct description
from online_retail_staging

-- buat table product_category
alter table online_retail_staging
add column product_category varchar(150);

-- hitung jumlah produk per produk_category
SELECT product_category, COUNT(*)
FROM online_retail_staging
GROUP BY product_category
ORDER BY COUNT(*) DESC;


select customerid, description
from online_retail_staging
where customerid is null;

-- cek harga barang yg 0
select count(*) as null
from online_retail_staging
where unitprice = 0.00;
-- hapus harga barang yang 0
delete from online_retail_staging
where unitprice = 0.00


SELECT COUNT(*) AS total_uncategorized
FROM online_retail_staging
WHERE product_category = 'Uncategorized';


SELECT LOWER(word), COUNT(*) AS frequency
FROM (
    SELECT unnest(string_to_array(regexp_replace(description, '[^A-Za-z0-9 ]', '', 'g'), ' ')) AS word
    FROM online_retail_staging
    WHERE product_category = 'Uncategorized'
) AS words
WHERE word <> ''
GROUP BY word
ORDER BY frequency DESC
LIMIT 100;


delete from online_retail_staging
where customerid is null;

select customerid from online_retail_staging
where customerid is null;