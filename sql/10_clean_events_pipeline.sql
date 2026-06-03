USE adtrack_intelligence;

-- =====================================================
-- Step 10A: Create validation error table
-- Stores rejected raw events and the reason why they were rejected.
-- =====================================================

CREATE TABLE IF NOT EXISTS event_validation_errors (
    validation_error_id INT AUTO_INCREMENT PRIMARY KEY,
    raw_event_id INT NOT NULL,
    event_id VARCHAR(100),
    tracking_id VARCHAR(100),
    error_type VARCHAR(100) NOT NULL,
    error_message TEXT NOT NULL,
    detected_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (raw_event_id) REFERENCES events_raw(raw_event_id)
);


-- =====================================================
-- Step 10B: Reset clean pipeline outputs
-- This does NOT delete raw events.
-- =====================================================

TRUNCATE TABLE events_clean;
TRUNCATE TABLE event_validation_errors;


-- =====================================================
-- Step 10C: Store validation errors
-- =====================================================

-- 1. Missing tracking_id
INSERT INTO event_validation_errors (
    raw_event_id,
    event_id,
    tracking_id,
    error_type,
    error_message
)
SELECT
    raw_event_id,
    event_id,
    tracking_id,
    'missing_tracking_id',
    CONCAT('Raw event ', event_id, ' has no tracking_id.')
FROM events_raw
WHERE tracking_id IS NULL;


-- 2. Unknown tracking_id
INSERT INTO event_validation_errors (
    raw_event_id,
    event_id,
    tracking_id,
    error_type,
    error_message
)
SELECT
    er.raw_event_id,
    er.event_id,
    er.tracking_id,
    'unknown_tracking_id',
    CONCAT('Raw event ', er.event_id, ' references unknown tracking_id: ', er.tracking_id)
FROM events_raw er
LEFT JOIN ad_requests ar
    ON er.tracking_id = ar.tracking_id
WHERE er.tracking_id IS NOT NULL
  AND ar.tracking_id IS NULL;


-- 3. Duplicate event_id
INSERT INTO event_validation_errors (
    raw_event_id,
    event_id,
    tracking_id,
    error_type,
    error_message
)
SELECT
    er.raw_event_id,
    er.event_id,
    er.tracking_id,
    'duplicate_event_id',
    CONCAT('Raw event_id ', er.event_id, ' appears multiple times in events_raw.')
FROM events_raw er
JOIN (
    SELECT event_id
    FROM events_raw
    GROUP BY event_id
    HAVING COUNT(*) > 1
) dup
    ON er.event_id = dup.event_id;


-- 4. Campaign mismatch between raw event and ad request
INSERT INTO event_validation_errors (
    raw_event_id,
    event_id,
    tracking_id,
    error_type,
    error_message
)
SELECT
    er.raw_event_id,
    er.event_id,
    er.tracking_id,
    'campaign_mismatch',
    CONCAT(
        'Raw event ',
        er.event_id,
        ' campaign_id ',
        er.campaign_id,
        ' does not match ad request campaign_id ',
        ar.campaign_id,
        '.'
    )
FROM events_raw er
JOIN ad_requests ar
    ON er.tracking_id = ar.tracking_id
WHERE er.campaign_id IS NULL
   OR er.campaign_id <> ar.campaign_id;


-- 5. App mismatch between raw event and ad request
INSERT INTO event_validation_errors (
    raw_event_id,
    event_id,
    tracking_id,
    error_type,
    error_message
)
SELECT
    er.raw_event_id,
    er.event_id,
    er.tracking_id,
    'app_mismatch',
    CONCAT(
        'Raw event ',
        er.event_id,
        ' app_id ',
        er.app_id,
        ' does not match ad request app_id ',
        ar.app_id,
        '.'
    )
FROM events_raw er
JOIN ad_requests ar
    ON er.tracking_id = ar.tracking_id
WHERE er.app_id IS NULL
   OR er.app_id <> ar.app_id;


-- 6. User mismatch between raw event and ad request
INSERT INTO event_validation_errors (
    raw_event_id,
    event_id,
    tracking_id,
    error_type,
    error_message
)
SELECT
    er.raw_event_id,
    er.event_id,
    er.tracking_id,
    'user_mismatch',
    CONCAT(
        'Raw event ',
        er.event_id,
        ' user_id ',
        er.user_id,
        ' does not match ad request user_id ',
        ar.user_id,
        '.'
    )
FROM events_raw er
JOIN ad_requests ar
    ON er.tracking_id = ar.tracking_id
WHERE er.user_id IS NULL
   OR er.user_id <> ar.user_id;


-- 7. Country mismatch between raw event and ad request
INSERT INTO event_validation_errors (
    raw_event_id,
    event_id,
    tracking_id,
    error_type,
    error_message
)
SELECT
    er.raw_event_id,
    er.event_id,
    er.tracking_id,
    'country_mismatch',
    CONCAT(
        'Raw event ',
        er.event_id,
        ' country ',
        er.country,
        ' does not match ad request country ',
        ar.country,
        '.'
    )
FROM events_raw er
JOIN ad_requests ar
    ON er.tracking_id = ar.tracking_id
WHERE er.country IS NULL
   OR er.country <> ar.country;


-- 8. Platform mismatch between raw event and ad request
INSERT INTO event_validation_errors (
    raw_event_id,
    event_id,
    tracking_id,
    error_type,
    error_message
)
SELECT
    er.raw_event_id,
    er.event_id,
    er.tracking_id,
    'platform_mismatch',
    CONCAT(
        'Raw event ',
        er.event_id,
        ' platform ',
        er.platform,
        ' does not match ad request platform ',
        ar.platform,
        '.'
    )
FROM events_raw er
JOIN ad_requests ar
    ON er.tracking_id = ar.tracking_id
WHERE er.platform IS NULL
   OR er.platform <> ar.platform;


-- =====================================================
-- Step 10D: Insert valid events into events_clean
-- A valid event must:
-- 1. have a tracking_id
-- 2. reference an existing ad_request
-- 3. have a unique event_id
-- 4. match the campaign/app/user/country/platform of the ad_request
-- =====================================================

INSERT INTO events_clean (
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
)
SELECT
    er.event_id,
    er.tracking_id,
    er.campaign_id,
    er.app_id,
    er.user_id,
    er.event_type,
    er.event_time,
    COALESCE(er.revenue, 0.00) AS revenue,
    COALESCE(er.reward_cost, 0.00) AS reward_cost,
    er.country,
    er.platform
FROM events_raw er
JOIN ad_requests ar
    ON er.tracking_id = ar.tracking_id
WHERE er.raw_event_id NOT IN (
    SELECT DISTINCT raw_event_id
    FROM event_validation_errors
);


-- =====================================================
-- Step 10E: Pipeline health checks
-- =====================================================

-- Raw vs clean vs rejected count
SELECT
    (SELECT COUNT(*) FROM events_raw) AS raw_events,
    (SELECT COUNT(*) FROM events_clean) AS clean_events,
    (SELECT COUNT(DISTINCT raw_event_id) FROM event_validation_errors) AS rejected_raw_events;


-- Validation error summary
SELECT
    error_type,
    COUNT(*) AS error_count
FROM event_validation_errors
GROUP BY error_type
ORDER BY error_count DESC;


-- Clean event distribution
SELECT
    event_type,
    COUNT(*) AS clean_event_count
FROM events_clean
GROUP BY event_type
ORDER BY clean_event_count DESC;


-- Safety check: should return 0 rows
SELECT
    event_id,
    COUNT(*) AS duplicate_count
FROM events_clean
GROUP BY event_id
HAVING COUNT(*) > 1;


-- Safety check: should return 0 rows
SELECT
    ec.clean_event_id,
    ec.event_id,
    ec.tracking_id
FROM events_clean ec
LEFT JOIN ad_requests ar
    ON ec.tracking_id = ar.tracking_id
WHERE ar.tracking_id IS NULL;