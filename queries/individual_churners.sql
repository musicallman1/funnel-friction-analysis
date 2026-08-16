-- ============================================
-- PA_5: Individual Checkout Churners
-- ============================================
-- Purpose: Creates a 5 event pre-churn sequence
--          leading up to the churn event for individual
--          users that met selected churn criteria. This
--          supported analysis of overall churn compared
--          to friction-driven churn defined in PA_9.
--
-- Output file: PA_5__Individual_Churners_from_Begin_Checkout_.csv
-- Rows: 2,506 (note: exceeds unique user count of 1,949
--        due to Payment Method and add_payment_info
--        firing simultaneously at identical timestamps
--        for the same users) - See README.md for full explanation.
--
-- Key design decisions:
--   - last_event CTE uses MAX(event_timestamp) per user
--     to identify final checkout event before churning
--   - LAG window (5 events) captures pre-churn sequence
--   - Excludes users who eventually purchased
--   - Filters out redundant or generic ('session_start','first_visit',
--    'user_engagement', 'scroll') events from pre-churn sequence 
--   - Relabels page_view events using page_title for specific
--     checkout pages ('Shopping Cart', 'Payment Method',
--     'Checkout Confirmation') to improve sequence accuracy
--
-- Tableau usage: PA_5 data source — Dashboard 4
--   Use COUNTD(user_pseudo_id) for user-level metrics
--   due to 557 users appearing twice (Payment Method and
--   add_payment_info firing at identical timestamps)
--
-- Analysis period: full dataset (no date filter —
--   abandoners not constrained to purchase window)
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
  SELECT user_pseudo_id, 
    event_date, event_timestamp,
    event_label AS churn_event,
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
  WHERE ie.churn_event IN ('begin_checkout', 
        'add_payment_info', 'Payment Method',
         'add_shipping_info')
  AND ie.user_pseudo_id NOT IN (
    SELECT user_pseudo_id
    FROM filtered_cols
    WHERE event_label = 'purchase')
 
)

SELECT * FROM abandoners
