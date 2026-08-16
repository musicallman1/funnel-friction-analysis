-- ============================================
-- PA_3: Funnel Counts by Browser & OS
-- ============================================
-- Purpose: Counts the number of users who reached each
--          checkout funnel step, segmented by browser
--          and operating system. Provides the raw user
--          counts that support funnel drop-off analysis
--          across browser/operating system combinations.
--
-- Output file: PA_3__(Browser,_OS_Funnel_Counts).csv
-- Rows: 6 (one per browser/OS combination)
--
-- Funnel steps counted:
--   first_visit → add_to_cart → begin_checkout →
--   add_shipping_info → add_payment_info → purchase
--
-- Key design decisions:
--   - Raw counts only — percentages handled in PA_4
--   - Browser and operating system combinations same
--     as in PA_2
--   - Users with only one event filtered out to remove
--     single-event sessions that don't represent
--      meaningful funnel engagement
--
-- Tableau usage: PA_3 data source — Dashboard 2
--   Joined to PA_4 on browser + operating_system
--   Raw counts appear in Tooltip
--
-- Analysis period: 2020-11-01 through 2021-01-25
-- Dataset: tc-da-1.turing_data_analytics.raw_events
-- ============================================
WITH events AS 
(SELECT user_pseudo_id, event_name, event_timestamp,  
country, category,browser, browser_version,operating_system,
mobile_brand_name, mobile_model_name,
FROM `tc-da-1.turing_data_analytics.raw_events`
WHERE browser IN ('Chrome','Safari') AND 
operating_system IN ('iOS', 'Macintosh','Windows','Android')
),

event_steps AS 
(SELECT  COUNT (e.user_pseudo_id) AS user_events,
e.event_name,e.browser, e.operating_system
FROM  events e
WHERE e.event_name = 'add_to_cart' OR 
e.event_name = 'begin_checkout' OR
e.event_name = 'first_visit' OR 
e.event_name = 'add_payment_info' OR
e.event_name = 'add_shipping_info' OR 
e.event_name = 'purchase'


GROUP BY e.event_name, e.browser, e.operating_system
ORDER BY user_events DESC)

SELECT browser, operating_system,
    SUM(CASE WHEN event_name = 'first_visit' THEN es.user_events ELSE 0 END) AS first_visit,
    SUM(CASE WHEN event_name = 'add_to_cart' THEN es.user_events ELSE 0 END) AS add_to_cart,
    SUM(CASE WHEN event_name = 'begin_checkout' THEN es.user_events ELSE 0 END) AS begin_checkout,
    SUM(CASE WHEN event_name = 'add_shipping_info' THEN es.user_events ELSE 0 END) AS add_shipping_info,
    SUM(CASE WHEN event_name = 'add_payment_info' THEN es.user_events ELSE 0 END) AS add_payment_info,
    SUM(CASE WHEN event_name = 'purchase' THEN user_events ELSE 0 END) AS purchase
FROM event_steps es
WHERE user_events > 1
GROUP BY browser, operating_system
ORDER BY browser, operating_system;
