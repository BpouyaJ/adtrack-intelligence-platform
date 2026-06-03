USE adtrack_intelligence;

-- =====================================================
-- Step 5A: Clean old anomaly test data if script is re-run
-- =====================================================

SET SQL_SAFE_UPDATES = 0;

DELETE FROM events_raw
WHERE event_id LIKE 'anomaly_%'
   OR tracking_id LIKE 'trk_anomaly_%'
   OR tracking_id = 'trk_unknown_999';

DELETE FROM ad_requests
WHERE tracking_id LIKE 'trk_anomaly_%';

TRUNCATE TABLE alerts;

SET SQL_SAFE_UPDATES = 1;


-- =====================================================
-- Step 5B: Insert intentional bad data for testing alerts
-- This simulates real production data problems.
-- =====================================================

-- Ad request that will have a click but no impression
INSERT INTO ad_requests (
    tracking_id,
    user_id,
    app_id,
    campaign_id,
    experiment_id,
    request_time,
    country,
    platform
) VALUES
('trk_anomaly_click_no_imp', 2, 1, 1, 1, '2026-06-01 11:00:00', 'DE', 'android');


INSERT INTO events_raw (
    event_id,
    tracking_id,
    campaign_id,
    app_id,
    user_id,
    event_type,
    event_time,
    revenue,
    reward_cost,
    country,
    platform
) VALUES

-- 1. Missing tracking_id
('anomaly_missing_tracking', NULL, 1, 1, 1, 'click', '2026-06-01 11:01:00', 0.00, 0.00, 'DE', 'android'),

-- 2. Unknown tracking_id that does not exist in ad_requests
('anomaly_unknown_tracking', 'trk_unknown_999', 1, 1, 1, 'install', '2026-06-01 11:02:00', 0.00, 0.00, 'DE', 'android'),

-- 3. Duplicate raw event_id
('anomaly_duplicate_event', 'trk_manual_001', 1, 1, 1, 'install', '2026-06-01 11:03:00', 0.00, 0.00, 'DE', 'android'),
('anomaly_duplicate_event', 'trk_manual_001', 1, 1, 1, 'install', '2026-06-01 11:03:05', 0.00, 0.00, 'DE', 'android'),

-- 4. Country mismatch
-- Campaign 1 targets DE, but this event says FR.
('anomaly_country_mismatch', 'trk_manual_001', 1, 1, 1, 'click', '2026-06-01 11:04:00', 0.00, 0.00, 'FR', 'android'),

-- 5. Platform mismatch
-- Campaign 2 targets iOS, but this event says Android.
('anomaly_platform_mismatch', 'trk_manual_002', 2, 2, 3, 'click', '2026-06-01 11:05:00', 0.00, 0.00, 'DE', 'android'),

-- 6. Click without impression
('anomaly_click_without_impression', 'trk_anomaly_click_no_imp', 1, 1, 2, 'click', '2026-06-01 11:06:00', 0.00, 0.00, 'DE', 'android');


-- =====================================================
-- Step 5C: Alert 1 - Missing or unknown tracking_id
-- =====================================================

INSERT INTO alerts (
    alert_type,
    severity,
    entity_type,
    entity_id,
    alert_message
)
SELECT
    'data_quality' AS alert_type,
    'high' AS severity,
    'tracking_id' AS entity_type,
    COALESCE(er.tracking_id, 'NULL') AS entity_id,
    CONCAT(
        'Event ',
        er.event_id,
        ' has missing or unknown tracking_id: ',
        COALESCE(er.tracking_id, 'NULL')
    ) AS alert_message
FROM events_raw er
LEFT JOIN ad_requests ar
    ON er.tracking_id = ar.tracking_id
WHERE er.tracking_id IS NULL
   OR ar.tracking_id IS NULL;


-- =====================================================
-- Step 5D: Alert 2 - Duplicate event_id in raw events
-- =====================================================

INSERT INTO alerts (
    alert_type,
    severity,
    entity_type,
    entity_id,
    alert_message
)
SELECT
    'data_quality' AS alert_type,
    'high' AS severity,
    'system' AS entity_type,
    event_id AS entity_id,
    CONCAT(
        'Duplicate event_id detected: ',
        event_id,
        ' appears ',
        COUNT(*),
        ' times in events_raw.'
    ) AS alert_message
FROM events_raw
GROUP BY event_id
HAVING COUNT(*) > 1;


-- =====================================================
-- Step 5E: Alert 3 - Duplicate installs for same tracking_id
-- In most CPI attribution systems, one tracking_id should not create multiple installs.
-- =====================================================

INSERT INTO alerts (
    alert_type,
    severity,
    entity_type,
    entity_id,
    alert_message
)
SELECT
    'data_quality' AS alert_type,
    'high' AS severity,
    'tracking_id' AS entity_type,
    tracking_id AS entity_id,
    CONCAT(
        'Duplicate install problem: tracking_id ',
        tracking_id,
        ' has ',
        COUNT(*),
        ' install events.'
    ) AS alert_message
FROM events_raw
WHERE event_type = 'install'
  AND tracking_id IS NOT NULL
GROUP BY tracking_id
HAVING COUNT(*) > 1;


-- =====================================================
-- Step 5F: Alert 4 - Clicks without impressions
-- A user should normally see an ad before clicking it.
-- =====================================================

INSERT INTO alerts (
    alert_type,
    severity,
    entity_type,
    entity_id,
    alert_message
)
SELECT
    'data_quality' AS alert_type,
    'medium' AS severity,
    'tracking_id' AS entity_type,
    tracking_id AS entity_id,
    CONCAT(
        'Funnel issue: tracking_id ',
        tracking_id,
        ' has clicks but no impressions.'
    ) AS alert_message
FROM events_raw
WHERE tracking_id IS NOT NULL
GROUP BY tracking_id
HAVING
    SUM(CASE WHEN event_type = 'click' THEN 1 ELSE 0 END) > 0
    AND
    SUM(CASE WHEN event_type = 'impression' THEN 1 ELSE 0 END) = 0;


-- =====================================================
-- Step 5G: Alert 5 - Installs without clicks
-- Usually an install should be preceded by a click.
-- =====================================================

INSERT INTO alerts (
    alert_type,
    severity,
    entity_type,
    entity_id,
    alert_message
)
SELECT
    'data_quality' AS alert_type,
    'medium' AS severity,
    'tracking_id' AS entity_type,
    tracking_id AS entity_id,
    CONCAT(
        'Attribution issue: tracking_id ',
        tracking_id,
        ' has installs but no clicks.'
    ) AS alert_message
FROM events_raw
WHERE tracking_id IS NOT NULL
GROUP BY tracking_id
HAVING
    SUM(CASE WHEN event_type = 'install' THEN 1 ELSE 0 END) > 0
    AND
    SUM(CASE WHEN event_type = 'click' THEN 1 ELSE 0 END) = 0;


-- =====================================================
-- Step 5H: Alert 6 - Country or platform mismatch
-- Event country/platform should match campaign targeting.
-- =====================================================

INSERT INTO alerts (
    alert_type,
    severity,
    entity_type,
    entity_id,
    alert_message
)
SELECT
    'data_quality' AS alert_type,
    'medium' AS severity,
    'campaign' AS entity_type,
    CAST(er.campaign_id AS CHAR) AS entity_id,
    CONCAT(
        'Targeting mismatch for event ',
        er.event_id,
        ': campaign targets ',
        c.target_country,
        '/',
        c.target_platform,
        ' but event has ',
        er.country,
        '/',
        er.platform,
        '.'
    ) AS alert_message
FROM events_raw er
JOIN campaigns c
    ON er.campaign_id = c.campaign_id
WHERE
    er.country IS NOT NULL
    AND er.platform IS NOT NULL
    AND (
        er.country <> c.target_country
        OR er.platform <> c.target_platform
    );


-- =====================================================
-- Step 5I: Alert 7 - Campaigns with clicks but no installs
-- This is not always a data bug, but it is a performance warning.
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
    'low' AS severity,
    'campaign' AS entity_type,
    CAST(campaign_id AS CHAR) AS entity_id,
    CONCAT(
        'Campaign ',
        campaign_id,
        ' has ',
        SUM(CASE WHEN event_type = 'click' THEN 1 ELSE 0 END),
        ' clicks but zero installs.'
    ) AS alert_message
FROM events_raw
WHERE campaign_id IS NOT NULL
GROUP BY campaign_id
HAVING
    SUM(CASE WHEN event_type = 'click' THEN 1 ELSE 0 END) > 0
    AND
    SUM(CASE WHEN event_type = 'install' THEN 1 ELSE 0 END) = 0;


-- =====================================================
-- Step 5J: Test alerts
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
ORDER BY
    CASE severity
        WHEN 'high' THEN 1
        WHEN 'medium' THEN 2
        WHEN 'low' THEN 3
    END,
    alert_id;