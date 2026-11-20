USE RetailAnalysis;
GO
-- Retail project | Step 6: the restock priority list + the views Power BI will read

-- 6A. RESTOCK PRIORITY LIST: A-class products that sell 1.5x faster in Sep-Nov (before the peak, stock up)
CREATE OR ALTER VIEW v_restock_priority AS
SELECT p.stock_code, p.[description], p.units AS total_units, p.revenue,
       ROUND(u.base_avg_monthly_units, 1)  AS base_monthly_units,
       ROUND(u.peak_avg_monthly_units, 1)  AS peak_monthly_units,
       ROUND(u.uplift_multiple, 2)         AS uplift_multiple,
       ROUND(v.sd_monthly_units, 1)        AS sd_monthly_units,
       ROUND(v.cv, 2)                      AS cv,
       v.demand_pattern,
       CASE WHEN v.demand_pattern = 'Volatile'
            THEN 'Restock before peak + extra safety stock'
            ELSE 'Restock before peak' END AS recommended_action
FROM v_product_abc p
JOIN v_peak_uplift u        ON u.stock_code = p.stock_code
JOIN v_demand_variability v ON v.stock_code = p.stock_code
WHERE p.abc_class = 'A' AND u.uplift_multiple >= 1.5;
GO

SELECT COUNT(*) AS priority_products FROM v_restock_priority;                       -- expect 400
SELECT TOP 15 * FROM v_restock_priority ORDER BY revenue DESC;
SELECT demand_pattern, COUNT(*) AS products FROM v_restock_priority GROUP BY demand_pattern;

GO

-- 6B. Views for Power BI ------------------------------------------------------
-- Fact table: one row per sale line (no long text, keeps Power BI fast)
CREATE OR ALTER VIEW v_sales_fact AS
SELECT invoice, stock_code, sale_date, country, customer_id, quantity, price, revenue
FROM sales_clean;
GO

-- Monthly summary: sales plus cancellations (from retail_clean, which still has the C invoices)
CREATE OR ALTER VIEW v_monthly_summary AS
WITH inv AS (
    SELECT DATEFROMPARTS(YEAR(invoice_date), MONTH(invoice_date), 1) AS month_start,
           COUNT(DISTINCT invoice) AS invoices_all,
           COUNT(DISTINCT CASE WHEN invoice LIKE 'C%' THEN invoice END) AS invoices_cancelled
    FROM retail_clean
    GROUP BY DATEFROMPARTS(YEAR(invoice_date), MONTH(invoice_date), 1)
),
rev AS (
    SELECT DATEFROMPARTS(YEAR(sale_date), MONTH(sale_date), 1) AS month_start,
           SUM(revenue) AS revenue
    FROM sales_clean
    GROUP BY DATEFROMPARTS(YEAR(sale_date), MONTH(sale_date), 1)
)
SELECT i.month_start, ROUND(r.revenue, 2) AS revenue, i.invoices_all, i.invoices_cancelled
FROM inv i JOIN rev r ON r.month_start = i.month_start;
GO

SELECT COUNT(*) AS fact_rows FROM v_sales_fact;
SELECT TOP 5 * FROM v_monthly_summary ORDER BY month_start;
