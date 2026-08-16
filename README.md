# E-Commerce Daily Duration and Friction Analysis

**Turing College Data Analytics Certificate - Product Analyst Project**   
**Analysis Period:** November 2020 - January 2021  
**Dataset:** E-commerce event-level clickstream data, Nov 2020–Jan 2021  
**Tableau Dashboard:** [View on Tableau Public](https://public.tableau.com/views/ProductAnalystProject_17805926636940/Introduction?:language=en-US&publish=yes&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)

---

## Project Overview

This analysis examines checkout friction patterns in a Google Analytics 
e-commerce dataset spanning November 2020 through January 25th 2021 (last 
five days of the month filtered out due to missing data). In this span, 
253,609 unique users visited, 9303 initiated checkout, and 4,195 completed a purchase. 
Of those who initiated checkout, 1,949 abandoned without purchasing — 58.13% of whom showed detectable friction signals.
The central emergent question: How does checkout friction meaningfully impact time to purchase 
(average daily duration), funnel completion rates, and revenue outcomes?

The analysis was structured around a PM presentation framework — 
identifying where friction occurs, quantifying its business impact, 
and providing actionable recommendations for engineering prioritization.

---

## Key Findings

- Clean path users purchase **17% faster** (57.41 vs 68.97 min avg) than overall users
- **$75,390** in revenue lost to friction-driven abandonment
- **$260,105** in at-risk revenue retained despite friction
- **Chrome/Macintosh** users show highest time-to-purchase (79 min)
- **889 users** looped on begin_checkout — dominant friction pattern
- **307 users** likely experienced payment processing failure
- Funnel drop-off consistent across all browser/OS segments

---

## Key Definitions

**Friction**  
Detected when a user repeated the same checkout step more than once 
before completing or abandoning their purchase.

**Clean Path**  
A user who initiated checkout and completed each required downstream step exactly once — shipping, payment method, and payment info — with no repeated steps within the same session. begin_checkout was excluded from the step-count requirement due to widespread re-entry behavior that would have made the definition too restrictive for meaningful analysis (n = 626 users, Nov 2020–Jan 25th, 2021).

**Friction Completers**  
Users who experienced friction but still completed their purchase 
(n= 3,909 users — $260,105 at-risk revenue retained).

**Friction Churners**  
Users who experienced friction and abandoned without purchasing 
(n= 1,133 users — $75,390 in lost revenue).

**Total Checkout Churners**  
All users who reached a checkout step and never purchased, regardless 
of friction detection (n= 1,949 — 58.13% friction-driven).

**AOV**  
$66.54 — calculated as `AVG(purchase_revenue_in_usd)` across all 
purchase transactions through 2021-01-25. Used consistently across 
all revenue calculations.

---

## Recommendations

1. **Fix checkout restart loop** - 889 friction churners (78.5%)
   churned after hitting `begin_checkout` more than once.
   Investigate back button behavior and session persistence.

2. **Investigate payment processing failures** - 307 users submitted
   payment info but returned to the payment method where they
   chured. 208 users were friction churners, having seen the same step
   multiple times. Priority to fix the payment steps.

3. **Prioritize Chrome UX** - Chrome/Macintosh (79 min avg, highest segment)
   and Chrome/Android both exceed the overall average. Focus friction 
   reduction on desktop Chrome first.

4. **Address shipping redirection** — 410 users were redirected back 
   to checkout after shipping. Investigate the checkout/shipping 
   navigation flow.

5. **Fix 'Check Your Information'tracking** - 51.6% of users checkout
   starters (5,014 of 9,715) showed no `Checkout Your Information`
   event. This step was excluded from the clean path definition as
   a result. In a production environment, verifying whether this reflects
   a tracking gap or an optional checkout flow would enable more precise 
   funnel analysis.

---

## File Inventory

| File | Rows | Grain | Query |
|---|---|---|---|
| PA_1 | 87 | Daily + overall duration | [`queries/daily_session_duration.sql`](queries/daily_session_duration.sql) |
| PA_2 | 397 | Daily by browser/OS | [`queries/duration_by_browser_os.sql`](queries/duration_by_browser_os.sql) |
| PA_3 | 6 | Funnel counts by browser/OS | [`queries/funnel_step_counts.sql`](queries/funnel_step_counts.sql) |
| PA_4 | 6 | Funnel rates by browser/OS | [`queries/funnel_conversion_rates.sql`](queries/funnel_conversion_rates.sql) |
| PA_5 | 2,506 | Individual churners | [`queries/individual_churners.sql`](queries/individual_churners.sql) |
| PA_8 | 173 | Clean path vs overall daily | [`queries/clean_path_overall.sql`](queries/clean_path_overall.sql) |
| PA_9 | 2 | Friction segments + revenue | [`queries/friction_segments.sql`](queries/friction_segments.sql) |
| AOV Diagnostic | — | Single scalar value | [`queries/aov_diagnostic.sql`](queries/aov_diagnostic.sql) |

---

## Queries

All SQL queries are in the `/queries` folder. Each file includes 
purpose comments and inline analytical decision notes.  
/queries  
- daily_session_duration.sql 
- duration_by_browser_os.sql 
- funnel_step_counts.sql
- funnel_conversion_rates.sql
- individual_churners.sql  
- clean_path_overall.sql  
- friction_segments.sql  
- aov_diagnostic.sql  

---

## Known Limitiations

- **Session proxy** - 'event_date' used as a session boundary.
  Multi-day checkout journeys excluded.
- **Payment Method / add_payment_info pairing** — these events fire 
  simultaneously at identical timestamps, causing double-counting 
  in some analyses.
- **Checkout Your Information** — excluded from clean path definition 
  due to 51.6% absence rate suggesting tracking gap rather than 
  user behavior.
  - **AOV as fixed multiplier** — revenue calculations use a single 
  AOV ($66.54) applied uniformly across all segments.
  - **begin_checkout in Clean Path** - begin_checkout exclusion from clean path definition — begin_checkout was excluded as a clean path criterion due to widespread re-entry        behavior across the dataset. As a result, clean path measures efficient completion of downstream checkout steps only. Whether a user entered checkout once or multiple times       before completing those steps cleanly cannot be determined from this definition. This means some clean path users may have re-entered checkout before completing, and the 57.41    minute average may slightly understate true single-pass completion time.


