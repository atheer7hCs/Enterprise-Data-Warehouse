
CREATE SCHEMA silver;

DROP TABLE IF EXISTS silver.customers;

CREATE TABLE silver.customers(
Customer_ID varchar(50),
Company_name varchar(50),
Industry varchar(50),
Segment varchar(50),
Region varchar(50),
"state" varchar(50),
Credit_Limit_USD int,
Payment_Terms varchar(50),
Account_Manager varchar(50),
Email varchar(100),
Acquisition_Date text,
Status varchar(50)
);


DROP TABLE IF EXISTS silver.employees;

CREATE TABLE silver.employees(
Employee_ID varchar(50),
First_name varchar(50),
Last_name varchar(50),
Email varchar(50),
Department varchar(50),
Title varchar(50),
Hire_Date text,
Manager_ID varchar(50) Null,
Office_Location varchar(50),
Employment_Status varchar(50)
);

Drop table if exists silver.products;

create table silver.products(
Prodect_ID varchar(50),
SKU varchar(50),
UPC varchar(50),
Product_Name varchar(50),
Category varchar(50),
Brand varchar(50),
Unit_Cost_USD float,
Unit_Price_USD float,
Supplier_ID varchar(50),
Stock_Status varchar(50),
warranty_moths int
);

DROP TABLE IF  EXISTS silver.suppliers;

create table silver.suppliers(
Suplier_ID varchar(50),
Suplier_Name varchar(50),
Category varchar(50),
City varchar(50),
Country varchar(50),
Lead_Time_Days int,
Payment_Terms varchar(50),
Supplier_Rating float,
Active_Status varchar(50)
);

DROP TABLE IF EXISTS silver.orders;

create table silver.orders(
Order_ID varchar(50),
Order_Date date ,
Customer_ID varchar(50) ,
Product_ID varchar(50) ,
Quantity varchar(50) ,
Unit_Price_USD float ,
Subtotal_USD float ,
Discount_Percent float ,
Discount_Amount_USD float ,
Tax_Amount_USD float ,
Total_Amount_USD float ,
Order_Status varchar(50) ,
Payment_Method varchar(50) ,
Sales_Employee_ID varchar(50) ,
Ship_Date varchar(50) NULL,
Delivery_Date varchar(50) NULL
);
