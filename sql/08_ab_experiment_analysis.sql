USE adtrack_intelligence;

-- =====================================================
-- Step 8A: Check experiment assignment
-- Shows how many generated ad requests were assigned to each variant.
-- =====================================================

SELECT
    e.experiment_id,
    e.experiment_name,
    e.variant,
    e.algorithm_name,
    COUNT(*) AS ad_requests
FROM ad_requests ar
JOIN experiments e
    ON ar.experiment_id = e.experiment_id
WHERE ar.tracking_id LIKE 'trk_py_%'
GROUP BY
    e.experiment_id,
    e.experiment_name,
    e.variant,
    e.algorithm_name
ORDER BY e.variant;

-- =====================================================
-- Step 8B: A/B experiment KPI comparison
-- We compare Variant A vs Variant B using generated ad requests and events.
-- =====================================================

SELECT
    e.variant,
    e.algorithm_name,

    COUNT(DISTINCT ar.ad_request_id) AS ad_requests,

    COUNT(CASE WHEN er.event_type = 'impression' THEN 1 END) AS impressions,
    COUNT(CASE WHEN er.event_type = 'click' THEN 1 END) AS clicks,
    COUNT(CASE WHEN er.event_type = 'install' THEN 1 END) AS installs,
    COUNT(CASE WHEN er.event_type = 'conversion' THEN 1 END) AS conversions,
    COUNT(CASE WHEN er.event_type = 'reward' THEN 1 END) AS rewards,

    COALESCE(
        ROUND(
            COUNT(CASE WHEN er.event_type = 'impression' THEN 1 END)
            / NULLIF(COUNT(DISTINCT ar.ad_request_id), 0),
            4
        ),
        0.0000
    ) AS impression_rate,

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
        SUM(CASE WHEN er.event_type = 'install' THEN c.bid_cpi ELSE 0 END),
        2
    ) AS spend,

    ROUND(COALESCE(SUM(er.revenue), 0), 2) AS revenue,
    ROUND(COALESCE(SUM(er.reward_cost), 0), 2) AS reward_cost,

    ROUND(
        COALESCE(SUM(er.revenue), 0)
        - SUM(CASE WHEN er.event_type = 'install' THEN c.bid_cpi ELSE 0 END)
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

FROM ad_requests ar
JOIN experiments e
    ON ar.experiment_id = e.experiment_id
JOIN campaigns c
    ON ar.campaign_id = c.campaign_id
LEFT JOIN events_raw er
    ON ar.tracking_id = er.tracking_id
WHERE ar.tracking_id LIKE 'trk_py_%'
GROUP BY
    e.variant,
    e.algorithm_name
ORDER BY e.variant;

-- =====================================================
-- Step 8C: Create experiment_results reporting table
-- =====================================================

CREATE TABLE IF NOT EXISTS experiment_results (
    result_id INT AUTO_INCREMENT PRIMARY KEY,
    experiment_name VARCHAR(100) NOT NULL,
    variant ENUM('A', 'B') NOT NULL,
    algorithm_name VARCHAR(100) NOT NULL,

    ad_requests INT DEFAULT 0,
    impressions INT DEFAULT 0,
    clicks INT DEFAULT 0,
    installs INT DEFAULT 0,
    conversions INT DEFAULT 0,
    rewards INT DEFAULT 0,

    impression_rate DECIMAL(10,4) DEFAULT 0.0000,
    ctr DECIMAL(10,4) DEFAULT 0.0000,
    install_rate DECIMAL(10,4) DEFAULT 0.0000,
    conversion_rate DECIMAL(10,4) DEFAULT 0.0000,

    spend DECIMAL(12,2) DEFAULT 0.00,
    revenue DECIMAL(12,2) DEFAULT 0.00,
    reward_cost DECIMAL(12,2) DEFAULT 0.00,
    profit DECIMAL(12,2) DEFAULT 0.00,
    ecpm DECIMAL(12,2) DEFAULT 0.00,

    calculated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

TRUNCATE TABLE experiment_results;

INSERT INTO experiment_results (
    experiment_name,
    variant,
    algorithm_name,
    ad_requests,
    impressions,
    clicks,
    installs,
    conversions,
    rewards,
    impression_rate,
    ctr,
    install_rate,
    conversion_rate,
    spend,
    revenue,
    reward_cost,
    profit,
    ecpm
)
SELECT
    e.experiment_name,
    e.variant,
    e.algorithm_name,

    COUNT(DISTINCT ar.ad_request_id) AS ad_requests,

    COUNT(CASE WHEN er.event_type = 'impression' THEN 1 END) AS impressions,
    COUNT(CASE WHEN er.event_type = 'click' THEN 1 END) AS clicks,
    COUNT(CASE WHEN er.event_type = 'install' THEN 1 END) AS installs,
    COUNT(CASE WHEN er.event_type = 'conversion' THEN 1 END) AS conversions,
    COUNT(CASE WHEN er.event_type = 'reward' THEN 1 END) AS rewards,

    COALESCE(
        ROUND(
            COUNT(CASE WHEN er.event_type = 'impression' THEN 1 END)
            / NULLIF(COUNT(DISTINCT ar.ad_request_id), 0),
            4
        ),
        0.0000
    ) AS impression_rate,

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
        SUM(CASE WHEN er.event_type = 'install' THEN c.bid_cpi ELSE 0 END),
        2
    ) AS spend,

    ROUND(COALESCE(SUM(er.revenue), 0), 2) AS revenue,
    ROUND(COALESCE(SUM(er.reward_cost), 0), 2) AS reward_cost,

    ROUND(
        COALESCE(SUM(er.revenue), 0)
        - SUM(CASE WHEN er.event_type = 'install' THEN c.bid_cpi ELSE 0 END)
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

FROM ad_requests ar
JOIN experiments e
    ON ar.experiment_id = e.experiment_id
JOIN campaigns c
    ON ar.campaign_id = c.campaign_id
LEFT JOIN events_raw er
    ON ar.tracking_id = er.tracking_id
WHERE ar.tracking_id LIKE 'trk_py_%'
GROUP BY
    e.experiment_name,
    e.variant,
    e.algorithm_name;

    -- =====================================================
-- Step 8D: Variant B uplift compared to Variant A
-- =====================================================

SELECT
    a.variant AS baseline_variant,
    b.variant AS test_variant,

    a.algorithm_name AS baseline_algorithm,
    b.algorithm_name AS test_algorithm,

    a.ad_requests AS a_ad_requests,
    b.ad_requests AS b_ad_requests,

    a.ctr AS a_ctr,
    b.ctr AS b_ctr,
    ROUND((b.ctr - a.ctr) / NULLIF(a.ctr, 0) * 100, 2) AS ctr_lift_percent,

    a.install_rate AS a_install_rate,
    b.install_rate AS b_install_rate,
    ROUND((b.install_rate - a.install_rate) / NULLIF(a.install_rate, 0) * 100, 2) AS install_rate_lift_percent,

    a.conversion_rate AS a_conversion_rate,
    b.conversion_rate AS b_conversion_rate,
    ROUND((b.conversion_rate - a.conversion_rate) / NULLIF(a.conversion_rate, 0) * 100, 2) AS conversion_rate_lift_percent,

    a.revenue AS a_revenue,
    b.revenue AS b_revenue,
    ROUND(b.revenue - a.revenue, 2) AS revenue_delta,

    a.spend AS a_spend,
    b.spend AS b_spend,
    ROUND(b.spend - a.spend, 2) AS spend_delta,

    a.profit AS a_profit,
    b.profit AS b_profit,
    ROUND(b.profit - a.profit, 2) AS profit_delta,

    a.ecpm AS a_ecpm,
    b.ecpm AS b_ecpm,
    ROUND(b.ecpm - a.ecpm, 2) AS ecpm_delta

FROM experiment_results a
JOIN experiment_results b
    ON a.experiment_name = b.experiment_name
WHERE a.variant = 'A'
  AND b.variant = 'B';

  -- =====================================================
-- Step 8E: Daily experiment trend
-- Groups results by request date and variant.
-- =====================================================

SELECT
    DATE(ar.request_time) AS request_date,
    e.variant,
    e.algorithm_name,

    COUNT(DISTINCT ar.ad_request_id) AS ad_requests,

    COUNT(CASE WHEN er.event_type = 'impression' THEN 1 END) AS impressions,
    COUNT(CASE WHEN er.event_type = 'click' THEN 1 END) AS clicks,
    COUNT(CASE WHEN er.event_type = 'install' THEN 1 END) AS installs,
    COUNT(CASE WHEN er.event_type = 'conversion' THEN 1 END) AS conversions,

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

    ROUND(COALESCE(SUM(er.revenue), 0), 2) AS revenue,

    ROUND(
        SUM(CASE WHEN er.event_type = 'install' THEN c.bid_cpi ELSE 0 END),
        2
    ) AS spend,

    ROUND(
        COALESCE(SUM(er.revenue), 0)
        - SUM(CASE WHEN er.event_type = 'install' THEN c.bid_cpi ELSE 0 END)
        - COALESCE(SUM(er.reward_cost), 0),
        2
    ) AS profit

FROM ad_requests ar
JOIN experiments e
    ON ar.experiment_id = e.experiment_id
JOIN campaigns c
    ON ar.campaign_id = c.campaign_id
LEFT JOIN events_raw er
    ON ar.tracking_id = er.tracking_id
WHERE ar.tracking_id LIKE 'trk_py_%'
GROUP BY
    DATE(ar.request_time),
    e.variant,
    e.algorithm_name
ORDER BY
    request_date,
    e.variant;