
-- =====================================================
-- CREATE OR REPLACE PROCEDURE for Silver Layer ETL
-- =====================================================
DROP PROCEDURE IF EXISTS silver.load_silver;

CREATE OR REPLACE PROCEDURE silver.load_silver()
LANGUAGE plpgsql
AS $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    batch_start_time TIMESTAMP;
    rows_processed INT;
BEGIN
    batch_start_time := clock_timestamp();

    RAISE NOTICE '========================================';
    RAISE NOTICE '>> Starting Silver Layer ETL Pipeline';
    RAISE NOTICE '========================================';

    -- =====================================================
    -- 1. LOAD CUSTOMERS
    -- =====================================================

 start_time := clock_timestamp();
    RAISE NOTICE '[1/5] Processing Customers';

    TRUNCATE TABLE silver.customers;
    insert into silver.customers (
        customer_id,
        company_name,
        industry,
        segment,
        region,
        state,
        credit_limit_usd,
        payment_terms,
        account_manager,
        email,
        acquisition_date,
        status
    )
SELECT
        customer_id,
        company_name,
        industry,
        segment,
        region,
        CASE state
            WHEN 'NY' THEN 'New York (NY)'
            WHEN 'CA' THEN 'California (CA)'
            WHEN 'TX' THEN 'Texas (TX)'
            WHEN 'IL' THEN 'Illinois (IL)'
            WHEN 'FL' THEN 'Florida (FL)'
            WHEN 'WA' THEN 'Washington (WA)'
            WHEN 'MA' THEN 'Massachusetts (MA)'
            WHEN 'PA' THEN 'Pennsylvania (PA)'
            WHEN 'GA' THEN 'Georgia (GA)'
            WHEN 'NC' THEN 'North Carolina (NC)'
            WHEN 'MI' THEN 'Michigan (MI)'
            WHEN 'OH' THEN 'Ohio (OH)'
            ELSE state
        END,
        credit_limit_usd,
        payment_terms,
        account_manager,
        email,
        acquisition_date,
        status
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY customer_id) AS rn
        FROM bronze.customers
    ) t
    WHERE rn = 1;

    GET DIAGNOSTICS rows_processed = ROW_COUNT;
    RAISE NOTICE 'Customers loaded: % rows', rows_processed;
    RAISE NOTICE 'Duration: % seconds',
        EXTRACT(EPOCH FROM clock_timestamp() - start_time);

	-- =====================================================
    -- 2. LOAD EMPLOYEES
    -- =====================================================
    start_time := clock_timestamp();
    RAISE NOTICE '[2/5] Processing Employees';

    TRUNCATE TABLE silver.employees;
	Insert into silver.employees(
        employee_id,
        first_name,
        last_name,
        email,
        department,
        title,
        hire_date,
        manager_id,
        office_location,
        employment_status
	)
	select 
	    employee_id,
        first_name,
        last_name,
        email,
        department,
        title,
        hire_date,
		Coalesce(manager_id,'no Manger'),
		office_location,
        employment_status
    FROM bronze.employees;
	
    GET DIAGNOSTICS rows_processed = ROW_COUNT;
    RAISE NOTICE 'Employees loaded: % rows', rows_processed;

    -- =====================================================
    -- 3. LOAD PRODUCTS
    -- =====================================================
    start_time := clock_timestamp();
    RAISE NOTICE '[3/5] Processing Products';

    TRUNCATE TABLE silver.products;	

	With avg_margin as (
    select 
	     category,
            brand,
			Round(AVG(unit_price_usd - unit_cost_usd)::numeric, 2)AS avg_margin
			FROM bronze.products
        WHERE unit_price_usd > unit_cost_usd
        GROUP BY category, brand
	)
	INSERT INTO silver.products (
        Prodect_ID,
        sku,
        upc,
        Product_Name,
        category,
        brand,
        Unit_Cost_USD,
        Unit_Price_USD,
        Supplier_ID,
        Stock_Status,
        warranty_moths
    )
	SELECT
        p.Prodect_ID,
        p.sku,
        p.upc,
        p.Product_Name,
        p.category,
        p.brand,
        p.Unit_Cost_USD,
		CASE
            WHEN p.Unit_Price_USD <= p.Unit_Price_USD THEN p.Unit_Price_USD + COALESCE(m.avg_margin, 0)
            ELSE p.Unit_Price_USD
        END,
        p.Supplier_ID,
        p.Stock_Status,
        p.warranty_moths
		FROM (
        SELECT *,
               ROW_NUMBER() OVER (PARTITION BY prodect_id ORDER BY prodect_id) AS rn
        FROM bronze.products
    ) p
	LEFT JOIN avg_margin m
        ON p.category = m.category
       AND p.brand = m.brand
    WHERE rn = 1;

	
    -- =====================================================
    -- 4. LOAD SUPPLIERS
    -- =====================================================
    start_time := clock_timestamp();
    RAISE NOTICE '[4/5] Processing Suppliers';

	with imputation as (
       select 
	      Avg(supplier_rating) AS avg_rating,
		  (
             select city 
			 from bronze.suppliers
			 group by city
			 order by count(*) DESC
			 limit 1
		  ) as mode_city
		  FROM bronze.suppliers
	)
 INSERT INTO silver.suppliers (
        Suplier_ID,
        Suplier_Name,
        Category,
        City,
        Lead_Time_Days,
        Payment_Terms,
        Supplier_Rating,
        Active_Status
    )
    SELECT
        s.Suplier_ID,
        s.Suplier_Name,
        s.Category,
        COALESCE(s.City, i.mode_city),
        s.Lead_Time_Days,
        s.Payment_Terms,
        COALESCE(s.Supplier_Rating, i.avg_rating),
        s.Active_Status
    FROM bronze.suppliers s
    CROSS JOIN imputation i;

 -- =====================================================
    -- 5. LOAD ORDERS
    -- =====================================================
    start_time := clock_timestamp();
    RAISE NOTICE '[5/5] Processing Orders';

    TRUNCATE TABLE silver.orders;

    INSERT INTO silver.orders (
        Order_ID,
        Order_Date,
        Customer_ID ,
        Product_ID,
        Quantity,
        Unit_Price_USD,
        Subtotal_USD,
        Discount_Percent,
        Discount_Amount_USD,
        Tax_Amount_USD,
        Total_Amount_USD,
        Order_Status,
        Payment_Method,
        Sales_Employee_ID,
        Ship_Date,
        Delivery_Date 
    )
    SELECT
        o.Order_ID,
        o.Order_Date,
        o.Customer_ID ,
        o.Product_ID,
        ABS(o.Quantity::numeric),
        o.Unit_Price_USD,
        ABS(o.Subtotal_USD::numeric),
        o.Discount_Percent,
        o.Discount_Amount_USD,
        o.Tax_Amount_USD,
        o.Total_Amount_USD,
        o.Order_Status,
        o.payment_method,
        o.Sales_Employee_ID,
        o.Ship_Date,
        CASE
            WHEN o.Delivery_Date < o.Ship_Date
            THEN o.Ship_Date + INTERVAL '5 days'
            ELSE o.Delivery_Date
        END
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (PARTITION BY Order_ID ORDER BY Order_Date DESC) AS rn
        FROM bronze.orders
    ) o
    WHERE rn = 1
      AND o.Order_Date BETWEEN DATE '2023-01-01' AND DATE '2023-12-28'
      AND o.Quantity <> 0
      AND o.Customer_ID IN (SELECT Customer_ID FROM silver.customers)
      AND o.Product_ID IN (SELECT Prodect_ID FROM silver.products)
      AND o.Sales_Employee_ID IN (SELECT Employee_ID FROM silver.employees);

    end_time := clock_timestamp();
    RAISE NOTICE '========================================';
    RAISE NOTICE '>> Silver Layer ETL Complete!';
    RAISE NOTICE 'Total Duration: % seconds',
        EXTRACT(EPOCH FROM end_time - batch_start_time);
    RAISE NOTICE '========================================';

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR OCCURRED: %', SQLERRM;
END;
$$;

call silver.load_silver();

ALTER TABLE bronze.customers
ALTER COLUMN Acquisition_Date TYPE DATE USING Acquisition_Date::date;

ALTER TABLE silver.orders
ALTER COLUMN Ship_Date TYPE DATE USING Ship_Date::date,
ALTER COLUMN Delivery_Date TYPE DATE USING Delivery_Date::date;

-- Add primary keys and foreign keys to enforce data integrity
ALTER TABLE silver.customers ADD PRIMARY KEY (customer_id);
ALTER TABLE silver.employees ADD PRIMARY KEY (employee_id);
ALTER TABLE silver.products  ADD PRIMARY KEY (prodect_id);
ALTER TABLE silver.suppliers ADD PRIMARY KEY (suplier_id);
ALTER TABLE silver.orders    ADD PRIMARY KEY (order_id);

ALTER TABLE silver.orders
  ADD FOREIGN KEY (customer_id)       REFERENCES silver.customers(customer_id),
  ADD FOREIGN KEY (product_id)        REFERENCES silver.products(prodect_id),
  ADD FOREIGN KEY (sales_employee_id) REFERENCES silver.employees(employee_id);

ALTER TABLE silver.products
  ADD FOREIGN KEY (supplier_id) REFERENCES silver.suppliers(suplier_id);

ALTER COLUMN Delivery_Date TYPE DATE USING Delivery_Date::date;


