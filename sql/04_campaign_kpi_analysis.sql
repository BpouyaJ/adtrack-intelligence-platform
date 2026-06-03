USE adtrack_intelligence;

-- =====================================================
-- Step 4A: Campaign KPI analysis from manual raw event data
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
WHERE er.tracking_id LIKE 'trk_manual_%'
GROUP BY
    er.campaign_id,
    c.campaign_name,
    c.target_country,
    c.target_platform,
    c.target_category,
    c.bid_cpi
ORDER BY profit DESC;


-- =====================================================
-- Step 4B: Insert manual campaign metrics into reporting table
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
WHERE er.tracking_id LIKE 'trk_manual_%'
GROUP BY
    DATE(er.event_time),
    er.campaign_id,
    c.bid_cpi;


-- =====================================================
-- Step 4C: Test reporting table
-- =====================================================

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
ORDER BY d.profit DESC;