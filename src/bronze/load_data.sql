
DROP PROCEDURE IF EXISTS bronze.load_raw;

create or replace procedure bronze.load_raw()
LANGUAGE plpgsql
--بداية جسم الإجراء
AS $$
declare 
 start_time timestamp;
 end_time TIMESTAMP;
 batch_start_time TIMESTAMP;
 row_count INT;
 
BEGIN
-- Capture Start Time
    start_time := clock_timestamp();
RAISE NOTICE '========================================';
RAISE NOTICE '>> Loading Bronze Layer (Raw Data)';
RAISE NOTICE '========================================';
------------------------------------------------------------------
-- 1. LOAD CUSTOMERS
------------------------------------------------------------------
start_time := clock_timestamp();
RAISE NOTICE '[1/5] Loading bronze.customers';

TRUNCATE TABLE bronze.customers;

COPY bronze.customers
FROM 'C:\pg_data_sql\Enterprise-Data-Warehouse\Dataset\customers (1).csv'
DELIMITER ','
CSV HEADER;

GET DIAGNOSTICS row_count = ROW_COUNT;
end_time := clock_timestamp();

RAISE NOTICE '>> Loaded: % rows', row_count;
RAISE NOTICE '>> Duration: % seconds',

EXTRACT(EPOCH FROM (end_time - start_time));

    ------------------------------------------------------------------
    -- 2. LOAD EMPLOYEES
    ------------------------------------------------------------------
    start_time := clock_timestamp();
    RAISE NOTICE '[2/5] Loading bronze.employees';

    TRUNCATE TABLE bronze.employees;

    COPY bronze.employees
    FROM 'C:\pg_data_sql\Enterprise-Data-Warehouse\Dataset\employees.csv'
    DELIMITER ','
    CSV HEADER;

    GET DIAGNOSTICS row_count = ROW_COUNT;
    end_time := clock_timestamp();

    RAISE NOTICE '>> Loaded: % rows', row_count;
    RAISE NOTICE '>> Duration: % seconds',
        EXTRACT(EPOCH FROM (end_time - start_time));

    ------------------------------------------------------------------
    -- 3. LOAD PRODUCTS
    ------------------------------------------------------------------
    start_time := clock_timestamp();
    RAISE NOTICE '[3/5] Loading bronze.products';

    TRUNCATE TABLE bronze.products;

    COPY bronze.products
    FROM 'C:\pg_data_sql\Enterprise-Data-Warehouse\Dataset\products.csv'
    DELIMITER ','
    CSV HEADER;

    GET DIAGNOSTICS row_count = ROW_COUNT;
    end_time := clock_timestamp();

    RAISE NOTICE '>> Loaded: % rows', row_count;
    RAISE NOTICE '>> Duration: % seconds',
        EXTRACT(EPOCH FROM (end_time - start_time));

    ------------------------------------------------------------------
    -- 4. LOAD SUPPLIERS
    ------------------------------------------------------------------
    start_time := clock_timestamp();
    RAISE NOTICE '[4/5] Loading bronze.suppliers';

    TRUNCATE TABLE bronze.suppliers;

    COPY bronze.suppliers
    FROM 'C:\pg_data_sql\Enterprise-Data-Warehouse\Dataset\suppliers.csv'
    DELIMITER ','
    CSV HEADER;

    GET DIAGNOSTICS row_count = ROW_COUNT;
    end_time := clock_timestamp();

    RAISE NOTICE '>> Loaded: % rows', row_count;
    RAISE NOTICE '>> Duration: % seconds',
        EXTRACT(EPOCH FROM (end_time - start_time));

    ------------------------------------------------------------------
    -- 5. LOAD ORDERS
    ------------------------------------------------------------------
    start_time := clock_timestamp();
    RAISE NOTICE '[5/5] Loading bronze.orders';

    TRUNCATE TABLE bronze.orders;

    COPY bronze.orders
    FROM 'C:\pg_data_sql\Enterprise-Data-Warehouse\Dataset\orders.csv'
    DELIMITER ','
    CSV HEADER;

    GET DIAGNOSTICS row_count = ROW_COUNT;
    end_time := clock_timestamp();

    RAISE NOTICE '>> Loaded: % rows', row_count;
    RAISE NOTICE '>> Duration: % seconds',
        EXTRACT(EPOCH FROM (end_time - start_time));

    ------------------------------------------------------------------
    -- SUMMARY
    ------------------------------------------------------------------
    RAISE NOTICE '========================================';
    RAISE NOTICE '>> Bronze Layer Load Complete!';
    RAISE NOTICE '>> Total Duration: % seconds',
        EXTRACT(EPOCH FROM (clock_timestamp() - batch_start_time));
    RAISE NOTICE '========================================';

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '========================================';
        RAISE NOTICE '>> ERROR OCCURRED DURING LOADING!';
        RAISE NOTICE '>> Error Message: %', SQLERRM;
        RAISE NOTICE '>> Error Code: %', SQLSTATE;
        RAISE NOTICE '========================================';
END;
$$;

call bronze.load_raw();


select *
from bronze.customers;
