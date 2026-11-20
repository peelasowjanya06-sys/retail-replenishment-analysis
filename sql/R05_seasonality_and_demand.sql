USE RetailAnalysis;
GO
-- Retail project | Step 5: seasonality and demand variability

-- 5A. How much of each year's revenue comes in September to November?
--     (2009 is only December, and 2011 stops on 9 Dec, so compare 2010 and 2011)
SELECT YEAR(sale_date) AS sales_year,
       ROUND(100.0 * SUM(CASE WHEN MONTH(sale_date) IN (9, 10, 11) THEN revenue ELSE 0 END)
             / SUM(revenue), 1) AS sep_nov_pct_of_year
FROM sales_clean
WHERE YEAR(sale_date) IN (2010, 2011)
GROUP BY YEAR(sale_date)
ORDER BY sales_year;

-- 5B. In 2011, how much faster is the average month in Sep-Nov than in Jan-Aug?
WITH m AS (
    SELECT MONTH(sale_date) AS mth, SUM(revenue) AS revenue
    FROM sales_clean
    WHERE YEAR(sale_date) = 2011 AND sale_date < '2011-12-01'
    GROUP BY MONTH(sale_date)
)
SELECT ROUND(AVG(CASE WHEN mth BETWEEN 9 AND 11 THEN revenue END)
           / AVG(CASE WHEN mth BETWEEN 1 AND 8  THEN revenue END), 2) AS peak_vs_normal_revenue_multiple
FROM m;

GO

-- 5C. Demand variability of each A-class product
--     CV (coefficient of variation) = standard deviation / average of monthly units.
--     Low CV = steady demand. High CV = spiky demand, needs a bigger safety stock.
--     Window: Jan 2010 to Nov 2011 (23 full months). Months with no sales count as 0.
CREATE OR ALTER VIEW v_demand_variability AS
WITH months AS (
    SELECT CAST('2010-01-01' AS DATE) AS month_start
    UNION ALL
    SELECT DATEADD(month, 1, month_start) FROM months WHERE month_start < '2011-11-01'
),
a AS (SELECT stock_code FROM v_product_abc WHERE abc_class = 'A'),
grid AS (SELECT a.stock_code, m.month_start FROM a CROSS JOIN months m),
u AS (
    SELECT stock_code,
           DATEFROMPARTS(YEAR(sale_date), MONTH(sale_date), 1) AS month_start,
           SUM(quantity) AS units
    FROM sales_clean
    WHERE sale_date >= '2010-01-01' AND sale_date < '2011-12-01'
    GROUP BY stock_code, DATEFROMPARTS(YEAR(sale_date), MONTH(sale_date), 1)
),
s AS (
    SELECT g.stock_code,
           AVG(1.0 * COALESCE(u.units, 0))  AS avg_monthly_units,
           STDEV(1.0 * COALESCE(u.units, 0)) AS sd_monthly_units
    FROM grid g
    LEFT JOIN u ON u.stock_code = g.stock_code AND u.month_start = g.month_start
    GROUP BY g.stock_code
)
SELECT stock_code, avg_monthly_units, sd_monthly_units,
       sd_monthly_units / NULLIF(avg_monthly_units, 0) AS cv,
       CASE WHEN sd_monthly_units / NULLIF(avg_monthly_units, 0) <= 0.5 THEN 'Stable'
            WHEN sd_monthly_units / NULLIF(avg_monthly_units, 0) <= 1.0 THEN 'Moderate'
            WHEN sd_monthly_units / NULLIF(avg_monthly_units, 0) >  1.0 THEN 'Volatile' END AS demand_pattern
FROM s;
GO

SELECT demand_pattern, COUNT(*) AS a_class_products
FROM v_demand_variability
WHERE demand_pattern IS NOT NULL
GROUP BY demand_pattern
ORDER BY CASE demand_pattern WHEN 'Stable' THEN 1 WHEN 'Moderate' THEN 2 ELSE 3 END;

GO

-- 5D. Peak-season uplift per A-class product (2011):
--     average monthly units in Sep-Nov  vs  average monthly units in Jan-Aug
CREATE OR ALTER VIEW v_peak_uplift AS
SELECT s.stock_code,
       SUM(CASE WHEN MONTH(s.sale_date) BETWEEN 1 AND 8  THEN s.quantity ELSE 0 END) / 8.0 AS base_avg_monthly_units,
       SUM(CASE WHEN MONTH(s.sale_date) BETWEEN 9 AND 11 THEN s.quantity ELSE 0 END) / 3.0 AS peak_avg_monthly_units,
       (SUM(CASE WHEN MONTH(s.sale_date) BETWEEN 9 AND 11 THEN s.quantity ELSE 0 END) / 3.0)
         / NULLIF(SUM(CASE WHEN MONTH(s.sale_date) BETWEEN 1 AND 8 THEN s.quantity ELSE 0 END) / 8.0, 0) AS uplift_multiple
FROM sales_clean s
JOIN v_product_abc p ON p.stock_code = s.stock_code AND p.abc_class = 'A'
WHERE s.sale_date >= '2011-01-01' AND s.sale_date < '2011-12-01'
GROUP BY s.stock_code;
GO

SELECT COUNT(*) AS a_class_with_base_sales,
       SUM(CASE WHEN uplift_multiple >= 1.5 THEN 1 ELSE 0 END) AS selling_1_5x_faster_in_peak
FROM v_peak_uplift
WHERE uplift_multiple IS NOT NULL;
