-- Retail project | Step 0 (SQL Server / SSMS): create the database and load the raw CSV
-- BEFORE running: unzip online_retail_II_csv.zip and put online_retail_II.csv in C:\Retail\
-- (If you use another folder, change the path in the BULK INSERT line.)

IF DB_ID('RetailAnalysis') IS NULL CREATE DATABASE RetailAnalysis;
GO
USE RetailAnalysis;
GO

-- Staging table: every column is TEXT on purpose, so the load can never fail on a bad value.
-- We convert to proper types in the next script, and we can SEE which values are bad.
DROP TABLE IF EXISTS retail_raw;
CREATE TABLE retail_raw (
    invoice       VARCHAR(30),
    stock_code    VARCHAR(40),
    [description] NVARCHAR(400),
    quantity      VARCHAR(30),
    invoice_date  VARCHAR(30),
    price         VARCHAR(30),
    customer_id   VARCHAR(30),
    country       VARCHAR(60)
);
GO

BULK INSERT retail_raw
FROM 'C:\Retail\online_retail_II.csv'
WITH (
    FORMAT          = 'CSV',
    FIRSTROW        = 2,            -- skip the header line
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0a',       -- the file uses Unix line endings
    CODEPAGE        = '65001',      -- UTF-8
    KEEPNULLS,                      -- empty cells become NULL
    TABLOCK
);
GO

-- Must return 1,067,371
SELECT COUNT(*) AS rows_loaded FROM retail_raw;
