-- ====================================
-- 1. Changes over time analysis
-- ====================================

-- Changes by year
SELECT 
	YEAR(order_date) AS order_year,
	SUM(sales_amount) AS total_Sales,
	SUM(quantity) AS total_quantity,
	COUNT(DISTINCT customer_key) AS total_customers
FROM
	gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY 
	YEAR(order_date)
ORDER BY 
	YEAR(order_date);

-- Changes by month
SELECT 
	MONTH(order_date) as order_month,
	SUM(sales_amount) as total_Sales,
	SUM(quantity) AS total_quantity,
	COUNT(DISTINCT customer_key) AS total_customers
FROM
	gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY 
	MONTH(order_date)
ORDER BY 
	MONTH(order_date);

-- Changes by year and month
SELECT 
	YEAR(order_date) as order_year,
	MONTH(order_date) as order_month,
	SUM(sales_amount) as total_Sales,
	SUM(quantity) AS total_quantity,
	COUNT(DISTINCT customer_key) AS total_customers
FROM
	gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY 
	YEAR(order_date),
	MONTH(order_date)
ORDER BY 
	YEAR(order_date),
	MONTH(order_date);

-- Using DATETRUNC function by year
SELECT 
	DATETRUNC(YEAR,order_date) as order_year,
	SUM(sales_amount) as total_Sales,
	SUM(quantity) AS total_quantity,
	COUNT(DISTINCT customer_key) AS total_customers
FROM
	gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY 
	DATETRUNC(YEAR,order_date)
ORDER BY 
	DATETRUNC(YEAR,order_date);

-- Using DATETRUNC function by month
SELECT 
	DATETRUNC(MONTH,order_date) as order_year,
	SUM(sales_amount) as total_Sales,
	SUM(quantity) AS total_quantity,
	COUNT(DISTINCT customer_key) AS total_customers
FROM
	gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY 
	DATETRUNC(MONTH,order_date)
ORDER BY 
	DATETRUNC(MONTH,order_date);

-- Using FORMAT function
SELECT 
	FORMAT(order_date, 'yyyy-MMM') as order_year,
	SUM(sales_amount) as total_Sales,
	SUM(quantity) AS total_quantity,
	COUNT(DISTINCT customer_key) AS total_customers
FROM
	gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY 
	FORMAT(order_date, 'yyyy-MMM')
ORDER BY 
	FORMAT(order_date, 'yyyy-MMM');


-- =====================================
-- 2. Cumulative Analysis
-- =====================================

-- Calculate total sales per month, running total and moving average of sales over time

-- By month
SELECT
	order_date,
	total_sales,
	SUM(total_sales) OVER (ORDER BY order_date) AS running_total_sales,
	SUM(avg_price) OVER (ORDER BY order_date) AS moving_average_price
FROM
(
SELECT
	DATETRUNC(MONTH,order_date) AS order_date,
	SUM(sales_amount) AS total_sales,
	AVG(price) AS avg_price
FROM
	gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH,order_date)
) AS sub

-- By year
SELECT
	order_date,
	total_sales,
	SUM(total_sales) OVER (ORDER BY order_date) AS running_total_sales,
	SUM(avg_price) OVER (ORDER BY order_date) AS moving_average_price
FROM
(
SELECT
	DATETRUNC(YEAR,order_date) AS order_date,
	SUM(sales_amount) as total_sales,
	AVG(price) AS avg_price
FROM
	gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(YEAR,order_date)
) AS sub


-- =======================================
-- 3. Performance Analysis
-- =======================================

-- Analyse the yearly performance of products by compairing their sales to both
-- the average sales performance of the product and the previous year's sales

WITH yearly_product_sales AS
(
SELECT
	YEAR(fs.order_date) AS order_year,
	dp.product_name,
	SUM(fs.sales_amount) AS current_sales
FROM
	gold.fact_sales AS fs
LEFT JOIN
	gold.dim_products AS dp
ON
	fs.product_key = dp.product_key
WHERE 
	fs.order_date IS NOT NULL
GROUP BY
	YEAR(fs.order_date),
	dp.product_name
) 

SELECT 
	order_year,
	product_name,
	current_sales,
	AVG(current_sales) OVER(PARTITION BY product_name) AS avg_sales,
	current_sales - AVG(current_sales) OVER(PARTITION BY product_name) AS diff_avg,
	CASE WHEN current_sales - AVG(current_sales) OVER(PARTITION BY product_name) > 0 THEN 'Above avg'
		WHEN current_sales - AVG(current_sales) OVER(PARTITION BY product_name) < 0 THEN 'Below avg'
		ELSE 'Avg'
	END AS cat,
	LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) AS prev_year,
	current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) AS diff_sales,
	CASE WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
		WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
		ELSE 'No Change'
	END AS cat
FROM
	yearly_product_sales
ORDER BY
	product_name,
	order_year


-- =======================================
-- 4. Part to whole analysis
-- =======================================

-- Which category contribute the most to overall sales?

WITH perc_sales AS 
(
SELECT
	category,
	SUM(sales_amount) AS total_sales,
	SUM(SUM(sales_amount)) OVER() AS overall_sales
FROM
	gold.fact_sales AS fs
LEFT JOIN
	gold.dim_products AS dp
ON
	fs.product_key = dp.product_key
GROUP BY
	category
)

SELECT
	category,
	total_sales,
	CONCAT(ROUND(CAST(total_sales AS FLOAT) / overall_sales * 100, 2), ' %') AS total_percentage
FROM
	perc_sales
ORDER BY total_sales DESC



-- ================================
-- 5. Data Segmentation
-- ================================

-- Segment products into cost ranges and count how many products fall into each segment

WITH count_prod AS 
(
SELECT
	product_name,
	product_cost,
	CASE 
		WHEN product_cost < 100 THEN 'Below 100'
		WHEN product_cost BETWEEN 100 AND 500 THEN '100-500'
		WHEN product_cost BETWEEN 500 AND 1000 THEN '500-1000'
		ELSE 'Above 1000'
	END cost_range
FROM
	gold.dim_products
)

SELECT
	cost_range,
	COUNT(product_name) AS total_products
FROM
	count_prod
GROUP BY 
	cost_range
ORDER BY
	total_products DESC


/*
Group customers into three segments based on theis spending behaviour
- VIP: Customer with at least 12 months of history and spending more than 5000 euro
- Regular: Customer with at least 12 months of history and spending less than 5000 or less than 5000 euro
- New: Customers with life span less than 12 months
And find total number of customers by each group
*/

WITH customer_spend AS
(
SELECT
	dc.customer_key,
	SUM(fs.sales_amount) AS total_sales,
	MIN(fs.order_date) AS first_order,
	MAX(fs.order_date) AS last_order,
	DATEDIFF(MONTH, MIN(fs.order_date), MAX(fs.order_date)) AS timespan
FROM
	gold.fact_sales AS fs
LEFT JOIN
	gold.dim_customers AS dc
ON
	fs.customer_key = dc.customer_key
GROUP BY
	dc.customer_key
)

SELECT
	customer_segment,
	COUNT(customer_key) AS total_customer
FROM

(
	SELECT
		customer_key,
		total_sales,
		timespan,
		CASE 
			WHEN timespan >= 12 AND total_sales > 5000 THEN 'VIP'
			WHEN timespan >= 12 AND total_sales <= 5000 THEN 'Regular'
			ELSE 'New'
		END AS customer_segment
	FROM
		customer_spend
) as sub
GROUP BY customer_segment