-- Data Source: https://www.kaggle.com/datasets/kyanyoga/sample-sales-data

-- 1. Inspecting Data
SELECT * FROM `sales_data.sales`;

-- Inspecting  unique values
SELECT DISTINCT STATUS FROM `sales_data.sales`; --- 6 different status - would be nice to plot
SELECT DISTINCT YEAR_ID FROM `sales_data.sales`;  -- 3 years
SELECT DISTINCT PRODUCTLINE FROM `sales_data.sales`;  --would be nice to plot
SELECT DISTINCT COUNTRY FROM `sales_data.sales`; --- 9 unique countries
SELECT DISTINCT DEALSIZE FROM `sales_data.sales`; ---Nice to plot
SELECT DISTINCT TERRITORY FROM `sales_data.sales`;   ---Nice to plot , but change NA to full name North America

-- 2. Check the number of unique customers
SELECT
  COUNT(DISTINCT CUSTOMERNAME) AS distinct_customer_count
  , COUNT(CUSTOMERNAME) AS total_customer_count
FROM `sales_data.sales`;


-- 3. Data Cleaning
-- Change 'NA' in Territory to 'North America'
SELECT 
  * 
FROM `sales_data.sales`
WHERE Territory = 'NA';

SELECT DISTINCT
  CASE WHEN TERRITORY = 'NA' THEN 'North America' ELSE TERRITORY END AS TERRITORY
FROM `sales_data.sales`;



-- ANALYSIS STAGE: 
-- Revenue per Productline, 
SELECT
  PRODUCTLINE
  , SUM(sales) AS Revenue
FROM `sales_data.sales`
GROUP BY PRODUCTLINE
ORDER BY Revenue DESC; -- Clasic cars are giving us the most revenue


-- Revenue per Year, 
SELECT
  YEAR_ID
  , SUM(sales) AS Revenue
FROM `sales_data.sales`
GROUP BY YEAR_ID
ORDER BY Revenue DESC; -- 2004 has the highest revenue


-- Revenue per Dealsize 
SELECT
  DEALSIZE
  , SUM(sales) AS Revenue
FROM `sales_data.sales`
GROUP BY DEALSIZE
ORDER BY Revenue DESC;-- Medium deals are generating the most revenue


----What was the best month for sales in a specific year? How much was earned that month? 
-- For 2003
SELECT
  MONTH_ID
  , SUM(sales) AS Revenue
  , COUNT(ORDERNUMBER) AS Frequency
FROM  `sales_data.sales`
WHERE YEAR_ID = 2003
GROUP BY MONTH_ID
ORDER BY Revenue DESC;


-- For 2004
SELECT
  MONTH_ID
  , SUM(sales) AS Revenue
  , COUNT(ORDERNUMBER) AS Frequency
FROM `sales_data.sales`
WHERE YEAR_ID = 2004
GROUP BY MONTH_ID
ORDER BY Revenue DESC;
-- 11th (November) has the most revneue for both 2003 and 2004

-- For 2005
SELECT
  MONTH_ID
  , SUM(sales) AS Revenue
  , COUNT(ORDERNUMBER) AS Frequency
FROM `sales_data.sales`
WHERE YEAR_ID = 2005
GROUP BY MONTH_ID
ORDER BY Revenue DESC;

-- May has the highest revenue
-- Note: 2005 has only 5 months



-- Clearly, November seems to be the peak month.
-- Let's find what product in November drives sales
SELECT  
    MONTH_ID
    , PRODUCTLINE
    , SUM(sales) Revenue
    , COUNT(ORDERNUMBER) Total_Orders
FROM`sales_data.sales`
WHERE YEAR_ID = 2004 
   AND MONTH_ID = 11 --change year to see the rest
GROUP BY  MONTH_ID, PRODUCTLINE
ORDER BY 3 DESC;


--------------------------------------------------------------
-- RFM Mpodel (Recency, Frequency, and Monetary)
/*  - Recency: last order date
    - Frequency: count of total orders
    - Monetary Value: total spend
*/


DROP TABLE IF EXISTS sales_data.temp_rfm;
CREATE TABLE sales_data.temp_rfm AS #rfm

WITH rfm AS(
SELECT
    CUSTOMERNAME
    , SUM(sales) AS MonetaryValue
    , AVG(sales) AS AvgMonetaryValue
    , COUNT(ORDERNUMBER) AS Frequency
    , MAX(ORDERDATE) AS last_order_date
    , (SELECT MAX(ORDERDATE) FROM `sales_data.sales`) AS max_order_date
    , DATE_DIFF((SELECT MAX(ORDERDATE) FROM `sales_data.sales`), MAX(ORDERDATE),  DAY) AS Recency
FROM `sales_data.sales`
GROUP BY CUSTOMERNAME

  )

, rfm_calc AS (
  SELECT 
     r.*
     , NTILE(4) OVER(order by Recency desc) rfm_recency
     , NTILE(4) OVER(order by Frequency) rfm_frequency
     , NTILE(4) OVER(order by MonetaryValue) rfm_monetory    
  FROM rfm r

)

  SELECT 
    c.*, rfm_recency + rfm_frequency + rfm_monetory AS rfm_column
    , CAST(rfm_recency AS STRING) || CAST(rfm_frequency AS STRING) || CAST(rfm_monetory AS STRING) AS rfm_score   -- concatenating
FROM rfm_calc c;

SELECT
  CUSTOMERNAME,
  rfm_recency,
  rfm_frequency,
  rfm_monetory,
  rfm_score,
  CASE
    WHEN rfm_score  IN ('111', '112', '121', '122', '123', '132', '211', '212', '114', '141') THEN 'lost_customers'  --lost customers
    WHEN rfm_score  IN ('133', '134', '143', '144', '134', '143', '244', '124') THEN 'slipping_away_slowly' -- (Big spenders who haven’t purchased lately) slipping away
    WHEN rfm_score  IN ('311', '411', '331') THEN 'new_customers'--Transacted only once, but very recently and low spendings
    WHEN rfm_score  IN ('222', '223', '233', '242') THEN 'potential_churners'-- Transacted fairly recent, frequency and spending total
    WHEN rfm_score  IN ('323', '333', '321', '422', '332', '432') THEN 'active_customers' --Customers who buy often & recently, but at low price points
    WHEN rfm_score  IN ('433', '434', '443', '444') THEN 'loyal_customers'-- Best customers: transacted recently, do so often and spend more than other customers
  END AS rfm_segment
FROM sales_data.temp_rfm;


  SELECT * FROM `sales_data.temp_rfm`;
 ------------------------------------------------------------------------------------------------------------

------RFM Table formulated to be visualized with Tableau
-----------------------------------------------------------------------------------------------------------------------
---- Let us explore few more questions

---- What products are most often sold together? 
---- select * from [dbo].[sales_data_sample] where ORDERNUMBER =  10411
SELECT
    DISTINCT OrderNumber
    , STRING_AGG(PRODUCTCODE, ',') OVER (PARTITION BY OrderNumber) AS ProductCodes
FROM  `sales_data.sales` s
WHERE  s.OrderNumber IN (
        SELECT ORDERNUMBER
        FROM (
            SELECT
                ORDERNUMBER
                , COUNT(*) AS rn
            FROM `sales_data.sales`
            WHERE STATUS = 'Shipped'
            GROUP BY ORDERNUMBER
            ) WHERE rn = 3
         ) ORDER BY 2 DESC;

-------------------------------------------------------------------------------------------------------

---EXTRAs----
--What city has the highest number of sales in a specific country
select city, round(sum(sales), 2) Revenue
from `sales_data.sales`
where country = 'UK'
group by city
order by 2 desc;


------------------------------------------------------------------------------------------

---What is the best product in United States?
select country, YEAR_ID, PRODUCTLINE, round(sum(sales), 2) Revenue
from `sales_data.sales`
where country = 'USA'
group by  country, YEAR_ID, PRODUCTLINE
order by 4 desc;


SELECT * FROM `sales_data.temp_rfm`
