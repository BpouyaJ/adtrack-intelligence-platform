USE adtrack_intelligence;

-- =====================================================
-- Step 7A: Check generated data volume
-- =====================================================

SELECT
    COUNT(*) AS generated_ad_requests
FROM ad_requests
WHERE tracking_id LIKE 'trk_py_%';

SELECT
    COUNT(*) AS generated_events
FROM events_raw
WHERE tracking_id LIKE 'trk_py_%';

SELECT
    event_type,
    COUNT(*) AS event_count
FROM events_raw
WHERE tracking_id LIKE 'trk_py_%'
GROUP BY event_type
ORDER BY event_count DESC;

-- =====================================================
-- Step 7B: Campaign KPI analysis from generated events
-- =====================================================

SELECT
    er.campaign_id,
    c.campaign_name,
    c.target_country,
    c.target_platform,
    c.target_category,
    c.bid_cpi,

    COUNT(CASE WHEN er.event_type = 'impression' THEN 1 END) AS impressions,
    COUNT(CASE WHEN er.event_type = 'click' THEN 1 END) AS clicks,
    COUNT(CASE WHEN er.event_type = 'install' THEN 1 END) AS installs,
    COUNT(CASE WHEN er.event_type = 'conversion' THEN 1 END) AS conversions,
    COUNT(CASE WHEN er.event_type = 'reward' THEN 1 END) AS rewards,

    ROUND(
        COUNT(CASE WHEN er.event_type = 'click' THEN 1 END)
        / NULLIF(COUNT(CASE WHEN er.event_type = 'impression' THEN 1 END), 0),
        4
    ) AS ctr,

    ROUND(
        COUNT(CASE WHEN er.event_type = 'install' THEN 1 END)
        / NULLIF(COUNT(CASE WHEN er.event_type = 'click' THEN 1 END), 0),
        4
    ) AS install_rate,

    ROUND(
        COUNT(CASE WHEN er.event_type = 'conversion' THEN 1 END)
        / NULLIF(COUNT(CASE WHEN er.event_type = 'install' THEN 1 END), 0),
        4
    ) AS conversion_rate,

    ROUND(
        COUNT(CASE WHEN er.event_type = 'install' THEN 1 END) * c.bid_cpi,
        2
    ) AS spend,

    ROUND(COALESCE(SUM(er.revenue), 0), 2) AS revenue,

    ROUND(COALESCE(SUM(er.reward_cost), 0), 2) AS reward_cost,

    ROUND(
        COALESCE(SUM(er.revenue), 0)
        - (COUNT(CASE WHEN er.event_type = 'install' THEN 1 END) * c.bid_cpi)
        - COALESCE(SUM(er.reward_cost), 0),
        2
    ) AS profit,

    ROUND(
        COALESCE(SUM(er.revenue), 0)
        / NULLIF(COUNT(CASE WHEN er.event_type = 'impression' THEN 1 END), 0)
        * 1000,
        2
    ) AS ecpm

FROM events_raw er
JOIN campaigns c
    ON er.campaign_id = c.campaign_id
WHERE er.tracking_id LIKE 'trk_py_%'
GROUP BY
    er.campaign_id,
    c.campaign_name,
    c.target_country,
    c.target_platform,
    c.target_category,
    c.bid_cpi
ORDER BY profit DESC;

-- =====================================================
-- Step 7C: Refresh daily campaign metrics with generated data
-- Safe version: prevents NULL/NaN KPI values
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
    DATE(er.event_time) AS metric_date,
    er.campaign_id,

    COUNT(CASE WHEN er.event_type = 'impression' THEN 1 END) AS impressions,
    COUNT(CASE WHEN er.event_type = 'click' THEN 1 END) AS clicks,
    COUNT(CASE WHEN er.event_type = 'install' THEN 1 END) AS installs,
    COUNT(CASE WHEN er.event_type = 'conversion' THEN 1 END) AS conversions,
    COUNT(CASE WHEN er.event_type = 'reward' THEN 1 END) AS rewards,

    COALESCE(
        ROUND(
            COUNT(CASE WHEN er.event_type = 'click' THEN 1 END)
            / NULLIF(COUNT(CASE WHEN er.event_type = 'impression' THEN 1 END), 0),
            4
        ),
        0.0000
    ) AS ctr,

    COALESCE(
        ROUND(
            COUNT(CASE WHEN er.event_type = 'install' THEN 1 END)
            / NULLIF(COUNT(CASE WHEN er.event_type = 'click' THEN 1 END), 0),
            4
        ),
        0.0000
    ) AS install_rate,

    COALESCE(
        ROUND(
            COUNT(CASE WHEN er.event_type = 'conversion' THEN 1 END)
            / NULLIF(COUNT(CASE WHEN er.event_type = 'install' THEN 1 END), 0),
            4
        ),
        0.0000
    ) AS conversion_rate,

    ROUND(
        COUNT(CASE WHEN er.event_type = 'install' THEN 1 END) * c.bid_cpi,
        2
    ) AS spend,

    ROUND(COALESCE(SUM(er.revenue), 0), 2) AS revenue,

    ROUND(
        COALESCE(SUM(er.revenue), 0)
        - (COUNT(CASE WHEN er.event_type = 'install' THEN 1 END) * c.bid_cpi)
        - COALESCE(SUM(er.reward_cost), 0),
        2
    ) AS profit,

    COALESCE(
        ROUND(
            COALESCE(SUM(er.revenue), 0)
            / NULLIF(COUNT(CASE WHEN er.event_type = 'impression' THEN 1 END), 0)
            * 1000,
            2
        ),
        0.00
    ) AS ecpm

FROM events_raw er
JOIN campaigns c
    ON er.campaign_id = c.campaign_id
WHERE er.tracking_id LIKE 'trk_py_%'
GROUP BY
    DATE(er.event_time),
    er.campaign_id,
    c.bid_cpi;

-- =====================================================
-- Step 7D: Refresh daily app/game metrics with generated data
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
    DATE(er.event_time) AS metric_date,
    er.app_id,

    COUNT(CASE WHEN er.event_type = 'impression' THEN 1 END) AS impressions,
    COUNT(CASE WHEN er.event_type = 'click' THEN 1 END) AS clicks,
    COUNT(CASE WHEN er.event_type = 'install' THEN 1 END) AS installs,
    COUNT(CASE WHEN er.event_type = 'conversion' THEN 1 END) AS conversions,

    ROUND(COALESCE(SUM(er.revenue), 0), 2) AS revenue,
    ROUND(COALESCE(SUM(er.reward_cost), 0), 2) AS reward_cost

FROM events_raw er
WHERE er.tracking_id LIKE 'trk_py_%'
GROUP BY
    DATE(er.event_time),
    er.app_id;

-- =====================================================
-- Step 7E-1: Best campaigns by total profit
-- =====================================================

SELECT
    c.campaign_id,
    c.campaign_name,
    c.target_country,
    c.target_platform,
    c.target_category,

    SUM(d.impressions) AS impressions,
    SUM(d.clicks) AS clicks,
    SUM(d.installs) AS installs,
    SUM(d.conversions) AS conversions,

    ROUND(SUM(d.clicks) / NULLIF(SUM(d.impressions), 0), 4) AS ctr,
    ROUND(SUM(d.installs) / NULLIF(SUM(d.clicks), 0), 4) AS install_rate,
    ROUND(SUM(d.conversions) / NULLIF(SUM(d.installs), 0), 4) AS conversion_rate,

    ROUND(SUM(d.spend), 2) AS total_spend,
    ROUND(SUM(d.revenue), 2) AS total_revenue,
    ROUND(SUM(d.profit), 2) AS total_profit,
    ROUND(SUM(d.revenue) / NULLIF(SUM(d.impressions), 0) * 1000, 2) AS ecpm

FROM daily_campaign_metrics d
JOIN campaigns c
    ON d.campaign_id = c.campaign_id
GROUP BY
    c.campaign_id,
    c.campaign_name,
    c.target_country,
    c.target_platform,
    c.target_category
ORDER BY total_profit DESC;

-- =====================================================
-- Step 7E-2: Worst campaigns by total profit
-- =====================================================

SELECT
    c.campaign_id,
    c.campaign_name,
    c.target_country,
    c.target_platform,
    c.target_category,

    SUM(d.impressions) AS impressions,
    SUM(d.clicks) AS clicks,
    SUM(d.installs) AS installs,
    SUM(d.conversions) AS conversions,

    ROUND(SUM(d.clicks) / NULLIF(SUM(d.impressions), 0), 4) AS ctr,
    ROUND(SUM(d.installs) / NULLIF(SUM(d.clicks), 0), 4) AS install_rate,

    ROUND(SUM(d.spend), 2) AS total_spend,
    ROUND(SUM(d.revenue), 2) AS total_revenue,
    ROUND(SUM(d.profit), 2) AS total_profit

FROM daily_campaign_metrics d
JOIN campaigns c
    ON d.campaign_id = c.campaign_id
GROUP BY
    c.campaign_id,
    c.campaign_name,
    c.target_country,
    c.target_platform,
    c.target_category
ORDER BY total_profit ASC;

-- =====================================================
-- Step 7E-3: Best apps/games by revenue
-- =====================================================

SELECT
    a.app_id,
    a.app_name,
    p.publisher_name,
    a.category,
    a.platform,

    SUM(d.impressions) AS impressions,
    SUM(d.clicks) AS clicks,
    SUM(d.installs) AS installs,
    SUM(d.conversions) AS conversions,

    ROUND(SUM(d.clicks) / NULLIF(SUM(d.impressions), 0), 4) AS ctr,
    ROUND(SUM(d.installs) / NULLIF(SUM(d.clicks), 0), 4) AS install_rate,

    ROUND(SUM(d.revenue), 2) AS total_revenue,
    ROUND(SUM(d.reward_cost), 2) AS total_reward_cost

FROM daily_app_metrics d
JOIN apps a
    ON d.app_id = a.app_id
JOIN publishers p
    ON a.publisher_id = p.publisher_id
GROUP BY
    a.app_id,
    a.app_name,
    p.publisher_name,
    a.category,
    a.platform
ORDER BY total_revenue DESC;

-- =====================================================
-- Step 7E-4: Publisher performance
-- =====================================================

SELECT
    p.publisher_id,
    p.publisher_name,
    p.country AS publisher_country,

    SUM(d.impressions) AS impressions,
    SUM(d.clicks) AS clicks,
    SUM(d.installs) AS installs,
    SUM(d.conversions) AS conversions,

    ROUND(SUM(d.clicks) / NULLIF(SUM(d.impressions), 0), 4) AS ctr,
    ROUND(SUM(d.installs) / NULLIF(SUM(d.clicks), 0), 4) AS install_rate,

    ROUND(SUM(d.revenue), 2) AS total_revenue,
    ROUND(SUM(d.reward_cost), 2) AS total_reward_cost

FROM daily_app_metrics d
JOIN apps a
    ON d.app_id = a.app_id
JOIN publishers p
    ON a.publisher_id = p.publisher_id
GROUP BY
    p.publisher_id,
    p.publisher_name,
    p.country
ORDER BY total_revenue DESC;

-- =====================================================
-- Step 7E-5: Country and platform performance
-- =====================================================

SELECT
    c.target_country,
    c.target_platform,

    SUM(d.impressions) AS impressions,
    SUM(d.clicks) AS clicks,
    SUM(d.installs) AS installs,
    SUM(d.conversions) AS conversions,

    ROUND(SUM(d.clicks) / NULLIF(SUM(d.impressions), 0), 4) AS ctr,
    ROUND(SUM(d.installs) / NULLIF(SUM(d.clicks), 0), 4) AS install_rate,
    ROUND(SUM(d.conversions) / NULLIF(SUM(d.installs), 0), 4) AS conversion_rate,

    ROUND(SUM(d.spend), 2) AS total_spend,
    ROUND(SUM(d.revenue), 2) AS total_revenue,
    ROUND(SUM(d.profit), 2) AS total_profit

FROM daily_campaign_metrics d
JOIN campaigns c
    ON d.campaign_id = c.campaign_id
GROUP BY
    c.target_country,
    c.target_platform
ORDER BY total_profit DESC;

-- =====================================================
-- Step 7E-6: App category performance
-- =====================================================

SELECT
    a.category,

    SUM(d.impressions) AS impressions,
    SUM(d.clicks) AS clicks,
    SUM(d.installs) AS installs,
    SUM(d.conversions) AS conversions,

    ROUND(SUM(d.clicks) / NULLIF(SUM(d.impressions), 0), 4) AS ctr,
    ROUND(SUM(d.installs) / NULLIF(SUM(d.clicks), 0), 4) AS install_rate,

    ROUND(SUM(d.revenue), 2) AS total_revenue,
    ROUND(SUM(d.reward_cost), 2) AS total_reward_cost

FROM daily_app_metrics d
JOIN apps a
    ON d.app_id = a.app_id
GROUP BY
    a.category
ORDER BY total_revenue DESC;

