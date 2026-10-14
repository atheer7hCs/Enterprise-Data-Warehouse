	-- =============================================================================
-- DDL Script: Create Gold Date Dimension (gold.dim_date)
-- =============================================================================

DROP VIEW IF EXISTS gold.dim_date;

CREATE VIEW gold.dim_date AS
WITH 
    -- 1. Generate a small list of numbers (0-9)
    d0 AS (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 
           UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9),
    
    -- 2. Cross join them to generate more numbers (10*10*10*10 = 10,000 days)
    d4 AS (
        SELECT ROW_NUMBER() OVER () - 1 AS n
        FROM d0 t1, d0 t2, d0 t3, d0 t4
    ),

    -- 3. Calculate dates from the number list
    DateSeries AS (
        SELECT ('2023-01-01'::date + n * INTERVAL '1 day')::date AS full_date
        FROM d4
        WHERE ('2023-01-01'::date + n * INTERVAL '1 day') <= '2026-12-31'::date
    )

-- 4. Select final columns
SELECT
    TO_CHAR(full_date, 'YYYYMMDD')::INT AS date_key,
    full_date AS date,
    EXTRACT(YEAR FROM full_date)::INT AS year,
    EXTRACT(MONTH FROM full_date)::INT AS month,
    EXTRACT(DAY FROM full_date)::INT AS day,
    EXTRACT(QUARTER FROM full_date)::INT AS quarter,
    TO_CHAR(full_date, 'Month') AS month_name,
    TO_CHAR(full_date, 'Mon') AS month_short,
    TO_CHAR(full_date, 'Day') AS day_name,
    TO_CHAR(full_date, 'Dy') AS day_short,
    
    -- Fiscal Logic
    CASE 
        WHEN EXTRACT(MONTH FROM full_date) >= 4 THEN EXTRACT(YEAR FROM full_date)::INT + 1
        ELSE EXTRACT(YEAR FROM full_date)::INT
    END AS fiscal_year,
    
    CASE 
        WHEN EXTRACT(MONTH FROM full_date) >= 4 THEN EXTRACT(MONTH FROM full_date)::INT - 3
        ELSE EXTRACT(MONTH FROM full_date)::INT + 9
    END AS fiscal_month,
    
    -- Weekend Flag (Sunday=0, Saturday=6)
    CASE 
        WHEN EXTRACT(DOW FROM full_date) IN (0,6) THEN 1
        ELSE 0
    END AS is_weekend
FROM DateSeries;




SELECT
    c.region,
    SUM(f.total_amount) AS total_revenue,
    COUNT(DISTINCT f.order_id) AS total_orders
FROM gold.fact_orders f
JOIN gold.dim_customers c ON f.customer_id = c.customer_id
GROUP BY c.region
ORDER BY total_revenue DESC;

SELECT
    d.year,
    d.month_name,
    SUM(f.total_amount) AS monthly_revenue
FROM gold.fact_orders f
JOIN gold.dim_date d ON f.order_date = d.date
GROUP BY d.year, d.month, d.month_name
ORDER BY d.year, d.month;



SELECT
    e.employee_name,
    e.department,
    COUNT(f.order_id) AS total_orders,
    SUM(f.total_amount) AS total_revenue
FROM gold.fact_orders f
JOIN gold.dim_employees e ON f.employee_id = e.employee_id
GROUP BY e.employee_id, e.employee_name, e.department
ORDER BY total_revenue DESC;
