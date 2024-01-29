-- CHALLENGE A

-- Task 1

-- Create a temp table for daily snapshots
CREATE TABLE tmp_listings AS
SELECT 
    *,
    CURRENT_DATE AS snapshot_date
FROM cln_listings;

-- Update fact table
UPDATE fct_listings fl
SET
    valid_to = (SELECT snapshot_date 
                FROM tmp_listings tl 
                WHERE tl.listing_id = fl.listing_id)
WHERE valid_to IS NULL;

-- Insert new records into the fact table
INSERT INTO fct_listings (listing_id, price, valid_from, valid_to, listing_date_key, platform_id, product_type_id, status_id, user_id)
SELECT
    tl.listing_id,
    tl.price,
    tl.snapshot_date,
    NULL,
    tl.listing_date_key,
    tl.platform_id,
    tl.product_type_id,
    tl.status_id,
    tl.user_id
FROM tmp_listings tl

-- Drop temp table
DROP TABLE tmp_listings;





-- Task 2

-- create CTE with cleaned-up/mapped data
WITH report AS (
    SELECT 
        l.listing_id,
        l.price,
        l.listing_date_key,
        p.platform
    FROM fct_listings l
    JOIN dim_platform p ON p.platform_id = l.platform_id AND p.valid_from <= l.listing_date_key AND (p.valid_to >= l.listing_date_key OR p.valid_to IS NULL)
    WHERE l.listing_date_key >= '2021-12-01' AND l.listing_date_key <= '2022-01-31'
)

SELECT
    listing_date_key as calendar_date,
    platform,
    COUNT(*) AS total_listings,
    AVG(price) AS average_price,
    SUM(price) AS total_amount
FROM report
GROUP BY listing_date_key, platform
ORDER BY listing_date_key, platform;



-- CHALLENGE B

-- Task 1


-- using same CTE but extended from previous task
WITH reportCTE AS (
    SELECT 
        l.listing_id,
        l.price,
        l.listing_date_key,
  		pt.product_type,
        d.quarter,
        p.platform,
        u.user_id,
        u.location.city as city
    FROM fct_listings l
    JOIN dim_platform p ON p.platform_id = l.platform_id AND p.valid_from <= l.listing_date_key AND (p.valid_to >= l.listing_date_key OR p.valid_to IS NULL)
    JOIN dim_product_type pt ON pt.product_type_id = l.product_type_id AND pt.valid_from <= l.listing_date_key AND (pt.valid_to >= l.listing_date_key OR pt.valid_to IS NULL)
    JOIN dim_user u ON u.user_id = l.user_id AND u.valid_from <= l.listing_date_key AND (u.valid_to >= l.listing_date_key OR u.valid_to IS NULL)
    JOIN dim_date d ON d.date_key = l.listing_date_key
    WHERE l.listing_date_key >= '2021-12-01' AND l.listing_date_key <= '2022-01-31'
)

-- a) The top 3 selling product types by platform.
SELECT
    platform,
    product_type,
    COUNT(*) AS total
FROM
    reportCTE
GROUP BY platform, product_type
ORDER BY platform, total DESC
LIMIT 3;


-- b) The bottom 3 selling product types by platform.
SELECT
    platform,
    product_type,
    COUNT(*) AS total
FROM
    reportCTE
GROUP BY platform, product_type
ORDER BY platform, total ASC
LIMIT 3;

-- c) The top 3 idle product types (amount of days).
WITH idleCTE AS (
    SELECT
        product_type,
        MAX(listing_date_key) AS listing_date_key,
        DATEDIFF(CURRENT_DATE, MAX(listing_date_key)) AS days_idle
    FROM
        reportCTE
    GROUP BY
        product_type
)

SELECT
    product_type,
    days_idle
FROM
    idleCTE
ORDER BY days_idle DESC
LIMIT 3;


-- d) The total amount sold by product type (monetary value rounded to two decimals).
SELECT
    product_type,
    ROUND(SUM(price), 2) AS total_amount_sold
FROM reportCTE
GROUP BY product_type
ORDER BY total_amount_sold DESC;

-- e) Any other insights you could learn from the data that would be useful for the company to know.

-- Quarterly sales more than 10
SELECT
        r.product_type,
        d.quarter,
        COUNT(*) AS total_quantity_sold
FROM reportCTE r
LEFT JOIN dim_date d ON r.listing_date_key = d.date_key
GROUP BY r.product_type, d.quarter
HAVING COUNT(*) > 10
ORDER BY total_quantity_sold DESC


-- Sales by city
SELECT
    r.product_type,
    r.city,
    COUNT(*) AS total_quantity_sold
FROM reportCTE r
GROUP BY r.product_type, r.city


-- CHALLENGE C

-- Task 1

WITH blackListing AS (
  SELECT
    u.location.country,
    COUNT(listing_id) AS num_listings
  FROM
    fct_listings f
 	INNER JOIN dim_product_type pt ON pt.product_type_id = f.product_type_id AND pt.product_type_tags.color = 'black'
  LEFT JOIN dim_user u ON u.user_id = f.user_id
  GROUP BY country
)

SELECT
  country,
  num_listings
FROM
  blackListing
ORDER BY
  num_listings DESC
LIMIT 3;