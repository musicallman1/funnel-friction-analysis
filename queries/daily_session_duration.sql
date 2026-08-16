-- ============================================
-- PA_1: Daily and Overall Purchase Duration
-- ============================================
-- Purpose: Calculates average time to purchase per day
--          and overall, measuring from a user's first
--          event of the day to their first purchase.
--
-- Output file: PA_1__Daily_and_Overall_Duration_.csv
-- Rows: 87 (85 daily rows + 1 overall summary row)
--
-- Key design decisions:
--   - first_event_cte groups by user + date only (no event_name)
--     to prevent fan-out from multiple event types per user per day
--   - time_to_purchase measured in minutes from first event
--     of the day to first purchase of the day
--   - Same-day constraint: fp.event_date = fe.event_date
--     excludes multi-day checkout journeys
--   - Date filter: through 2021-01-25 to align with
--     all other analysis files
--
-- Tableau usage: PA_1 data source — Dashboard 1
--   Daily rows feed the time series scatter chart
--   Overall row feeds the 68.97 min KPI tile
--
-- Analysis period: 2020-11-01 through 2021-01-25
-- Dataset: tc-da-1.turing_data_analytics.raw_events
-- ============================================
WITH correct_cols AS
(SELECT user_pseudo_id, event_name,
parse_date('%Y%m%d',event_date) AS event_date, 
TIMESTAMP_MICROS(event_timestamp) AS event_timestamp,
FROM `tc-da-1.turing_data_analytics.raw_events`), 

first_event_cte AS 
(SELECT cc.user_pseudo_id,
cc.event_date, 
MIN(cc.event_timestamp) AS first_event_time
FROM correct_cols cc 
GROUP BY cc.user_pseudo_id, cc.event_date), 

first_purchase_cte AS
(SELECT  cc.user_pseudo_id, 
cc.event_date, 
MIN(cc.event_timestamp) AS first_purchase_time
FROM correct_cols cc
WHERE cc.event_name = 'purchase' 
GROUP BY cc.user_pseudo_id, cc.event_date),

purchase_time AS 
(SELECT fp.user_pseudo_id, fe.event_date AS first_event_date, 
fp.event_date AS purchase_date, 
fe.first_event_time, fp.first_purchase_time, 
TIMESTAMP_DIFF(fp.first_purchase_time, fe.first_event_time, MINUTE) AS time_to_purchase 
FROM first_purchase_cte fp
JOIN first_event_cte fe 
ON fp.user_pseudo_id = fe.user_pseudo_id
WHERE fp.event_date = fe.event_date 
AND fp.event_date <= '2021-01-25' 
ORDER BY purchase_date), 

daily_results AS 
(SELECT ROUND(AVG(time_to_purchase),2) AS avg_minutes_to_purchase, 
purchase_date, COUNT(*) AS no_of_purchases
FROM purchase_time
GROUP BY purchase_date
ORDER BY purchase_date), 

overall_avg AS (
  SELECT 
    ROUND(AVG(avg_minutes_to_purchase), 2) AS overall_avg_minutes,
    SUM(no_of_purchases) AS total_purchases
  FROM daily_results
)

SELECT 
  purchase_date,
  avg_minutes_to_purchase,
  no_of_purchases,
  'Daily' AS result_type
FROM daily_results

UNION ALL

SELECT 
  NULL AS purchase_date,
  overall_avg_minutes,
  total_purchases,
  'Overall' AS result_type
FROM overall_avg
ORDER by purchase_date;
