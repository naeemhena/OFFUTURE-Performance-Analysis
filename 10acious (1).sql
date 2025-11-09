GRANT
SELECT
	ON
	mystic_manuscript.master,
	mystic_manuscript.master_sales_date,
	mystic_manuscript.ten_worst_performers,
	mystic_manuscript.ten_best_performers,
	mystic_manuscript.profit_by_country,
	mystic_manuscript.discount_affects_profit,
	mystic_manuscript.subcategories_profits,
	mystic_manuscript.category_profits,
	mystic_manuscript.sale_by_segment,
	mystic_manuscript.sales_profits_by_qtr_year,
	mystic_manuscript.least_profitable_countries,
	mystic_manuscript.most_profitable_countries,
	mystic_manuscript.profit_by_country_qtr,
	mystic_manuscript.profit_percent_vs_sales
	 TO 
		de14_arth,
		da14_grst,
		da14_hena;


-- MASTER TABLE---------------------------------------
CREATE VIEW mystic_manuscript.master AS
SELECT
	o.order_id,
	o.ship_mode,
	o.customer_id,
	c.customer_name,
	c.segment,
	a.city,
	a.state,
	a.country,
	a.postal_code,
	o.market,
	o.region,
	p.product_id,
	p.category,
	p.sub_category,
	p.product_name,
	oi.sales,
	oi.quantity,
	oi.discount,
	oi.profit,
	oi.shipping_cost,
	o.order_priority,
	o.order_date,
	o.ship_date
FROM
	offuture.ORDER AS o
JOIN offuture.address AS a ON
	o.address_id = a.address_id
JOIN offuture.order_item AS oi ON
	oi.order_id = o.order_id
JOIN offuture.product AS p ON
	p.product_id = oi.product_id
JOIN (
	SELECT
		customer_id_long AS customer_id,
		customer_name,
		segment
	FROM
		offuture.customer
	WHERE
		customer_id_long IS NOT NULL
UNION
	SELECT
		customer_id_short AS customer_id,
		customer_name,
		segment
	FROM
		offuture.customer
	WHERE
		customer_id_short IS NOT NULL
) AS c ON
	o.customer_id = c.customer_id;

--SALES BY DATE MASTER TABLE-------------------------------------
CREATE VIEW mystic_manuscript.master_sales_date AS
SELECT
	order_id,
	product_id,
	order_date,
	ship_date,
	sales,
	quantity,
	discount,
	profit,
	shipping_cost,
	EXTRACT(YEAR FROM order_date) AS order_year,
	EXTRACT(MONTH FROM order_date) AS order_month,
	EXTRACT(QUARTER FROM order_date) AS order_quarter
FROM
	mystic_manuscript.master;

-- WORST PERFORMING PRODUCTS BY PROFIT-------------------------------
CREATE VIEW mystic_manuscript.ten_worst_performers AS
SELECT
	product_name,
	SUM(quantity) AS total_amount_sold,
	SUM(profit) AS total_profit,
	ROUND(SUM(profit)/ SUM(quantity), 2) AS total_profit_per_unit
FROM
	mystic_manuscript.master
GROUP BY
	product_name
ORDER BY
	(SUM(profit)/ SUM(quantity)) ASC
LIMIT
	10;

--BEST PERFORMING PRODUCTS BY PROFIT----------------------------------
CREATE VIEW mystic_manuscript.ten_best_performers AS
SELECT
	product_name,
	SUM(quantity) AS total_amount_sold,
	SUM(profit) AS total_profit,
	ROUND(SUM(profit)/ SUM(quantity), 2) AS total_profit_per_unit -- round for readability
FROM
	mystic_manuscript.master
GROUP BY
	product_name
ORDER BY
	(SUM(profit)/ SUM(quantity)) DESC
LIMIT
	10;

--PROFIT BY COUNTRY--------------------------------------------------
CREATE VIEW mystic_manuscript.profit_by_country AS
SELECT
	country,
	SUM(quantity) AS total_amount_sold,
	SUM(profit) AS total_profit
FROM
	mystic_manuscript.master
GROUP BY
	country
ORDER BY
	SUM(profit) DESC;

--DISCOUNT AFFECTS PROFITS------------------------------------------
CREATE VIEW mystic_manuscript.discount_affects_profit AS
SELECT
	discount,
	SUM(profit) AS profit,
	CASE --case to discard sales without discount, for sales with discount find out sale before discount
		WHEN discount > 0 
	THEN ROUND(SUM((sales /( 1 -discount)-sales + profit)), 2) --profit added with calculated profit from no discount, rounded for readability, 
		ELSE SUM(profit)
	END AS profit_without_discount
FROM
	mystic_manuscript.master
GROUP BY 
	discount
ORDER BY
	discount ASC;

--PROFITS BY SUBCATEGORIES----------------------------------------
CREATE VIEW mystic_manuscript.subcategories_profits AS
SELECT
	sub_category,
	SUM(quantity) AS total_amount_sold,
	SUM(profit) AS total_profit,
	ROUND(SUM(profit)/ SUM(quantity), 2) AS total_profit_per_unit --rounded for readability
FROM
	mystic_manuscript.master
GROUP BY
	sub_category
ORDER BY
	(SUM(profit)/ SUM(quantity)) DESC;
	
	--PROFITS BY CATEGORY-------------------------------------------
CREATE VIEW mystic_manuscript.category_profits AS
SELECT
	category,
	SUM(quantity) AS total_amount_sold,
	SUM(profit) AS total_profit,
	ROUND(SUM(profit)/ SUM(quantity), 2) AS total_profit_per_unit --rounded for readability
FROM
	mystic_manuscript.master
GROUP BY
	category
ORDER BY
	(SUM(profit)/ SUM(quantity)) DESC;
	
--SALES BY SEGMENT/COUNTRY ---------------------------------------
CREATE VIEW mystic_manuscript.sale_by_segment AS
SELECT 
	country,
	segment,   -- who are the customers. homeoffice, corporate, consumer
	SUM(sales) AS total_sales
FROM
	mystic_manuscript.master	
GROUP BY
	country,
	segment 
ORDER BY
	total_sales DESC;
	
	-- SALES, PROFITS, AND FREQUENCY OF DISCOUNTS BY QTR AND YEAR-
CREATE VIEW mystic_manuscript.sales_profits_by_qtr_year AS
SELECT
	order_year,
	order_quarter,
	SUM(sales) AS total_sales,
	SUM(profit) AS total_profit, 
	COUNT(discount) FILTER ( 
WHERE
	discount > 0) AS discounted_orders_count --how many discounts are they giving
FROM
	mystic_manuscript.master_sales_date
GROUP BY
	order_year,
	order_quarter
ORDER BY
	order_year,
	order_quarter;

-- FIND LEAST PROFITABLE COUNTRIES------------------------
CREATE VIEW mystic_manuscript.least_profitable_countries AS
SELECT
	country,
	total_amount_sold,
	total_profit
FROM
	mystic_manuscript.profit_by_country
ORDER BY
	total_profit ASC
LIMIT 3; -- limit to three due to high numbers of countries. also links to further query

-- FIND MOST PROFITABLE COUNTRIES-------------------------
CREATE VIEW mystic_manuscript.most_profitable_countries AS
SELECT
	country,
	total_amount_sold,
	total_profit
FROM
	mystic_manuscript.profit_by_country
ORDER BY
	total_profit DESC
LIMIT 3; -- limit to three due to high numbers of countries. also links to further query

-- TOTAL PROFIT BY COUNTRY PER QUARTER.TOP AND BOTTOM 3.------
CREATE VIEW mystic_manuscript.profit_by_country_qtr AS
SELECT
	country,
	DATE_TRUNC('quarter', order_date) AS order_quarter_date,
	SUM(profit) AS total_profit
FROM
	mystic_manuscript.master
WHERE
    country IN (
        SELECT country FROM mystic_manuscript.most_profitable_countries
        UNION
        SELECT country FROM mystic_manuscript.least_profitable_countries -- selecting top and bottom countries from list
    )
GROUP BY
	country,
	order_quarter_date
ORDER BY
	country,
	order_quarter_date;


--PERCENTAGE OF PROFIT VS SALES BY YEAR AND QTR
CREATE VIEW mystic_manuscript.profit_percent_vs_sales as
SELECT
	order_year,
	order_quarter,
	(SUM(profit) / NULLIF(SUM(sales), 0)) * 100 AS profit_margin_pct --to get profit percentage
FROM
	mystic_manuscript.master_sales_date
GROUP BY
	order_year,
	order_quarter
ORDER BY
	order_year,
	order_quarter;

-----CURIOSITY TABLES NO RELEVANT GRAPH BUT GOOD TALKING POINTS----

---how many discounts per sub catergory
SELECT
    COUNT(*)FILTER(
    WHERE discount>0) AS cat_discount_count,
    sub_category
FROM 
    mystic_manuscript.master
GROUP BY
    sub_category
ORDER BY
    cat_discount_count DESC;
-- Tables are the least discounted sub-category

-- Calculate average discount by sub-category
SELECT
    AVG(discount) AS cat_discount_avg,
    sub_category
FROM 
    mystic_manuscript.master
GROUP BY
    sub_category
ORDER BY
    cat_discount_avg DESC;
-- Tables receive the highest average discount ~30%

--TABLE PROFIT VS SALES
SELECT
	sum(profit) AS total_profit,-- £750k
	sum(sales) AS total_sales -- -£65k
FROM
	mystic_manuscript.master
WHERE sub_category = 'Tables'


SELECT DISTINCT(sub_category) FROM mystic_manuscript.master

