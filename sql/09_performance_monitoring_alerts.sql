USE adtrack_intelligence;

-- =====================================================
-- Step 9A: Clean old generated monitoring alerts
-- We keep old data_quality alerts, but refresh generated performance alerts.
-- =====================================================

SET SQL_SAFE_UPDATES = 0;

DELETE FROM alerts
WHERE alert_message LIKE '[Generated Monitoring]%'
   OR alert_message LIKE '[Experiment Monitoring]%';

SET SQL_SAFE_UPDATES = 1;


-- =====================================================
-- Step 9B: Campaigns with very negative profit
-- These campaigns may need bid, targeting, or delivery review.
-- =====================================================

INSERT INTO alerts (
    alert_type,
    severity,
    entity_type,
    entity_id,
    alert_message
)
SELECT
    'performance' AS alert_type,
    'high' AS severity,
    'campaign' AS entity_type,
    CAST(c.campaign_id AS CHAR) AS entity_id,
    CONCAT(
        '[Generated Monitoring] Campaign ',
        c.campaign_id,
        ' - ',
        c.campaign_name,
        ' has very negative total profit: ',
        ROUND(SUM(d.profit), 2),
        '. Revenue: ',
        ROUND(SUM(d.revenue), 2),
        ', Spend: ',
        ROUND(SUM(d.spend), 2),
        '.'
    ) AS alert_message
FROM daily_campaign_metrics d
JOIN campaigns c
    ON d.campaign_id = c.campaign_id
GROUP BY
    c.campaign_id,
    c.campaign_name
HAVING SUM(d.profit) < -150;


-- =====================================================
-- Step 9C: High spend with weak revenue
-- Shows campaigns that cost a lot but do not generate enough revenue.
-- =====================================================

INSERT INTO alerts (
    alert_type,
    severity,
    entity_type,
    entity_id,
    alert_message
)
SELECT
    'performance' AS alert_type,
    'medium' AS severity,
    'campaign' AS entity_type,
    CAST(c.campaign_id AS CHAR) AS entity_id,
    CONCAT(
        '[Generated Monitoring] Campaign ',
        c.campaign_id,
        ' - ',
        c.campaign_name,
        ' has high spend compared to revenue. Spend: ',
        ROUND(SUM(d.spend), 2),
        ', Revenue: ',
        ROUND(SUM(d.revenue), 2),
        ', ROAS: ',
        ROUND(SUM(d.revenue) / NULLIF(SUM(d.spend), 0), 4),
        '.'
    ) AS alert_message
FROM daily_campaign_metrics d
JOIN campaigns c
    ON d.campaign_id = c.campaign_id
GROUP BY
    c.campaign_id,
    c.campaign_name
HAVING
    SUM(d.spend) > 100
    AND SUM(d.revenue) / NULLIF(SUM(d.spend), 0) < 0.50;


-- =====================================================
-- Step 9D: Low CTR campaigns
-- CTR below threshold may indicate weak ad relevance or bad targeting.
-- =====================================================

INSERT INTO alerts (
    alert_type,
    severity,
    entity_type,
    entity_id,
    alert_message
)
SELECT
    'performance' AS alert_type,
    'medium' AS severity,
    'campaign' AS entity_type,
    CAST(c.campaign_id AS CHAR) AS entity_id,
    CONCAT(
        '[Generated Monitoring] Campaign ',
        c.campaign_id,
        ' - ',
        c.campaign_name,
        ' has low CTR: ',
        ROUND(SUM(d.clicks) / NULLIF(SUM(d.impressions), 0), 4),
        '. Impressions: ',
        SUM(d.impressions),
        ', Clicks: ',
        SUM(d.clicks),
        '.'
    ) AS alert_message
FROM daily_campaign_metrics d
JOIN campaigns c
    ON d.campaign_id = c.campaign_id
GROUP BY
    c.campaign_id,
    c.campaign_name
HAVING
    SUM(d.impressions) >= 100
    AND SUM(d.clicks) / NULLIF(SUM(d.impressions), 0) < 0.22;


-- =====================================================
-- Step 9E: Good CTR but poor install rate
-- Users click, but do not install. This may indicate post-click friction.
-- =====================================================

INSERT INTO alerts (
    alert_type,
    severity,
    entity_type,
    entity_id,
    alert_message
)
SELECT
    'performance' AS alert_type,
    'medium' AS severity,
    'campaign' AS entity_type,
    CAST(c.campaign_id AS CHAR) AS entity_id,
    CONCAT(
        '[Generated Monitoring] Campaign ',
        c.campaign_id,
        ' - ',
        c.campaign_name,
        ' has acceptable CTR but weak install rate. CTR: ',
        ROUND(SUM(d.clicks) / NULLIF(SUM(d.impressions), 0), 4),
        ', Install rate: ',
        ROUND(SUM(d.installs) / NULLIF(SUM(d.clicks), 0), 4),
        '.'
    ) AS alert_message
FROM daily_campaign_metrics d
JOIN campaigns c
    ON d.campaign_id = c.campaign_id
GROUP BY
    c.campaign_id,
    c.campaign_name
HAVING
    SUM(d.impressions) >= 100
    AND SUM(d.clicks) / NULLIF(SUM(d.impressions), 0) >= 0.22
    AND SUM(d.installs) / NULLIF(SUM(d.clicks), 0) < 0.32;


-- =====================================================
-- Step 9F: Daily CTR drop compared to previous active day
-- Uses LAG() to compare one day with the previous day per campaign.
-- =====================================================

INSERT INTO alerts (
    alert_type,
    severity,
    entity_type,
    entity_id,
    alert_message
)
WITH daily_ctr AS (
    SELECT
        d.metric_date,
        d.campaign_id,
        c.campaign_name,
        SUM(d.impressions) AS impressions,
        SUM(d.clicks) AS clicks,
        COALESCE(
            SUM(d.clicks) / NULLIF(SUM(d.impressions), 0),
            0
        ) AS ctr
    FROM daily_campaign_metrics d
    JOIN campaigns c
        ON d.campaign_id = c.campaign_id
    GROUP BY
        d.metric_date,
        d.campaign_id,
        c.campaign_name
),
ctr_with_previous AS (
    SELECT
        metric_date,
        campaign_id,
        campaign_name,
        impressions,
        clicks,
        ctr,
        LAG(ctr) OVER (
            PARTITION BY campaign_id
            ORDER BY metric_date
        ) AS previous_ctr
    FROM daily_ctr
)
SELECT
    'performance' AS alert_type,
    'high' AS severity,
    'campaign' AS entity_type,
    CAST(campaign_id AS CHAR) AS entity_id,
    CONCAT(
        '[Generated Monitoring] Campaign ',
        campaign_id,
        ' - ',
        campaign_name,
        ' CTR dropped by ',
        ROUND((previous_ctr - ctr) / NULLIF(previous_ctr, 0) * 100, 2),
        '% on ',
        metric_date,
        '. Previous CTR: ',
        ROUND(previous_ctr, 4),
        ', Current CTR: ',
        ROUND(ctr, 4),
        '.'
    ) AS alert_message
FROM ctr_with_previous
WHERE
    previous_ctr IS NOT NULL
    AND previous_ctr > 0
    AND impressions >= 20
    AND (previous_ctr - ctr) / NULLIF(previous_ctr, 0) >= 0.30;


-- =====================================================
-- Step 9G: Experiment monitoring alert
-- Variant B improves engagement, but profit improvement is weak.
-- =====================================================

INSERT INTO alerts (
    alert_type,
    severity,
    entity_type,
    entity_id,
    alert_message
)
SELECT
    'experiment' AS alert_type,
    'medium' AS severity,
    'experiment' AS entity_type,
    b.variant AS entity_id,
    CONCAT(
        '[Experiment Monitoring] Variant B improved CTR by ',
        ROUND((b.ctr - a.ctr) / NULLIF(a.ctr, 0) * 100, 2),
        '%, install rate by ',
        ROUND((b.install_rate - a.install_rate) / NULLIF(a.install_rate, 0) * 100, 2),
        '%, and conversion rate by ',
        ROUND((b.conversion_rate - a.conversion_rate) / NULLIF(a.conversion_rate, 0) * 100, 2),
        '%, but profit delta is only ',
        ROUND(b.profit - a.profit, 2),
        '. Review whether the higher spend is justified.'
    ) AS alert_message
FROM experiment_results a
JOIN experiment_results b
    ON a.experiment_name = b.experiment_name
WHERE a.variant = 'A'
  AND b.variant = 'B'
  AND b.ctr > a.ctr
  AND b.install_rate > a.install_rate
  AND (b.profit - a.profit) < 50;


-- =====================================================
-- Step 9H: Test generated monitoring alerts
-- =====================================================

SELECT
    alert_id,
    alert_type,
    severity,
    entity_type,
    entity_id,
    alert_message,
    detected_at,
    is_resolved
FROM alerts
WHERE alert_message LIKE '[Generated Monitoring]%'
   OR alert_message LIKE '[Experiment Monitoring]%'
ORDER BY
    CASE severity
        WHEN 'high' THEN 1
        WHEN 'medium' THEN 2
        WHEN 'low' THEN 3
    END,
    alert_type,
    entity_type,
    entity_id;