USE RetailAnalysis;
GO
-- Retail project | Step 1: convert to proper data types, check the data, build the clean sales table

-- 1A. Typed copy of the raw data. TRY_CAST returns NULL instead of an error when a value cannot be converted.
DROP TABLE IF EXISTS retail_clean;
-- NOTE: stock_code is converted to UPPER CASE on purpose. The data contains the same product written both ways
-- (for example 85123A and 85123a). SQL Server's default collation treats them as the same anyway, so we make it
-- explicit and the results are identical on any server. This merges 170 duplicate product codes (4,877 -> 4,707).
SELECT
    invoice,
    UPPER(stock_code)                                        AS stock_code,
    [description],
    TRY_CAST(quantity AS INT)                                AS quantity,
    TRY_CAST(invoice_date AS DATETIME2(0))                   AS invoice_date,
    TRY_CAST(price AS DECIMAL(12,4))                         AS price,
    TRY_CAST(NULLIF(LTRIM(RTRIM(customer_id)), '') AS INT)   AS customer_id,
    country
INTO retail_clean
FROM retail_raw;
GO

-- 1B. Did every value convert? (all four numbers must be 0)
SELECT
    SUM(CASE WHEN quantity     IS NULL THEN 1 ELSE 0 END) AS bad_quantity,
    SUM(CASE WHEN invoice_date IS NULL THEN 1 ELSE 0 END) AS bad_date,
    SUM(CASE WHEN price        IS NULL THEN 1 ELSE 0 END) AS bad_price,
    SUM(CASE WHEN invoice IS NULL OR country IS NULL THEN 1 ELSE 0 END) AS missing_invoice_or_country
FROM retail_clean;

-- 1C. Size and period                 (expect 1,067,371 rows | 2009-12-01 to 2011-12-09)
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT invoice) AS invoices,
       MIN(invoice_date) AS first_sale, MAX(invoice_date) AS last_sale
FROM retail_clean;

-- 1D. Missing values                  (expect 243,007 customer IDs | 4,382 descriptions)
SELECT SUM(CASE WHEN customer_id   IS NULL THEN 1 ELSE 0 END) AS missing_customer_id,
       SUM(CASE WHEN [description] IS NULL THEN 1 ELSE 0 END) AS missing_description
FROM retail_clean;

-- 1E. Exact duplicate rows            (expect 34,335)
SELECT COUNT(*) AS duplicate_rows
FROM (
    SELECT ROW_NUMBER() OVER (PARTITION BY invoice, stock_code, [description], quantity,
                                           invoice_date, price, customer_id, country
                              ORDER BY (SELECT NULL)) AS rn
    FROM retail_clean
) x
WHERE x.rn > 1;

-- 1F. Cancellations: invoice numbers starting with C   (expect 8,292 cancelled invoices)
SELECT COUNT(DISTINCT CASE WHEN invoice LIKE 'C%' THEN invoice END) AS cancelled_invoices,
       SUM(CASE WHEN invoice LIKE 'C%' THEN 1 ELSE 0 END)           AS cancelled_lines
FROM retail_clean;

-- 1G. Zero or negative prices         (expect 6,207 rows)
SELECT SUM(CASE WHEN price <= 0 THEN 1 ELSE 0 END) AS price_zero_or_negative,
       SUM(CASE WHEN invoice NOT LIKE 'C%' AND quantity <= 0 THEN 1 ELSE 0 END) AS non_cancel_qty_zero_or_negative
FROM retail_clean;

-- 1H. Stock codes that are NOT products (postage, fees, manual adjustments ...)
--     A real product code = 5 digits, then 0 to 2 letters (for example 85048 or 79323P)
SELECT TOP 12 stock_code, COUNT(*) AS lines
FROM retail_clean
WHERE NOT (stock_code LIKE '[0-9][0-9][0-9][0-9][0-9]%'
           AND LEN(stock_code) <= 7
           AND SUBSTRING(stock_code, 6, 2) NOT LIKE '%[^A-Za-z]%')
GROUP BY stock_code
ORDER BY lines DESC;

-- 1I. THE CLEAN SALES TABLE: real sales of real products only, duplicates removed
DROP TABLE IF EXISTS sales_clean;
WITH f AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY invoice, stock_code, [description], quantity,
                                           invoice_date, price, customer_id, country
                              ORDER BY (SELECT NULL)) AS rn
    FROM retail_clean
    WHERE invoice NOT LIKE 'C%'                      -- not a cancellation
      AND quantity > 0 AND price > 0                 -- a real sale
      AND stock_code LIKE '[0-9][0-9][0-9][0-9][0-9]%'
      AND LEN(stock_code) <= 7
      AND SUBSTRING(stock_code, 6, 2) NOT LIKE '%[^A-Za-z]%'   -- a real product code
)
SELECT invoice, stock_code, [description], quantity,
       CAST(invoice_date AS DATE)  AS sale_date,
       invoice_date,
       price, customer_id, country,
       CAST(quantity * price AS DECIMAL(18,4)) AS revenue      -- revenue in GBP
INTO sales_clean
FROM f
WHERE rn = 1;
GO
CREATE INDEX ix_sales_product ON sales_clean(stock_code);
CREATE INDEX ix_sales_date    ON sales_clean(sale_date);
GO

-- 1J. Result of cleaning        (expect 1,003,213 rows | 4,707 products | 39,516 invoices | revenue 19,642,676)
SELECT COUNT(*) AS clean_rows, COUNT(DISTINCT stock_code) AS products,
       COUNT(DISTINCT invoice) AS invoices, ROUND(SUM(revenue), 0) AS revenue_gbp
FROM sales_clean;
