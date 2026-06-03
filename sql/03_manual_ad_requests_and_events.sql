USE adtrack_intelligence;

-- =========================
-- Clean previous manual test data if this script is re-run
-- =========================
SET SQL_SAFE_UPDATES = 0;

DELETE FROM events_raw
WHERE event_id LIKE 'manual_%'
   OR tracking_id LIKE 'trk_manual_%';

DELETE FROM ad_requests
WHERE tracking_id LIKE 'trk_manual_%';

SET SQL_SAFE_UPDATES = 1;

-- =========================
-- 1. Manual Ad Requests
-- Each ad request represents one user opening an app and receiving a selected campaign.
-- tracking_id connects the request to later events.
-- =========================

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
-- Valid German Android puzzle request
('trk_manual_001', 1, 1, 1, 1, '2026-06-01 10:00:00', 'DE', 'android'),

-- Valid German iOS puzzle request
('trk_manual_002', 3, 2, 2, 1, '2026-06-01 10:05:00', 'DE', 'ios'),

-- Valid Sweden Android strategy request
('trk_manual_003', 5, 3, 3, 2, '2026-06-01 10:10:00', 'SE', 'android'),

-- Valid US iOS arcade request
('trk_manual_004', 11, 6, 12, 2, '2026-06-01 10:15:00', 'US', 'ios'),

-- Valid Austria Android simulation request
('trk_manual_005', 17, 9, 9, 1, '2026-06-01 10:20:00', 'AT', 'android'),

-- Valid UK Android casino request
('trk_manual_006', 13, 7, 7, 2, '2026-06-01 10:25:00', 'GB', 'android');


-- =========================
-- 2. Raw Events
-- These represent what happened after the ad request.
-- Some requests get only impressions.
-- Some get clicks.
-- Some get installs/conversions.
-- =========================

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

-- Tracking 001: full successful funnel
('manual_001_imp', 'trk_manual_001', 1, 1, 1, 'impression', '2026-06-01 10:00:02', 0.00, 0.00, 'DE', 'android'),
('manual_001_click', 'trk_manual_001', 1, 1, 1, 'click', '2026-06-01 10:00:10', 0.00, 0.00, 'DE', 'android'),
('manual_001_install', 'trk_manual_001', 1, 1, 1, 'install', '2026-06-01 10:04:30', 0.00, 0.00, 'DE', 'android'),
('manual_001_reward', 'trk_manual_001', 1, 1, 1, 'reward', '2026-06-01 10:04:40', 0.00, 0.50, 'DE', 'android'),
('manual_001_conversion', 'trk_manual_001', 1, 1, 1, 'conversion', '2026-06-01 10:20:00', 5.00, 0.00, 'DE', 'android'),

-- Tracking 002: impression + click, but no install
('manual_002_imp', 'trk_manual_002', 2, 2, 3, 'impression', '2026-06-01 10:05:02', 0.00, 0.00, 'DE', 'ios'),
('manual_002_click', 'trk_manual_002', 2, 2, 3, 'click', '2026-06-01 10:05:25', 0.00, 0.00, 'DE', 'ios'),

-- Tracking 003: impression only
('manual_003_imp', 'trk_manual_003', 3, 3, 5, 'impression', '2026-06-01 10:10:03', 0.00, 0.00, 'SE', 'android'),

-- Tracking 004: full funnel with high revenue
('manual_004_imp', 'trk_manual_004', 12, 6, 11, 'impression', '2026-06-01 10:15:01', 0.00, 0.00, 'US', 'ios'),
('manual_004_click', 'trk_manual_004', 12, 6, 11, 'click', '2026-06-01 10:15:15', 0.00, 0.00, 'US', 'ios'),
('manual_004_install', 'trk_manual_004', 12, 6, 11, 'install', '2026-06-01 10:19:00', 0.00, 0.00, 'US', 'ios'),
('manual_004_conversion', 'trk_manual_004', 12, 6, 11, 'conversion', '2026-06-01 10:45:00', 12.00, 0.00, 'US', 'ios'),

-- Tracking 005: impression + click + install + reward
('manual_005_imp', 'trk_manual_005', 9, 9, 17, 'impression', '2026-06-01 10:20:01', 0.00, 0.00, 'AT', 'android'),
('manual_005_click', 'trk_manual_005', 9, 9, 17, 'click', '2026-06-01 10:20:12', 0.00, 0.00, 'AT', 'android'),
('manual_005_install', 'trk_manual_005', 9, 9, 17, 'install', '2026-06-01 10:28:00', 0.00, 0.00, 'AT', 'android'),
('manual_005_reward', 'trk_manual_005', 9, 9, 17, 'reward', '2026-06-01 10:28:20', 0.00, 0.40, 'AT', 'android'),

-- Tracking 006: impression + click only
('manual_006_imp', 'trk_manual_006', 7, 7, 13, 'impression', '2026-06-01 10:25:02', 0.00, 0.00, 'GB', 'android'),
('manual_006_click', 'trk_manual_006', 7, 7, 13, 'click', '2026-06-01 10:25:30', 0.00, 0.00, 'GB', 'android');


-- =========================
-- 3. Test query: event funnel per tracking_id
-- =========================

SELECT
    tracking_id,
    SUM(CASE WHEN event_type = 'impression' THEN 1 ELSE 0 END) AS impressions,
    SUM(CASE WHEN event_type = 'click' THEN 1 ELSE 0 END) AS clicks,
    SUM(CASE WHEN event_type = 'install' THEN 1 ELSE 0 END) AS installs,
    SUM(CASE WHEN event_type = 'conversion' THEN 1 ELSE 0 END) AS conversions,
    SUM(CASE WHEN event_type = 'reward' THEN 1 ELSE 0 END) AS rewards,
    SUM(revenue) AS revenue,
    SUM(reward_cost) AS reward_cost
FROM events_raw
WHERE tracking_id LIKE 'trk_manual_%'
GROUP BY tracking_id
ORDER BY tracking_id;