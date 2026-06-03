USE adtrack_intelligence;

-- =====================================================
-- Step 11A: Refresh daily campaign metrics from clean events
-- Source: events_clean
-- Purpose: dashboard/reporting should use validated event data.
-- =====================================================

TRUNCATE TABLE daily_campaign_metrics;

INSERT INTO daily_campaign_metrics (
    metric_date,
    campaign_id,
    impressions,
    clicks,
    installs,
    conversions,
    rewards,
    ctr,
    install_rate,
    conversion_rate,
    spend,
    revenue,
    profit,
    ecpm
)
SELECT
    DATE(ec.event_time) AS metric_date,
    ec.campaign_id,

    COUNT(CASE WHEN ec.event_type = 'impression' THEN 1 END) AS impressions,
    COUNT(CASE WHEN ec.event_type = 'click' THEN 1 END) AS clicks,
    COUNT(CASE WHEN ec.event_type = 'install' THEN 1 END) AS installs,
    COUNT(CASE WHEN ec.event_type = 'conversion' THEN 1 END) AS conversions,
    COUNT(CASE WHEN ec.event_type = 'reward' THEN 1 END) AS rewards,

    COALESCE(
        ROUND(
            COUNT(CASE WHEN ec.event_type = 'click' THEN 1 END)
            / NULLIF(COUNT(CASE WHEN ec.event_type = 'impression' THEN 1 END), 0),
            4
        ),
        0.0000
    ) AS ctr,

    COALESCE(
        ROUND(
            COUNT(CASE WHEN ec.event_type = 'install' THEN 1 END)
            / NULLIF(COUNT(CASE WHEN ec.event_type = 'click' THEN 1 END), 0),
            4
        ),
        0.0000
    ) AS install_rate,

    COALESCE(
        ROUND(
            COUNT(CASE WHEN ec.event_type = 'conversion' THEN 1 END)
            / NULLIF(COUNT(CASE WHEN ec.event_type = 'install' THEN 1 END), 0),
            4
        ),
        0.0000
    ) AS conversion_rate,

    ROUND(
        COUNT(CASE WHEN ec.event_type = 'install' THEN 1 END) * c.bid_cpi,
        2
    ) AS spend,

    ROUND(COALESCE(SUM(ec.revenue), 0), 2) AS revenue,

    ROUND(
        COALESCE(SUM(ec.revenue), 0)
        - (COUNT(CASE WHEN ec.event_type = 'install' THEN 1 END) * c.bid_cpi)
        - COALESCE(SUM(ec.reward_cost), 0),
        2
    ) AS profit,

    COALESCE(
        ROUND(
            COALESCE(SUM(ec.revenue), 0)
            / NULLIF(COUNT(CASE WHEN ec.event_type = 'impression' THEN 1 END), 0)
            * 1000,
            2
        ),
        0.00
    ) AS ecpm

FROM events_clean ec
JOIN campaigns c
    ON ec.campaign_id = c.campaign_id
WHERE ec.tracking_id LIKE 'trk_py_%'
GROUP BY
    DATE(ec.event_time),
    ec.campaign_id,
    c.bid_cpi;


-- =====================================================
-- Step 11B: Refresh daily app/game metrics from clean events
-- Source: events_clean
-- =====================================================

TRUNCATE TABLE daily_app_metrics;

INSERT INTO daily_app_metrics (
    metric_date,
    app_id,
    impressions,
    clicks,
    installs,
    conversions,
    revenue,
    reward_cost
)
SELECT
    DATE(ec.event_time) AS metric_date,
    ec.app_id,

    COUNT(CASE WHEN ec.event_type = 'impression' THEN 1 END) AS impressions,
    COUNT(CASE WHEN ec.event_type = 'click' THEN 1 END) AS clicks,
    COUNT(CASE WHEN ec.event_type = 'install' THEN 1 END) AS installs,
    COUNT(CASE WHEN ec.event_type = 'conversion' THEN 1 END) AS conversions,

    ROUND(COALESCE(SUM(ec.revenue), 0), 2) AS revenue,
    ROUND(COALESCE(SUM(ec.reward_cost), 0), 2) AS reward_cost

FROM events_clean ec
WHERE ec.tracking_id LIKE 'trk_py_%'
GROUP BY
    DATE(ec.event_time),
    ec.app_id;


-- =====================================================
-- Step 11C: Reporting table health checks
-- =====================================================

-- Campaign reporting rows
SELECT
    COUNT(*) AS daily_campaign_metric_rows
FROM daily_campaign_metrics;

-- App/game reporting rows
SELECT
    COUNT(*) AS daily_app_metric_rows
FROM daily_app_metrics;

-- Null KPI safety check: should return 0
SELECT
    COUNT(*) AS rows_with_null_campaign_kpis
FROM daily_campaign_metrics
WHERE ctr IS NULL
   OR install_rate IS NULL
   OR conversion_rate IS NULL
   OR ecpm IS NULL;

-- Campaign performance overview from clean events
SELECT
    d.metric_date,
    d.campaign_id,
    c.campaign_name,
    d.impressions,
    d.clicks,
    d.installs,
    d.conversions,
    d.rewards,
    d.ctr,
    d.install_rate,
    d.conversion_rate,
    d.spend,
    d.revenue,
    d.profit,
    d.ecpm
FROM daily_campaign_metrics d
JOIN campaigns c
    ON d.campaign_id = c.campaign_id
ORDER BY
    d.metric_date,
    d.profit DESC;

-- App/game performance overview from clean events
SELECT
    dam.metric_date,
    dam.app_id,
    a.app_name,
    a.category,
    a.platform,
    p.publisher_name,
    dam.impressions,
    dam.clicks,
    dam.installs,
    dam.conversions,
    dam.revenue,
    dam.reward_cost
FROM daily_app_metrics dam
JOIN apps a
    ON dam.app_id = a.app_id
JOIN publishers p
    ON a.publisher_id = p.publisher_id
ORDER BY
    dam.metric_date,
    dam.revenue DESC;