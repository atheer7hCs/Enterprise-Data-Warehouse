-- =====================================================
-- Analysis queries on the Silver layer
-- Adjust column names if they differ in your tables
-- =====================================================

-- View primary keys, foreign keys, and unique constraints in the Silver schema
SELECT conrelid::regclass AS table_name,
       conname            AS constraint_name,
       CASE contype WHEN 'p' THEN 'PRIMARY KEY'
                    WHEN 'f' THEN 'FOREIGN KEY'
                    WHEN 'u' THEN 'UNIQUE' END AS type,
       pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE connamespace = 'silver'::regnamespace
  AND contype IN ('p','f','u')
ORDER BY conrelid::regclass::text, contype;


-- 1. Data quality: row counts bronze vs silver (how much did cleaning remove?)
SELECT 'customers' AS tbl, (SELECT COUNT(*) FROM bronze.customers) AS bronze_rows, (SELECT COUNT(*) FROM silver.customers) AS silver_rows
UNION ALL SELECT 'employees', (SELECT COUNT(*) FROM bronze.employees), (SELECT COUNT(*) FROM silver.employees)
UNION ALL SELECT 'products',  (SELECT COUNT(*) FROM bronze.products),  (SELECT COUNT(*) FROM silver.products)
UNION ALL SELECT 'suppliers', (SELECT COUNT(*) FROM bronze.suppliers), (SELECT COUNT(*) FROM silver.suppliers)
UNION ALL SELECT 'orders',    (SELECT COUNT(*) FROM bronze.orders),    (SELECT COUNT(*) FROM silver.orders);
  


-- 2. Monthly revenue and order count
SELECT DATE_TRUNC('month', Order_Date)::date AS month,
       COUNT(*)                              AS orders,
       ROUND(CAST(SUM(Total_Amount_USD) AS numeric), 2)       AS revenue_usd
FROM silver.orders
GROUP BY 1
ORDER BY 1;

-- 3. Month-over-month revenue growth
WITH monthly AS (
    SELECT DATE_TRUNC('month', order_date)::date AS month,
           CAST(SUM(Total_Amount_USD) AS numeric) AS revenue
    FROM silver.orders
    GROUP BY 1
)
SELECT month,
       ROUND(revenue, 2) AS revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
             / NULLIF(LAG(revenue) OVER (ORDER BY month), 0), 2) AS mom_growth_pct
FROM monthly
ORDER BY month;


-- 4. Top 10 customers by revenue
SELECT c.customer_id, c.company_name, c.segment,
       COUNT(o.order_id)                  AS orders,
       ROUND(CAST(SUM(o.total_amount_usd)AS numeric), 2)  AS revenue_usd
FROM silver.orders o
JOIN silver.customers c ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.company_name, c.segment
ORDER BY revenue_usd DESC
LIMIT 10;

-- 5. Revenue by region and segment
SELECT c.region, c.segment,
       ROUND(CAST(SUM(o.total_amount_usd)AS numeric), 2) AS revenue_usd
FROM silver.orders o
JOIN silver.customers c ON c.customer_id = o.customer_id
GROUP BY c.region, c.segment
ORDER BY revenue_usd DESC;

-- 6. Top 10 products by revenue
SELECT p.product_name, p.category, p.brand,
       SUM(o.quantity)                   AS units_sold,
       ROUND(CAST(SUM(o.total_amount_usd)AS numeric), 2) AS revenue_usd
FROM silver.orders o
JOIN silver.products p ON p.prodect_id = o.product_id
GROUP BY p.product_name, p.category, p.brand
ORDER BY revenue_usd DESC
LIMIT 10;

-- 7. Category performance with estimated gross profit
SELECT p.category,
       SUM(o.quantity) AS units_sold,
       ROUND(SUM(o.subtotal_usd), 2) AS gross_sales,
       ROUND(CAST(SUM(o.subtotal_usd - o.quantity * p.unit_cost_usd)AS numeric), 2) AS est_gross_profit
FROM silver.orders o
JOIN silver.products p ON p.prodect_id = o.product_id
GROUP BY p.category
ORDER BY est_gross_profit DESC;

-- 8. Sales rep leaderboard
SELECT e.first_name || ' ' || e.last_name AS sales_rep,
       e.department,
       COUNT(o.order_id)                 AS orders,
       ROUND(CAST(SUM(o.total_amount_usd)AS numeric), 2) AS revenue_usd,
       RANK() OVER (ORDER BY SUM(o.total_amount_usd) DESC) AS revenue_rank
FROM silver.orders o
JOIN silver.employees e ON e.employee_id = o.sales_employee_id
GROUP BY e.employee_id, e.first_name, e.last_name, e.department
ORDER BY revenue_rank;

-- 9. Order status distribution
SELECT order_status,
       COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM silver.orders
GROUP BY order_status
ORDER BY orders DESC;

-- 10. Average delivery time (days) by month
SELECT DATE_TRUNC('month', order_date)::date AS month,
       ROUND(AVG(delivery_date - ship_date), 1) AS avg_days_ship_to_delivery
FROM silver.orders
WHERE delivery_date IS NOT NULL AND ship_date IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- 11. Impact of discounts: discount bands vs average order value
SELECT CASE
           WHEN discount_percent = 0  THEN '0%'
           WHEN discount_percent <= 10 THEN '1-10%'
           WHEN discount_percent <= 20 THEN '11-20%'
           ELSE '20%+'
       END AS discount_band,
       COUNT(*) AS orders,
       ROUND(CAST(AVG(total_amount_usd)AS numeric), 2) AS avg_order_value
FROM silver.orders
GROUP BY 1
ORDER BY 1;

-- 12. Supplier performance: rating vs lead time
SELECT s.suplier_name, s.category, s.supplier_rating, s.lead_time_days,
       COUNT(p.prodect_id) AS products_supplied
FROM silver.suppliers s
LEFT JOIN silver.products p ON p.supplier_id = s.suplier_id
GROUP BY s.suplier_id, s.suplier_name, s.category, s.supplier_rating, s.lead_time_days
ORDER BY s.supplier_rating DESC;

-- 13. Customers by credit limit usage (total spend vs credit limit)
SELECT c.company_name, c.credit_limit_usd,
       ROUND(CAST(SUM(o.total_amount_usd)AS numeric), 2) AS total_spend,
       ROUND(CAST(100.0 * SUM(o.total_amount_usd) / NULLIF(c.credit_limit_usd, 0)AS numeric), 1) AS pct_of_limit
FROM silver.customers c
JOIN silver.orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.company_name, c.credit_limit_usd
ORDER BY pct_of_limit DESC
LIMIT 10;

-- 14. Data quality checks (all should return 0)
SELECT COUNT(*) AS orders_with_bad_dates FROM silver.orders WHERE delivery_date < ship_date;
SELECT COUNT(*) AS orders_with_zero_qty  FROM silver.orders WHERE quantity = 0;
SELECT COUNT(*) AS duplicate_orders FROM (SELECT order_id FROM silver.orders GROUP BY order_id HAVING COUNT(*) > 1) d;
