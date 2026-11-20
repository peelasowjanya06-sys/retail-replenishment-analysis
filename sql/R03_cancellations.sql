USE RetailAnalysis;
GO
-- Retail project | Step 3: cancellations (returned or cancelled orders)

-- 3A. Overall: how many invoices were cancellations, and how much money?
WITH inv AS (
    SELECT COUNT(DISTINCT invoice) AS all_invoices,
           COUNT(DISTINCT CASE WHEN invoice LIKE 'C%' THEN invoice END) AS cancelled_invoices
    FROM retail_clean
),
val AS (
    SELECT SUM(ABS(CAST(quantity AS DECIMAL(18,4))) * price) AS cancelled_value
    FROM retail_clean
    WHERE invoice LIKE 'C%' AND price > 0
      AND stock_code LIKE '[0-9][0-9][0-9][0-9][0-9]%'
      AND LEN(stock_code) <= 7
      AND SUBSTRING(stock_code, 6, 2) NOT LIKE '%[^A-Za-z]%'
)
SELECT i.all_invoices, i.cancelled_invoices,
       ROUND(100.0 * i.cancelled_invoices / i.all_invoices, 2)                 AS cancelled_pct_of_invoices,
       ROUND(v.cancelled_value, 0)                                             AS cancelled_value_gbp,
       ROUND(100.0 * v.cancelled_value / (SELECT SUM(revenue) FROM sales_clean), 1) AS cancelled_pct_of_sales
FROM inv i CROSS JOIN val v;

-- 3B. Cancellation rate by month
SELECT DATEFROMPARTS(YEAR(invoice_date), MONTH(invoice_date), 1) AS month_start,
       COUNT(DISTINCT invoice)                                    AS invoices,
       COUNT(DISTINCT CASE WHEN invoice LIKE 'C%' THEN invoice END) AS cancelled_invoices,
       ROUND(100.0 * COUNT(DISTINCT CASE WHEN invoice LIKE 'C%' THEN invoice END)
             / COUNT(DISTINCT invoice), 1)                        AS cancelled_pct
FROM retail_clean
GROUP BY DATEFROMPARTS(YEAR(invoice_date), MONTH(invoice_date), 1)
ORDER BY month_start;

-- 3C. Products with the most cancelled units (candidates for a quality or description problem)
SELECT TOP 10 stock_code, MAX([description]) AS [description],
       SUM(-quantity) AS units_cancelled
FROM retail_clean
WHERE invoice LIKE 'C%' AND price > 0
  AND stock_code LIKE '[0-9][0-9][0-9][0-9][0-9]%'
  AND LEN(stock_code) <= 7
  AND SUBSTRING(stock_code, 6, 2) NOT LIKE '%[^A-Za-z]%'
GROUP BY stock_code
ORDER BY units_cancelled DESC;
