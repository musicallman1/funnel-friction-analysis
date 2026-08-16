-- ============================================
-- PA_9: Friction Segments and Revenue Impact
-- ============================================
-- Purpose: Quantifies the business impact of checkout
--          friction by comparing users who completed
--          purchase despite friction (Friction Completers)
--          against users who abandoned due to friction
--          (Friction Churners). Calculates revenue at risk
--          for each segment and captures behavioral metrics
--          including payment touches and checkout restarts.
--          Outputs feed the headline KPI tiles, revenue bars,
--          and payment behavior tiles on Dashboard 3.
--
-- Output file: PA_9__Frictioners_Segmentation_and_Revenue_.csv
-- Rows: 2 (one per segment:
--        Friction Completers, Friction Churners)
--
-- Segments:
--   Friction Completers: purchased despite friction
--     n=3,909 | revenue_at_risk=$260,105
--   Friction Churners: abandoned due to friction
--     n=1,133 | revenue_at_risk=$75,390
--   Total friction-affected revenue: $335,495
--
-- Key design decisions:
--   - Two independent pipelines share item_events CTE:
--     completer_clickstream → completer_friction → friction_completers
--     abandoner_clickstream → abandoner_friction → friction_churners
--     Earlier combined query applied completer logic to
--     abandoner data — splitting pipelines corrected this
--   - Completer friction filter: any checkout step > 1
--     in 5-event LAG window before purchase
--   - Churner friction filter: last_event matches checkout
--     step AND same step appears > 0 in prior 5 events
--   - Asymmetry between > 1 (completers) and > 0 (churners)
--     is intentional — completers' last event is purchase
--     (not a checkout step), so repetition must appear
--     twice within the window. Churners' last event IS
--     the checkout step, counting as one occurrence,
--     so > 0 in prior events confirms repetition.
--     See README.md 
--   - Revenue: affected_users * $66.54 AOV
--   - AOV source: aov_diagnostic.sql —
--     AVG(purchase_revenue_in_usd) across all purchase
--     rows through 2021-01-25. Verified against earlier
--     estimates of $65.72 and $65.43 (average of daily
--     averages — biased toward low-volume days)
--   - segment and revenue_label columns added to final
--     SELECT to enable dynamic Tableau KPI tile labeling
--     without calculated fields
--   - Checkout Your Information excluded from filtered_cols
--     consistent with PA_8 - See README.md 
--
-- Payment Method / add_payment_info note:
--   These events fire simultaneously at identical timestamps.
--   In the churner breakdown by last_event, the ~208 combined
--   payment-step churners are split arbitrarily between
--   Payment Method (107) and add_payment_info (101) rows
--   based on BigQuery timestamp tie-breaking — not a
--   meaningful behavioral distinction. 
--
-- Tableau usage: PA_9 data source — Dashboard 3
--   segment field → color dimension and KPI tile labels
--   revenue_label field → tooltip and annotation labels
--   revenue_at_risk → revenue bar chart and KPI tiles
--   affected_users → user count bar chart and KPI tiles
--   user_avg_payment_touches → payment behavior tiles
--   user_avg_begin_checkout → checkout restart tiles
--
-- Analysis period: 2020-11-01 through 2021-01-25
-- Dataset: tc-da-1.turing_data_analytics.raw_events
-- ============================================

WITH correct_cols AS
(SELECT user_pseudo_id, event_name,browser, operating_system,
page_title, parse_date('%Y%m%d',event_date) AS event_date, 
TIMESTAMP_MICROS(event_timestamp) AS event_timestamp,
FROM `tc-da-1.turing_data_analytics.raw_events`),

filtered_cols AS 
(SELECT user_pseudo_id,event_name,
event_date, event_timestamp,
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

item_events AS (
  SELECT user_pseudo_id, event_label,
    event_date, event_timestamp,
    LAG(event_label, 1) OVER (
      PARTITION BY user_pseudo_id 
      ORDER BY event_timestamp) AS one_event_before,
    LAG(event_label, 2) OVER (
      PARTITION BY user_pseudo_id 
      ORDER BY event_timestamp) AS two_events_before,
    LAG(event_label, 3) OVER (
      PARTITION BY user_pseudo_id 
      ORDER BY event_timestamp) AS three_events_before,
    LAG(event_label, 4) OVER (
      PARTITION BY user_pseudo_id 
      ORDER BY event_timestamp) AS four_events_before,
    LAG(event_label, 5) OVER (
      PARTITION BY user_pseudo_id 
      ORDER BY event_timestamp) AS five_events_before
  FROM filtered_cols
),

-- =====================
-- COMPLETER SIDE
-- =====================

completer_clickstream AS (
SELECT
  event_label AS current_event,
  one_event_before, two_events_before,
  three_events_before, four_events_before,
  five_events_before,
  COUNT(*) AS sequences,
  COUNT(DISTINCT user_pseudo_id) AS users
FROM item_events
WHERE event_label = 'purchase'
GROUP BY current_event,
  one_event_before, two_events_before,
  three_events_before, four_events_before,
  five_events_before
),

completer_friction AS (
SELECT *,
  (CASE WHEN one_event_before = 'Payment Method' THEN 1 ELSE 0 END +
   CASE WHEN two_events_before = 'Payment Method' THEN 1 ELSE 0 END +
   CASE WHEN three_events_before = 'Payment Method' THEN 1 ELSE 0 END +
   CASE WHEN four_events_before = 'Payment Method' THEN 1 ELSE 0 END +
   CASE WHEN five_events_before = 'Payment Method' THEN 1 ELSE 0 END)
   AS pay_meth_count,

  (CASE WHEN one_event_before = 'add_payment_info' THEN 1 ELSE 0 END +
   CASE WHEN two_events_before = 'add_payment_info' THEN 1 ELSE 0 END +
   CASE WHEN three_events_before = 'add_payment_info' THEN 1 ELSE 0 END +
   CASE WHEN four_events_before = 'add_payment_info' THEN 1 ELSE 0 END +
   CASE WHEN five_events_before = 'add_payment_info' THEN 1 ELSE 0 END)
   AS add_pay_count,

  (CASE WHEN one_event_before = 'begin_checkout' THEN 1 ELSE 0 END +
   CASE WHEN two_events_before = 'begin_checkout' THEN 1 ELSE 0 END +
   CASE WHEN three_events_before = 'begin_checkout' THEN 1 ELSE 0 END +
   CASE WHEN four_events_before = 'begin_checkout' THEN 1 ELSE 0 END +
   CASE WHEN five_events_before = 'begin_checkout' THEN 1 ELSE 0 END)
   AS begin_checkout_count,

  (CASE WHEN one_event_before = 'add_shipping_info' THEN 1 ELSE 0 END +
   CASE WHEN two_events_before = 'add_shipping_info' THEN 1 ELSE 0 END +
   CASE WHEN three_events_before = 'add_shipping_info' THEN 1 ELSE 0 END +
   CASE WHEN four_events_before = 'add_shipping_info' THEN 1 ELSE 0 END +
   CASE WHEN five_events_before = 'add_shipping_info' THEN 1 ELSE 0 END)
   AS shipping_count


FROM completer_clickstream
WHERE current_event = 'purchase'
),

-- =====================
-- ABANDONER SIDE
-- =====================

last_event AS (
SELECT user_pseudo_id,
  MAX(event_timestamp) AS last_event_timestamp
FROM filtered_cols
GROUP BY user_pseudo_id
),

abandoners AS (
SELECT ie.*
FROM item_events ie
JOIN last_event le
  ON ie.user_pseudo_id = le.user_pseudo_id
  AND ie.event_timestamp = le.last_event_timestamp
WHERE ie.event_label IN ('begin_checkout',
      'add_payment_info', 'Payment Method',
      'add_shipping_info')
AND ie.user_pseudo_id NOT IN (
  SELECT user_pseudo_id
  FROM filtered_cols
  WHERE event_label = 'purchase')
),

abandoner_clickstream AS (
SELECT
  event_label AS last_event,
  one_event_before, two_events_before,
  three_events_before, four_events_before,
  five_events_before,
  COUNT(*) AS sequences,
  COUNT(DISTINCT user_pseudo_id) AS users
FROM abandoners
GROUP BY last_event,
  one_event_before, two_events_before,
  three_events_before, four_events_before,
  five_events_before
),

abandoner_friction AS (
SELECT *,
  (CASE WHEN one_event_before = 'Payment Method' THEN 1 ELSE 0 END +
   CASE WHEN two_events_before = 'Payment Method' THEN 1 ELSE 0 END +
   CASE WHEN three_events_before = 'Payment Method' THEN 1 ELSE 0 END +
   CASE WHEN four_events_before = 'Payment Method' THEN 1 ELSE 0 END +
   CASE WHEN five_events_before = 'Payment Method' THEN 1 ELSE 0 END)
   AS pay_meth_count,

  (CASE WHEN one_event_before = 'add_payment_info' THEN 1 ELSE 0 END +
   CASE WHEN two_events_before = 'add_payment_info' THEN 1 ELSE 0 END +
   CASE WHEN three_events_before = 'add_payment_info' THEN 1 ELSE 0 END +
   CASE WHEN four_events_before = 'add_payment_info' THEN 1 ELSE 0 END +
   CASE WHEN five_events_before = 'add_payment_info' THEN 1 ELSE 0 END)
   AS add_pay_count,

  (CASE WHEN one_event_before = 'begin_checkout' THEN 1 ELSE 0 END +
   CASE WHEN two_events_before = 'begin_checkout' THEN 1 ELSE 0 END +
   CASE WHEN three_events_before = 'begin_checkout' THEN 1 ELSE 0 END +
   CASE WHEN four_events_before = 'begin_checkout' THEN 1 ELSE 0 END +
   CASE WHEN five_events_before = 'begin_checkout' THEN 1 ELSE 0 END)
   AS begin_checkout_count,

  (CASE WHEN one_event_before = 'add_shipping_info' THEN 1 ELSE 0 END +
   CASE WHEN two_events_before = 'add_shipping_info' THEN 1 ELSE 0 END +
   CASE WHEN three_events_before = 'add_shipping_info' THEN 1 ELSE 0 END +
   CASE WHEN four_events_before = 'add_shipping_info' THEN 1 ELSE 0 END +
   CASE WHEN five_events_before = 'add_shipping_info' THEN 1 ELSE 0 END)
   AS shipping_count

FROM abandoner_clickstream
),

-- =====================
-- FINAL AGGREGATIONS
-- =====================

friction_churners AS (
SELECT
  'Friction Churners' AS segment,
  'Lost Revenue' AS revenue_label,
  COUNT(*) AS sequences,
  SUM(users) AS affected_users,
  ROUND(SUM(users) * 66.54, 2) AS revenue_at_risk,
  AVG(begin_checkout_count) AS avg_begin_checkout,
  ROUND(SUM(begin_checkout_count * users) / SUM(users), 2) AS user_avg_begin_checkout,
  MAX(begin_checkout_count) AS max_begin_checkout,
  AVG(pay_meth_count + add_pay_count) AS avg_payment_touches,
  ROUND(SUM((pay_meth_count + add_pay_count) * users) / SUM(users), 2) AS user_avg_payment_touches,
  MAX(pay_meth_count + add_pay_count) AS max_payment_touches
FROM abandoner_friction
WHERE (last_event = 'Payment Method' AND pay_meth_count > 0)
  OR (last_event = 'add_payment_info' AND add_pay_count > 0)
  OR (last_event = 'begin_checkout' AND begin_checkout_count > 0)
  OR (last_event = 'add_shipping_info' AND shipping_count > 0)
),

friction_completers AS (
SELECT
  'Friction Completers' AS segment,
  'At-Risk Revenue Retained' AS revenue_label,
  COUNT(*) AS sequences,
  SUM(users) AS affected_users,
  ROUND(SUM(users) * 66.54, 2) AS revenue_at_risk,
  AVG(begin_checkout_count) AS avg_begin_checkout,
  ROUND(SUM(begin_checkout_count * users) / SUM(users), 2) AS user_avg_begin_checkout,
  MAX(begin_checkout_count) AS max_begin_checkout,
  AVG(pay_meth_count + add_pay_count) AS avg_payment_touches,
  ROUND(SUM((pay_meth_count + add_pay_count) * users) / SUM(users), 2) AS user_avg_payment_touches,
  MAX(pay_meth_count + add_pay_count) AS max_payment_touches
FROM completer_friction
WHERE pay_meth_count > 1 OR add_pay_count > 1
  OR begin_checkout_count > 1 OR shipping_count > 1
)

SELECT * FROM friction_churners
UNION ALL
SELECT * FROM friction_completers
