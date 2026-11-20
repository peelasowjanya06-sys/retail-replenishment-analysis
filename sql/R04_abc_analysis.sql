USE RetailAnalysis;
GO
-- Retail project | Step 4: ABC (Pareto) analysis
-- A = the products that together make the first 80% of revenue
-- B = the next 15% (up to 95%)       C = the last 5%
CREATE OR ALTER VIEW v_product_abc AS
WITH p AS (
    SELECT stock_code,
           MAX(LTRIM(RTRIM([description]))) AS [description],
           SUM(quantity)                    AS units,
           SUM(revenue)                     AS revenue
    FROM sales_clean
    GROUP BY stock_code
),
r AS (
    SELECT *,
           SUM(revenue) OVER ()                                              AS total_revenue,
           SUM(revenue) OVER (ORDER BY revenue DESC, stock_code
                              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cum_revenue
    FROM p
)
SELECT stock_code, [description], units,
       ROUND(revenue, 2)                                            AS revenue,
       ROW_NUMBER() OVER (ORDER BY revenue DESC, stock_code)        AS revenue_rank,
       ROUND(100.0 * cum_revenue / total_revenue, 2)                AS cumulative_revenue_pct,
       CASE WHEN cum_revenue - revenue < 0.80 * total_revenue THEN 'A'      -- revenue BEFORE this product is still under 80%
            WHEN cum_revenue - revenue < 0.95 * total_revenue THEN 'B'
            ELSE 'C' END                                            AS abc_class
FROM r;
GO

-- 4A. The key result: how few products make most of the money?
SELECT abc_class,
       COUNT(*)                                                    AS products,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)          AS pct_of_products,
       ROUND(SUM(revenue), 0)                                      AS revenue_gbp,
       ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 1)  AS pct_of_revenue
FROM v_product_abc
GROUP BY abc_class
ORDER BY abc_class;

-- 4B. Top 15 products
SELECT TOP 15 revenue_rank, stock_code, [description], units, revenue, cumulative_revenue_pct, abc_class
FROM v_product_abc
ORDER BY revenue_rank;
