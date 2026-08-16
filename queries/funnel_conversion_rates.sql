-- ============================================
-- PA_4: Funnel Rates by Browser & OS
-- ============================================
-- Purpose: Calculates funnel conversion rates for each
--          browser and operating system combination,
--          normalizing raw PA_3 counts as percentages
--          in PA_3. Provides percentage rates
--          of first visit users to enable cross-segment
--          comparison regardless of traffic volume.
--
-- Output file: PA_4__(Browser,_OS_Funnel_Rates).csv
-- Rows: 6 (one per browser/OS combination)
--
-- Key design decisions:
--   - Percentages normalized to first_visit as baseline
--     (prct_first_visit = 100% for all segments)
--   - Paired with PA_3 — PA_4 drives the visualization,
--     PA_3 provides raw counts in tooltips
--   -  Absolute percentages: each step / first_visit count
--     drives the funnel bar chart
--   - Relative step-to-step drop-off percentages
--     available in tooltip calculated fields
--
-- Tableau usage: PA_4 data source — Dashboard 2
--   Primary measure for funnel bar chart
--   Axis label: % of First Visit Users
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
operating_system IN ('iOS', 'Macintosh','Windows','Android')),

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
ORDER BY user_events DESC), 

pivot_counts AS 
(SELECT browser, operating_system,
    SUM(CASE WHEN event_name = 'first_visit' THEN es.user_events ELSE 0 END) AS first_visit,
    SUM(CASE WHEN event_name = 'add_to_cart' THEN es.user_events ELSE 0 END) AS add_to_cart,
    SUM(CASE WHEN event_name = 'begin_checkout' THEN es.user_events ELSE 0 END) AS begin_checkout,
    SUM(CASE WHEN event_name = 'add_shipping_info' THEN es.user_events ELSE 0 END) AS add_shipping_info,
    SUM(CASE WHEN event_name = 'add_payment_info' THEN es.user_events ELSE 0 END) AS add_payment_info,
    SUM(CASE WHEN event_name = 'purchase' THEN user_events ELSE 0 END) AS purchase
FROM event_steps es
WHERE user_events > 1
GROUP BY browser, operating_system)

SELECT  operating_system, browser,
ROUND(first_visit/first_visit * 100,2) AS prct_first_visit, 
ROUND(add_to_cart/first_visit * 100,2) AS prct_add_to_cart, 
ROUND(begin_checkout/first_visit * 100,2) AS prct_begin_checkout,
ROUND(add_shipping_info/first_visit * 100,2) AS prct_add_shipping,
ROUND(add_payment_info/first_visit * 100,2) AS prct_add_payment,
ROUND(purchase/first_visit * 100,2) AS prct_purchase
FROM pivot_counts
