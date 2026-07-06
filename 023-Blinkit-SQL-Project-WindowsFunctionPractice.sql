/* 
"Mastering Window Functions is a critical step in becoming a data analyst. This project applies real-world healthcare 
data to practice ranking, moving averages, cumulative calculations, segmentation, and trend analysis using MySQL."
*/

USE blinkitdatabase;

-- 1. Rank customers based on their total spending.
SELECT 
	customer_id,
    SUM(order_total) AS totalSpending,
    RANK() OVER (ORDER BY SUM(order_total) DESC) AS rankingByTotalSpending
FROM blinkit_orders 
GROUP BY customer_id;

-- 2. Rank stores by total sales.
SELECT
	store_id,
	SUM(order_total) AS totalSales,
    DENSE_RANK() OVER (ORDER BY SUM(order_total) DESC) AS rankingByTotalSales
FROM blinkit_orders
GROUP BY store_id;

-- 3. Rank products by total revenue within each product category.
SELECT 
    bip.category,
    bip.product_name,
    SUM(total_price) AS totalRevenue,
    ROW_NUMBER() OVER (
		PARTITION BY bip.category
		ORDER BY SUM(total_price) DESC) AS rank_
FROM blinkitorderitems boi
JOIN blinkitproducts bip
	ON boi.product_id = bip.product_id
GROUP BY bip.category, bip.product_name;


-- 4. Calculate the cumulative sales for each customer over time.
WITH customerMonthlySpending AS (
	SELECT 
		YEAR(order_date) AS year_,
		MONTH(order_date) AS month_,
		bo.customer_id,
		bc.customer_name,
		SUM(order_total) AS totalSales
	FROM blinkit_orders bo
	JOIN blinkitcustomers bc
		ON bo.customer_id = bc.customer_id
	GROUP BY year_, month_,	bo.customer_id, bc.customer_name
)
SELECT
	year_,
    month_,
    customer_id,
    customer_name,
    totalSales,
    SUM(totalSales) OVER (PARTITION BY customer_id ORDER BY year_, month_) AS cumulativeSales
FROM customerMonthlySpending
ORDER BY customer_id, year_, month_;

-- 5. Calculate cumulative running store revenue
SELECT 
    YEAR(order_date) AS year_,
    MONTH(order_date) AS month_,
    store_id,
    SUM(order_total) AS totalRevenue,
    SUM(SUM(order_total)) OVER (
        PARTITION BY store_id
        ORDER BY YEAR(order_date), MONTH(order_date)
    ) AS cumulativeStoreRevenue
FROM blinkit_orders
GROUP BY store_id, YEAR(order_date), MONTH(order_date)
ORDER BY year_, month_, store_id;

-- 6. Compare every customer's current order amount with their previous order.
SELECT
    customer_id,
    order_id,
    order_date,
    order_total AS currentOrderAmount,
    LAG(order_total, 1, 0) OVER(
        PARTITION BY customer_id
        ORDER BY order_date
    ) AS previousOrderAmount
FROM blinkit_orders
ORDER BY customer_id, order_date;


-- 7.  Show the next purchase date for every customer.
SELECT
    customer_id,
    order_id,
    order_date AS currentPurchaseDate,
    LEAD(order_date) OVER (
        PARTITION BY customer_id
        ORDER BY order_date
    ) AS nextPurchaseDate,
    LEAD(order_date) OVER (
        PARTITION BY customer_id
        ORDER BY order_date
    ) - order_date AS daysUntilNextPurchase
FROM blinkit_orders
ORDER BY customer_id, order_date;


-- 8. Calculate a 7-day moving average of daily sales for each store
SELECT
	store_id,
    order_date,
    totalSales,
    ROUND(
		AVG(totalSales) OVER (
			PARTITION BY store_id
            ORDER BY order_date 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS MA_7Days
FROM (
	SELECT
		store_id,
		order_date,
		SUM(order_total) AS totalSales
	FROM blinkit_orders
	GROUP BY store_id, order_date) t
ORDER BY store_id, order_date;

-- 9. Divide store into four sales quartiles.
WITH storeTotalSales AS (
	SELECT
		store_id,
		SUM(order_total) AS totalSales
	FROM blinkit_orders
	GROUP BY store_id)
SELECT
	store_id,
    totalSales,
    CASE 
		WHEN NTILE(4) OVER ( ORDER BY totalSales) = 1
			THEN "Low Sales"
		WHEN NTILE(4) OVER ( ORDER BY totalSales) = 2
			THEN "Medium Sales"
		WHEN NTILE(4) OVER ( ORDER BY totalSales) = 3
			THEN "High Sales"
		ELSE "Very High Sales" END AS salesSummary
FROM storeTotalSales
GROUP BY store_id
ORDER BY totalSales DESC;


-- 10. Revenue Contribution to Store
WITH storeTotalSales AS (
    SELECT
        store_id,
        SUM(order_total) AS totalSales
    FROM blinkit_orders
    GROUP BY store_id
)
SELECT
    store_id,
    totalSales,
    SUM(totalSales) OVER () AS companyTotalSales,
    ROUND(
        (1.0 * totalSales / SUM(totalSales) OVER ()) * 100,
        2
    ) AS revenueContributionPercent
FROM storeTotalSales
ORDER BY revenueContributionPercent DESC;

-- 11. Show every customer's first purchase amount.
WITH rankedOrders AS (
    SELECT
        customer_id,
        order_id,
        order_date,
        order_total AS firstPurchaseAmount,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id 
            ORDER BY order_date ASC) AS rn
    FROM blinkit_orders
)
SELECT 
    customer_id,
    order_id,
    order_date,
    firstPurchaseAmount
FROM rankedOrders
WHERE rn = 1
ORDER BY customer_id;

-- 12. Show the latest order amount for every customer.
WITH rankedOrders AS (
    SELECT
        customer_id,
        order_id,
        order_date,
        order_total AS lastPurchaseAmount,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id 
            ORDER BY order_date DESC) AS rn
    FROM blinkit_orders
)
SELECT 
    customer_id,
    order_id,
    order_date,
    lastPurchaseAmount
FROM rankedOrders
WHERE rn = 1
ORDER BY customer_id;

-- 13. Identify the top 10% of customers based on spending.
WITH customerSpending AS (
    SELECT
        customer_id,
        SUM(order_total) AS totalSpending
    FROM blinkit_orders
    GROUP BY customer_id
),
customerPercent AS (
    SELECT
        customer_id,
        totalSpending,
        PERCENT_RANK() OVER (
            ORDER BY totalSpending DESC
        ) AS spendingPercentile
    FROM customerSpending
)
SELECT *
FROM customerPercent
WHERE spendingPercentile <= 0.10 
ORDER BY totalSpending DESC;

-- 14. Determine each marketing campaign's contribution to total marketing revenue.
WITH campaignRevenue AS (
    SELECT
        campaign_id,
        campaign_name,
        SUM(revenue_generated) AS totalCampaignRevenue
    FROM blinkitMarketingPerformance
    GROUP BY campaign_id, campaign_name
)
SELECT
    campaign_id,
    campaign_name,
    totalCampaignRevenue,
    SUM(totalCampaignRevenue) OVER() AS totalMarketingRevenue,
    ROUND(
        (totalCampaignRevenue /
        SUM(totalCampaignRevenue) OVER()) * 100,
        2
    ) AS contributionPercentage
FROM campaignRevenue
ORDER BY contributionPercentage DESC;


/* 
"Mastering Window Functions is a critical step in becoming a data analyst. This project applies real-world healthcare 
data to practice ranking, moving averages, cumulative calculations, segmentation, and trend analysis using MySQL."
*/

