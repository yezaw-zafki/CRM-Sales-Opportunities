/*markdown
# 1. Table size
- confirm how many rows were loaded into each table
*/

SELECT 'fact_sale' AS table_name, COUNT(*) AS row_count FROM fact_sale
UNION ALL
SELECT 'dim_accounts', COUNT(*) FROM dim_accounts
UNION ALL
SELECT 'dim_products', COUNT(*) FROM dim_products
UNION ALL
SELECT 'dim_sales_teams', COUNT(*) FROM dim_sales_teams;

/*markdown
# 2. Overall Sales KPIs
- opportunity volume, outcomes, win rate, and deal values.
*/

SELECT
    COUNT(*) AS total_opportunities,
    COUNT(*) FILTER (WHERE is_won) AS won_opportunities,
    COUNT(*) FILTER (WHERE is_lost) AS lost_opportunities,
    COUNT(*) FILTER (WHERE is_open) AS open_opportunities,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE is_won)
        / NULLIF(COUNT(*) FILTER (WHERE is_won OR is_lost), 0),
        2
    ) AS closed_opportunity_win_rate_pct,
    TO_CHAR(SUM(close_value) FILTER (WHERE is_won), 'FM999,999,999,999,990.00')
        AS won_revenue,
    TO_CHAR(AVG(close_value) FILTER (WHERE is_won), 'FM999,999,999,999,990.00')
        AS average_won_deal_value,
    TO_CHAR(SUM(close_value) FILTER (WHERE is_open), 'FM999,999,999,999,990.00')
        AS recorded_open_pipeline_value
FROM fact_sale;

/*markdown
# 3. Data Quality
- check missing fields, date order, and consistency of stage flags.
*/

SELECT
    COUNT(*) FILTER (WHERE opportunity_id IS NULL) AS missing_opportunity_id,
    COUNT(*) FILTER (WHERE deal_stage IS NULL) AS missing_deal_stage,
    COUNT(*) FILTER (WHERE sales_agent_id IS NULL) AS missing_sales_agent,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS missing_product,
    COUNT(*) FILTER (WHERE account_id IS NULL) AS missing_account,
    COUNT(*) FILTER (WHERE engage_date IS NULL) AS missing_engage_date,
    COUNT(*) FILTER (WHERE close_date IS NULL) AS missing_close_date,
    COUNT(*) FILTER (WHERE close_value IS NULL) AS missing_close_value,
    COUNT(*) FILTER (
        WHERE engage_date IS NOT NULL
          AND close_date IS NOT NULL
          AND close_date < engage_date
    ) AS close_before_engage,
    COUNT(*) FILTER (
        WHERE is_won IS DISTINCT FROM (LOWER(deal_stage) = 'won')
           OR is_lost IS DISTINCT FROM (LOWER(deal_stage) = 'lost')
           OR is_open IS DISTINCT FROM (
               COALESCE(LOWER(deal_stage) NOT IN ('won', 'lost'), TRUE)
           )
    ) AS stage_flag_mismatches
FROM fact_sale;

/*markdown
# 4. Opportunity Funnel
- compare volume and share at each deal stage.
*/

SELECT
    deal_stage,
    COUNT(*) AS opportunities,
    ROUND(100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0), 2) AS share_pct,
    TO_CHAR(SUM(close_value) FILTER (WHERE is_won), 'FM999,999,999,999,990.00')
        AS won_revenue
FROM fact_sale
GROUP BY deal_stage
ORDER BY opportunities DESC;

/*markdown
# 5 Monthly Results
- track closed opportunity outcomes and won revenue over time.
*/

SELECT
    DATE_TRUNC('month', close_date)::date AS close_month,
    COUNT(*) AS closed_opportunities,
    COUNT(*) FILTER (WHERE is_won) AS won_opportunities,
    COUNT(*) FILTER (WHERE is_lost) AS lost_opportunities,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE is_won)
        / NULLIF(COUNT(*) FILTER (WHERE is_won OR is_lost), 0),
        2
    ) AS win_rate_pct,
    TO_CHAR(SUM(close_value) FILTER (WHERE is_won), 'FM999,999,999,999,990.00')
        AS won_revenue
FROM fact_sale
WHERE close_date IS NOT NULL
  AND (is_won OR is_lost)
GROUP BY DATE_TRUNC('month', close_date)
ORDER BY close_month;

/*markdown
# 6. Quarterly Revenue Trend
- compare won deal count, revenue, and average deal size.
*/

SELECT
    DATE_TRUNC('quarter', close_date)::date AS close_quarter,
    COUNT(*) FILTER (WHERE is_won) AS won_opportunities,
    TO_CHAR(SUM(close_value) FILTER (WHERE is_won), 'FM999,999,999,999,990.00')
        AS won_revenue,
    TO_CHAR(AVG(close_value) FILTER (WHERE is_won), 'FM999,999,999,999,990.00')
        AS average_won_deal_value
FROM fact_sale
WHERE close_date IS NOT NULL
GROUP BY DATE_TRUNC('quarter', close_date)
ORDER BY close_quarter;

/*markdown
# 7. Sales Agent Performance
- evaluate closed volume, win rate, and won revenue.
*/

SELECT
    st.sales_agent,
    st.manager,
    st.regional_office,
    COUNT(*) AS total_opportunities,
    COUNT(*) FILTER (WHERE fs.is_won) AS won_opportunities,
    COUNT(*) FILTER (WHERE fs.is_lost) AS lost_opportunities,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE fs.is_won)
        / NULLIF(COUNT(*) FILTER (WHERE fs.is_won OR fs.is_lost), 0),
        2
    ) AS win_rate_pct,
    TO_CHAR(
        SUM(fs.close_value) FILTER (WHERE fs.is_won),
        'FM999,999,999,999,990.00'
    ) AS won_revenue
FROM fact_sale AS fs
JOIN dim_sales_teams AS st USING (sales_agent_id)
GROUP BY st.sales_agent, st.manager, st.regional_office
ORDER BY SUM(fs.close_value) FILTER (WHERE fs.is_won) DESC NULLS LAST;

/*markdown
# 8. Regional Performance
- compare opportunity outcomes and revenue by office.
*/

SELECT
    st.regional_office,
    COUNT(*) AS total_opportunities,
    COUNT(*) FILTER (WHERE fs.is_won) AS won_opportunities,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE fs.is_won)
        / NULLIF(COUNT(*) FILTER (WHERE fs.is_won OR fs.is_lost), 0),
        2
    ) AS win_rate_pct,
    TO_CHAR(
        SUM(fs.close_value) FILTER (WHERE fs.is_won),
        'FM999,999,999,999,990.00'
    ) AS won_revenue
FROM fact_sale AS fs
JOIN dim_sales_teams AS st USING (sales_agent_id)
GROUP BY st.regional_office
ORDER BY SUM(fs.close_value) FILTER (WHERE fs.is_won) DESC NULLS LAST;

/*markdown
# 9. Product Performance
- identify products with the strongest win rates and revenue.
*/


SELECT
    p.product,
    p.series,
    TO_CHAR(p.sales_price, 'FM999,999,999,999,990.00') AS list_price,
    COUNT(*) AS total_opportunities,
    COUNT(*) FILTER (WHERE fs.is_won) AS won_opportunities,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE fs.is_won)
        / NULLIF(COUNT(*) FILTER (WHERE fs.is_won OR fs.is_lost), 0),
        2
    ) AS win_rate_pct,
    TO_CHAR(
        SUM(fs.close_value) FILTER (WHERE fs.is_won),
        'FM999,999,999,999,990.00'
    ) AS won_revenue,
    TO_CHAR(
        AVG(fs.close_value) FILTER (WHERE fs.is_won),
        'FM999,999,999,999,990.00'
    ) AS average_won_deal_value
FROM fact_sale AS fs
JOIN dim_products AS p USING (product_id)
GROUP BY p.product, p.series, p.sales_price
ORDER BY SUM(fs.close_value) FILTER (WHERE fs.is_won) DESC NULLS LAST;

/*markdown
# 10. Sector Performance
compare customer industries by pipeline conversion and value.
*/

SELECT
    a.sector,
    COUNT(*) AS total_opportunities,
    COUNT(*) FILTER (WHERE fs.is_won) AS won_opportunities,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE fs.is_won)
        / NULLIF(COUNT(*) FILTER (WHERE fs.is_won OR fs.is_lost), 0),
        2
    ) AS win_rate_pct,
    TO_CHAR(
        SUM(fs.close_value) FILTER (WHERE fs.is_won),
        'FM999,999,999,999,990.00'
    ) AS won_revenue
FROM fact_sale AS fs
JOIN dim_accounts AS a USING (account_id)
GROUP BY a.sector
ORDER BY SUM(fs.close_value) FILTER (WHERE fs.is_won) DESC NULLS LAST;

/*markdown
# 11. Account Leaderboard
- find customers contributing the most won revenue.
*/


SELECT
    a.account,
    a.sector,
    a.office_location,
    COUNT(*) AS total_opportunities,
    COUNT(*) FILTER (WHERE fs.is_won) AS won_opportunities,
    TO_CHAR(
        SUM(fs.close_value) FILTER (WHERE fs.is_won),
        'FM999,999,999,999,990.00'
    ) AS won_revenue,
    TO_CHAR(
        AVG(fs.close_value) FILTER (WHERE fs.is_won),
        'FM999,999,999,999,990.00'
    ) AS average_won_deal_value
FROM fact_sale AS fs
JOIN dim_accounts AS a USING (account_id)
GROUP BY a.account, a.sector, a.office_location
ORDER BY SUM(fs.close_value) FILTER (WHERE fs.is_won) DESC NULLS LAST
LIMIT 20;

/*markdown
# 12. Sales cycle
- measure days from engagement to close for won and lost deals.
*/


SELECT
    CASE
        WHEN is_won THEN 'Won'
        WHEN is_lost THEN 'Lost'
    END AS outcome,
    COUNT(*) AS closed_opportunities,
    ROUND(AVG(close_date - engage_date), 1) AS average_days_to_close,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY close_date - engage_date)
        AS median_days_to_close
FROM fact_sale
WHERE (is_won OR is_lost)
  AND engage_date IS NOT NULL
  AND close_date IS NOT NULL
  AND close_date >= engage_date
GROUP BY outcome
ORDER BY outcome;

/*markdown
# 13. Open Pipeline Aging
- find how long current open opportunities have been active.
*/

SELECT
    CASE
        WHEN CURRENT_DATE - engage_date < 30 THEN '0-29 days'
        WHEN CURRENT_DATE - engage_date < 60 THEN '30-59 days'
        WHEN CURRENT_DATE - engage_date < 90 THEN '60-89 days'
        ELSE '90+ days'
    END AS age_bucket,
    COUNT(*) AS open_opportunities,
    TO_CHAR(SUM(close_value), 'FM999,999,999,999,990.00')
        AS recorded_pipeline_value
FROM fact_sale
WHERE is_open
  AND engage_date IS NOT NULL
  AND engage_date <= CURRENT_DATE
GROUP BY age_bucket
ORDER BY MIN(CURRENT_DATE - engage_date);

/*markdown
# 14. Account Profile
- compare customer revenue and size across sectors and locations.
*/

SELECT
    sector,
    office_location,
    COUNT(*) AS accounts,
    TO_CHAR(AVG(revenue), 'FM999,999,999,999,990.00') AS average_account_revenue,
    ROUND(AVG(employees), 0) AS average_employee_count,
    MIN(year_established) AS oldest_establishment_year,
    MAX(year_established) AS newest_establishment_year
FROM dim_accounts
GROUP BY sector, office_location
ORDER BY accounts DESC;

/*markdown
# 15. Data Completeness
- check missing descriptive attributes in dimension tables.
*/

SELECT
    'dim_accounts' AS table_name,
    'sector' AS attribute_name,
    COUNT(*) FILTER (WHERE sector IS NULL) AS missing_values
FROM dim_accounts
UNION ALL
SELECT
    'dim_accounts',
    'revenue',
    COUNT(*) FILTER (WHERE revenue IS NULL)
FROM dim_accounts
UNION ALL
SELECT
    'dim_accounts',
    'employees',
    COUNT(*) FILTER (WHERE employees IS NULL)
FROM dim_accounts
UNION ALL
SELECT
    'dim_accounts',
    'office_location',
    COUNT(*) FILTER (WHERE office_location IS NULL)
FROM dim_accounts
UNION ALL
SELECT
    'dim_products',
    'series',
    COUNT(*) FILTER (WHERE series IS NULL)
FROM dim_products
UNION ALL
SELECT
    'dim_products',
    'sales_price',
    COUNT(*) FILTER (WHERE sales_price IS NULL)
FROM dim_products
UNION ALL
SELECT
    'dim_sales_teams',
    'manager',
    COUNT(*) FILTER (WHERE manager IS NULL)
FROM dim_sales_teams
UNION ALL
SELECT
    'dim_sales_teams',
    'regional_office',
    COUNT(*) FILTER (WHERE regional_office IS NULL)
FROM dim_sales_teams;

