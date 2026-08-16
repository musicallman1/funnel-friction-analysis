-- ============================================
-- PA_8: Clean Path vs Overall Purchase Duration
-- ============================================
-- Purpose: Compares average time to purchase between
--          users who followed a linear checkout path
--          (clean path) and all purchasers overall.
--          Measures whether checkout friction meaningfully
--          slows purchase completion, reported daily and
--          as an overall summary average.
--          Outputs feed the headline KPI tiles and daily
--          scatter chart on Dashboard 1 
--
-- Output file: PA_8__avg_minutes_and_revenue__Overall_vs_Clean_path_.csv
-- Rows: 173 (daily rows for both result types +
--        2 summary rows: Overall Average, Clean Path Average)
--
-- Clean path definition:
--   Users who completed add_shipping_info, Payment Method,
--   and add_payment_info exactly once after begin_checkout.
--   Checkout Your Information excluded - see README.md section for explanation.
--   n=651 purchases within analysis window
--
-- Key design decisions:
--   - Post-checkout COUNTIF replaces earlier LAG window —
--     anchors to MIN(event_timestamp) of begin_checkout
--     per user per date, counts checkpoints within that
--     window only
--   - clean_path_users outputs user_pseudo_id AND event_date
--     ensuring clean path qualification is per session,
--     not per user lifetime — earlier version output
--     user_pseudo_id only causing cross-date matches
--    - fan-out prevention: first_event_cte groups by
--     user_pseudo_id and event_date only — event_name
--     and purchase_revenue_in_usd removed from GROUP BY
--   - purchase_revenue_in_usd isolated to dedicated
--     purchase_revenue_overall CTE, joined on both
--     user_pseudo_id AND event_date to prevent
--     cross-date revenue fan-out
--   - Same-day constraint (fp.event_date = fe.event_date)
--     and date filter match PA_1
--
--
-- Tableau usage: PA_8 data source — Dashboard 1
--   Clean Path Average row → 57.41 min KPI tile
--   Overall Average row → 68.97 min KPI tile
--   Daily rows → scatter chart with reference lines
--   at 57.41 (clean path) and 68.97 (overall)
--   result_type field used as color dimension
--
-- Analysis period: 2020-11-01 through 2021-01-25
-- Dataset: tc-da-1.turing_data_analytics.raw_events
-- ============================================
WITH correct_cols AS
(SELECT user_pseudo_id, event_name,browser, 
operating_system,purchase_revenue_in_usd,
page_title, parse_date('%Y%m%d',event_date) AS event_date, 
TIMESTAMP_MICROS(event_timestamp) AS event_timestamp,
FROM `tc-da-1.turing_data_analytics.raw_events`),

filtered_cols AS 
(SELECT user_pseudo_id,event_name,
event_date, event_timestamp, 
browser, operating_system, 
purchase_revenue_in_usd,
CASE WHEN event_name = 'page_view'AND
page_title IN ('Shopping Cart', 
   'Payment Method', 
    'Checkout Confirmation')
    THEN page_title
    ELSE event_name 
    END AS event_label
FROM correct_cols
WHERE event_name NOT IN 
('session_start','first_visit',
'user_engagement', 'scroll') AND 
(event_name != 'page_view'OR 
page_title IN ('Shopping Cart', 
   'Payment Method', 
    'Checkout Confirmation'))
),

checkout_start AS (
  SELECT
    user_pseudo_id,
    event_date,
    MIN(event_timestamp) AS checkout_time
  FROM filtered_cols
  WHERE event_label = 'begin_checkout'
  GROUP BY user_pseudo_id, event_date
),

post_checkout_events AS (
  SELECT
    fc.user_pseudo_id,
    fc.event_date,
    fc.event_label,
    fc.event_timestamp
  FROM filtered_cols fc
  JOIN checkout_start cs
    ON fc.user_pseudo_id = cs.user_pseudo_id
    AND fc.event_date = cs.event_date
  WHERE fc.event_timestamp >= cs.checkout_time
),


session_checkpoint_counts AS (
  SELECT
    user_pseudo_id,
    event_date,  -- proxy for session
    COUNTIF(event_label = 'add_shipping_info') AS add_shipping_count,
    COUNTIF(event_label = 'Payment Method') AS payment_page_count,
    COUNTIF(event_label = 'add_payment_info') AS payment_info_count
  FROM post_checkout_events
  GROUP BY user_pseudo_id, event_date
),

clean_path_users AS (
  SELECT DISTINCT scc.user_pseudo_id, scc.event_date
  FROM session_checkpoint_counts scc
  -- must have actually purchased on that date
  JOIN (SELECT DISTINCT user_pseudo_id, event_date 
        FROM filtered_cols 
        WHERE event_label = 'purchase') p
    ON scc.user_pseudo_id = p.user_pseudo_id
    AND scc.event_date = p.event_date
  WHERE scc.add_shipping_count = 1
    AND scc.payment_page_count = 1
    AND scc.payment_info_count = 1
),

first_event_cte_overall AS 
(SELECT cc.user_pseudo_id,
  cc.event_date,
  MIN(cc.event_timestamp) AS first_event_time
FROM correct_cols cc 
GROUP BY cc.user_pseudo_id, cc.event_date), 

first_purchase_cte_overall AS
(SELECT cc.user_pseudo_id, 
  cc.event_date, 
  MIN(cc.event_timestamp) AS first_purchase_time
FROM correct_cols cc
WHERE cc.event_name = 'purchase' 
GROUP BY cc.user_pseudo_id, cc.event_date),

first_event_cte_clean AS 
(SELECT cc.user_pseudo_id, 
  cc.event_date,
  MIN(cc.event_timestamp) AS first_event_time
FROM correct_cols cc
JOIN clean_path_users cpu
  ON cc.user_pseudo_id = cpu.user_pseudo_id
  AND cc.event_date = cpu.event_date
GROUP BY cc.user_pseudo_id, cc.event_date), 

first_purchase_cte_clean AS
(SELECT cc.user_pseudo_id, 
  cc.event_date, 
  MIN(cc.event_timestamp) AS first_purchase_time
FROM correct_cols cc
JOIN clean_path_users cpu
  ON cc.user_pseudo_id = cpu.user_pseudo_id
  AND cc.event_date = cpu.event_date
WHERE cc.event_name = 'purchase' 
GROUP BY cc.user_pseudo_id, cc.event_date),

purchase_revenue_overall AS (
SELECT user_pseudo_id,
  event_date,
  AVG(purchase_revenue_in_usd) AS purchase_revenue_in_usd
FROM correct_cols
WHERE event_name = 'purchase'
GROUP BY user_pseudo_id, event_date
),

purchase_time_overall AS 
(SELECT fp.user_pseudo_id, 
  fe.event_date AS first_event_date, 
  fp.event_date AS purchase_date, 
  fe.first_event_time, 
  fp.first_purchase_time, 
  TIMESTAMP_DIFF(fp.first_purchase_time, 
    fe.first_event_time, MINUTE) AS time_to_purchase,
    pr.purchase_revenue_in_usd 
FROM first_purchase_cte_overall fp
JOIN first_event_cte_overall fe 
  ON fp.user_pseudo_id = fe.user_pseudo_id
  AND fp.event_date = fe.event_date
JOIN purchase_revenue_overall pr
  ON fp.user_pseudo_id = pr.user_pseudo_id
  AND fp.event_date = pr.event_date 
WHERE fp.event_date <= '2021-01-25'
),

purchase_time_clean AS 
(SELECT fp.user_pseudo_id, 
  fe.event_date AS first_event_date, 
  fp.event_date AS purchase_date, 
  fe.first_event_time, 
  fp.first_purchase_time, 
  TIMESTAMP_DIFF(fp.first_purchase_time, 
    fe.first_event_time, MINUTE) AS time_to_purchase,
    pr.purchase_revenue_in_usd
FROM first_purchase_cte_clean fp
JOIN first_event_cte_clean fe 
  ON fp.user_pseudo_id = fe.user_pseudo_id
  AND fp.event_date = fe.event_date
JOIN purchase_revenue_overall pr
  ON fp.user_pseudo_id = pr.user_pseudo_id
  AND fp.event_date = pr.event_date 
WHERE fp.event_date <= '2021-01-25'
),

overall_daily AS (
  SELECT 
    purchase_date,
    ROUND(AVG(time_to_purchase), 2) AS avg_minutes_to_purchase,
    COUNT(*) AS no_of_purchases,
    ROUND(AVG(purchase_revenue_in_usd),2) AS overall_avg_revenue_purchase,
    'Overall' AS result_type
  FROM purchase_time_overall
  GROUP BY purchase_date
),

clean_daily AS (
  SELECT 
    purchase_date,
    ROUND(AVG(time_to_purchase), 2) AS avg_minutes_to_purchase,
    COUNT(*) AS no_of_purchases,
    ROUND(AVG(purchase_revenue_in_usd),2) AS clean_avg_revenue_purchase,
    'Clean Path' AS result_type
  FROM purchase_time_clean
  JOIN clean_path_users cpu
    ON purchase_time_clean.user_pseudo_id = cpu.user_pseudo_id
  GROUP BY purchase_date
),

overall_summary AS (
  SELECT
    CAST(NULL AS DATE) AS purchase_date,
    ROUND(AVG(avg_minutes_to_purchase), 2) AS avg_minutes_to_purchase,
    SUM(no_of_purchases) AS no_of_purchases,
    ROUND(AVG(overall_avg_revenue_purchase),2) AS overall_total_avg_rev,
    'Overall Average' AS result_type
  FROM overall_daily
),

clean_summary AS (
  SELECT
   CAST(NULL AS DATE) AS purchase_date,
    ROUND(AVG(avg_minutes_to_purchase), 2) AS avg_minutes_to_purchase,
    SUM(no_of_purchases) AS no_of_purchases,
    ROUND(AVG(clean_avg_revenue_purchase),2) AS overall_clean_avg_rev,
    'Clean Path Average' AS result_type
  FROM clean_daily
)

SELECT * FROM overall_daily
UNION ALL
SELECT * FROM clean_daily
UNION ALL
SELECT * FROM overall_summary
UNION ALL
SELECT * FROM clean_summary
ORDER BY purchase_date, result_type
