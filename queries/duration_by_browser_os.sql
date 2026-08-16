-- ============================================
-- PA_2: Purchase Duration by Browser & OS
-- ============================================
-- Purpose: Extends PA_1 by segmenting average time to purchase
--          by browser and operating system. Focuses on Chrome
--          and Safari across desktop and mobile to identify
--          whether friction patterns differ by device/browser.
--
-- Output file: PA_2. (Daily, Overall by Browser, OS).csv
-- Rows: 397 (daily rows per segment + 6 overall summary rows,
--        one per browser/OS combination)
--
-- Segments covered:
--   Chrome: Macintosh, Windows, iOS, Android
--   Safari: Macintosh, iOS
--
-- Key design decisions:
--   - Follows PA_1 pattern: first_event_cte groups by
--     user + date only to prevent fan-out
--   - Browser and operating_system pulled from purchase side
--     of join (first_purchase_cte) using MAX() aggregation
--     to avoid fan-out from multi-browser sessions
--   - Browser/OS filter applied on both first_event_cte
--     and first_purchase_cte for consistency
--   - Same-day constraint and date filter match PA_1
-- 
---- Tableau usage: PA_2 data source — Dashboard 2
--   Overall rows feed the vertical bar chart with
--   Overall Avg: 68.97 min reference line
--
-- Analysis period: 2020-11-01 through 2021-01-25
-- Dataset: tc-da-1.turing_data_analytics.raw_events
-- ============================================
WITH correct_cols AS
(SELECT user_pseudo_id, event_name,
parse_date('%Y%m%d',event_date) AS event_date, 
browser, operating_system, 
TIMESTAMP_MICROS(event_timestamp) AS event_timestamp,
FROM `tc-da-1.turing_data_analytics.raw_events`), 

first_event_cte AS 
(SELECT cc.user_pseudo_id, 
cc.event_date, 
MIN(cc.event_timestamp) AS first_event_time 
FROM correct_cols cc 
WHERE browser IN ('Chrome','Safari')
AND operating_system IN ('Macintosh','Windows','iOS','Android')
GROUP BY cc.user_pseudo_id, cc.event_date), 

first_purchase_cte AS
(SELECT  cc.user_pseudo_id,
cc.event_date, 
MIN(cc.event_timestamp) AS first_purchase_time,
MAX(cc.browser) AS browser, 
MAX(cc.operating_system) AS operating_system
FROM correct_cols cc
WHERE cc.event_name = 'purchase' 
AND browser IN ('Chrome','Safari')
AND operating_system IN ('Macintosh','Windows','iOS','Android')
GROUP BY cc.user_pseudo_id, cc.event_date),

purchase_time AS 
(SELECT fp.user_pseudo_id, fe.event_date AS first_event_date, 
fp.event_date AS purchase_date, 
fe.first_event_time, fp.first_purchase_time, 
fp.browser, fp.operating_system, 
TIMESTAMP_DIFF(fp.first_purchase_time, fe.first_event_time, MINUTE) AS time_to_purchase 
FROM first_purchase_cte fp
JOIN first_event_cte fe 
ON fp.user_pseudo_id = fe.user_pseudo_id
WHERE fp.event_date = fe.event_date 
AND fp.event_date <= '2021-01-25'
ORDER BY purchase_date), 

daily_results AS 
(SELECT ROUND(AVG(time_to_purchase),2) AS avg_minutes_to_purchase, 
purchase_date, COUNT(*) AS no_of_purchases,
browser, operating_system
FROM purchase_time
GROUP BY purchase_date, browser, operating_system
ORDER BY purchase_date), 

overall_avg AS (
  SELECT 
    ROUND(AVG(avg_minutes_to_purchase), 2) AS overall_avg_minutes,
    SUM(no_of_purchases) AS total_purchases,
    browser, operating_system
  FROM daily_results
  GROUP BY browser, operating_system
)

SELECT 
  purchase_date,
  avg_minutes_to_purchase,
  no_of_purchases,
  browser, operating_system,
  'Daily' AS result_type
FROM daily_results

UNION ALL

SELECT 
  NULL AS purchase_date,
  overall_avg_minutes,
  total_purchases,
  browser, operating_system,
  'Overall' AS result_type
FROM overall_avg
ORDER by purchase_date;
