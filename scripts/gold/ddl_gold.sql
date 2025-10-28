/*
===========================================================================
DDL Script : Create Gold Views
===========================================================================

Script purpose:
	This script create views for gold layer
	The gold layer represent the dimention and fact tables i.e start schema.

	Each view performs transformation and combines data from silver layer to producs a clean, 
	enriched and business ready dataset.

Usage:
	This views can be query directly.
*/

-- =============================================
-- Create dimention : gold.dim_customers
-- =============================================

IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
	DROP VIEW gold.dim_customers;
GO

CREATE VIEW gold.dim_customers AS
SELECT
	ROW_NUMBER() OVER (ORDER BY cst_id) AS customer_key,
	ci.cst_id AS customer_id,
	ci.cst_key as customer_number,
	ci.cst_firstname AS first_name,
	ci.cst_lastname AS last_name,
	ci.cst_marital_status AS marital_status,
	-- lo.cntry AS country,
	CASE WHEN lo.cntry IS NULL THEN 'n/a'
	ELSE lo.cntry
	END AS country,
	CASE WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr
	ELSE COALESCE(ca.gen, 'n/a')
	END AS gender,
	ca.bdate AS birth_date,
	ci.cst_create_date AS create_date
FROM
	silver.crm_cust_info as ci
LEFT JOIN 
	silver.erp_cust_az12 as ca
ON ci.cst_key = ca.cid
LEFT JOIN
	silver.erp_loc_a101 as lo
ON ca.cid = lo.cid;


-- =============================================
-- Create dimention : gold.dim_products
-- =============================================

IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
	DROP VIEW gold.dim_products;
GO

CREATE VIEW gold.dim_products AS
SELECT 
	ROW_NUMBER() OVER (ORDER BY prod.prd_start_dt, prod.prd_key) AS product_key,
	prod.prd_id AS product_id,
	prod.prd_key AS product_number,
	prod.prd_nm AS product_name,
	prod.cat_id AS category_id,
	cat.cat AS category,
	cat.subcat AS subcategory,
	cat.maintenance,
	prod.prd_cost AS product_cost,
	prod.prd_line AS product_line,
	prod.prd_start_dt AS start_date
FROM
	silver.crm_prd_info AS prod
LEFT JOIN
	silver.erp_px_cat_g1v2 AS cat
	ON
		prod.cat_id = cat.id
WHERE 
	prod.prd_end_dt IS NULL	-- Filter out historical data;


-- =============================================
-- Create Fact : gold.fact_sales
-- =============================================

IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
	DROP VIEW gold.fact_sales;
GO

CREATE VIEW gold.fact_sales AS
SELECT 
	sd.sls_ord_num AS order_number,
	dm.product_key,
	dc.customer_key,
	sd.sls_order_dt AS order_date,
	sd.sls_ship_dt AS shipping_date,
	sd.sls_due_dt AS due_date,
	sd.sls_sales AS sales_amount,
	sd.sls_quantity AS quantity,
	sd.sls_price AS price
FROM
	silver.crm_sales_details AS sd
LEFT JOIN
	gold.dim_products AS dm
ON
	sd.sls_prd_key = dm.product_number
LEFT JOIN
	gold.dim_customers AS dc
ON
	sd.sls_cust_id = dc.customer_id;