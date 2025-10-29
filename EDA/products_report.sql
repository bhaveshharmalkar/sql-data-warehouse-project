/*
=================================================================
Product Report
=================================================================
Purpose:
	- This report consolidates key customer metrics and behaviors	

Highlights:
	1. Gathers essential field such as product name, category, subcategory and cost details.
	2. Segment products by revenue to identify High-performers, Mid-range, Low-performers.
	3. Aggregates product level metrics:
		- total orders
		- total sales
		- total quantity sold
		- total customer_unique
		- lifespan (in months)
	4. Calculates valuable kpis:
		- recency (months since last order)
		- average order revenue
		- average monthly revenue
*/


-- Create report: gold.products_report

IF OBJECT_ID('gold.products_report', 'V') IS NOT NULL
	DROP VIEW gold.products_report;
GO

CREATE VIEW gold.products_report AS

-- 1. Base Query: Retrive core columns from tables

WITH base_query AS
(
SELECT
	fs.order_number,
	fs.customer_key,
	dp.product_key,
	fs.order_date,
	fs.sales_amount,
	fs.quantity,
	dp.product_name,
	dp.category,
	dp.subcategory,
	dp.product_cost,
	dp.product_line
FROM
	gold.fact_sales AS fs
LEFT JOIN
	gold.dim_products AS dp
ON
	fs.product_key = dp.product_key
WHERE order_date IS NOT NULL
),

-- 2. Product Aggregation: Summarize key metrics at product level
product_aggregation AS 
(
SELECT
	product_key,
	product_name,
	category,
	subcategory,
	product_cost,
	COUNT(DISTINCT order_number) AS total_orders,
	SUM(sales_amount) AS total_sales,
	SUM(quantity) AS total_quantity,
	COUNT(DISTINCT customer_key) AS total_customers,
	MAX(order_date) AS last_sale_date,
	DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan,
	ROUND(AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity, 0)), 2) AS avg_selling_price
FROM
	base_query
GROUP BY
	product_key,
	product_name,
	category,
	subcategory,
	product_cost
)

SELECT
	product_key,
	product_name,
	category,
	subcategory,
	CASE 
		WHEN total_sales > 50000 THEN 'High Performers'
		WHEN total_sales >= 10000 THEN 'Mid Performers'
		ELSE 'Low Performers'
	END AS product_segment,
	product_cost,
	total_orders,
	total_sales,
	total_quantity,
	total_customers,
	last_sale_date,
	lifespan,
	avg_selling_price,
	DATEDIFF(MONTH, last_sale_date, GETDATE()) AS recency,
	CASE 
		WHEN total_orders = 0 THEN 0
		ELSE total_sales / total_orders
	END AS avg_order_revenue,
	CASE 
		WHEN lifespan = 0 THEN total_sales
		ELSE total_sales / lifespan
	END AS avg_monthly_revenue
FROM
	product_aggregation