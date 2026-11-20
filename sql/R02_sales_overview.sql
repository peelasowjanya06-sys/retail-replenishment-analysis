USE RetailAnalysis;
GO
-- Retail project | Step 2: sales overview (the questions a manager asks first)

-- 2A. Headline numbers
SELECT ROUND(SUM(revenue), 0)              AS revenue_gbp,
       COUNT(DISTINCT invoice)             AS invoices,
       COUNT(DISTINCT stock_code)          AS products,
       COUNT(DISTINCT customer_id)         AS identified_customers,
       ROUND(SUM(revenue) / COUNT(DISTINCT invoice), 2) AS avg_invoice_value
FROM sales_clean;

-- 2B. Revenue by year (2009 and 2011 are partial years: data runs 1 Dec 2009 to 9 Dec 2011)
SELECT YEAR(sale_date) AS sales_year, ROUND(SUM(revenue), 0) AS revenue_gbp, COUNT(DISTINCT invoice) AS invoices
FROM sales_clean
GROUP BY YEAR(sale_date)
ORDER BY sales_year;

-- 2C. Revenue by month with month-over-month change (LAG)
WITH monthly AS (
    SELECT DATEFROMPARTS(YEAR(sale_date), MONTH(sale_date), 1) AS month_start,
           SUM(revenue) AS revenue
    FROM sales_clean
    GROUP BY DATEFROMPARTS(YEAR(sale_date), MONTH(sale_date), 1)
)
SELECT month_start,
       ROUND(revenue, 0)                                           AS revenue_gbp,
       ROUND(LAG(revenue) OVER (ORDER BY month_start), 0)          AS prev_month_revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month_start))
             / NULLIF(LAG(revenue) OVER (ORDER BY month_start), 0), 1) AS mom_change_pct
FROM monthly
ORDER BY month_start;

-- 2D. Top 10 countries by revenue, with share of total (window SUM)
SELECT TOP 10 country,
       ROUND(SUM(revenue), 0)                                  AS revenue_gbp,
       ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 1) AS pct_of_revenue
FROM sales_clean
GROUP BY country
ORDER BY SUM(revenue) DESC;

-- 2E. How much revenue has no customer ID? (these rows still count for product analysis)
SELECT CASE WHEN customer_id IS NULL THEN 'No customer ID' ELSE 'Has customer ID' END AS customer_type,
       COUNT(*)                                                   AS lines,
       ROUND(SUM(revenue), 0)                                     AS revenue_gbp,
       ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 1) AS pct_of_revenue
FROM sales_clean
GROUP BY CASE WHEN customer_id IS NULL THEN 'No customer ID' ELSE 'Has customer ID' END;
