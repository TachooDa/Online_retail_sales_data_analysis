create table online_retail_staging (
    index int primary key,
    InvoiceNo varchar(50),
    StockCode varchar(255),
    Description text,
    Quantity int,
    InvoiceDate timestamp,
    UnitPrice DECIMAL(10,2),
    CustomerID int,
    Country varchar(200)
);

truncate table online_retail_staging;
drop table online_retail_staging;