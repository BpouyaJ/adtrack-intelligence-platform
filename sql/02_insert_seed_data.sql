USE adtrack_intelligence;

-- =========================
-- Clean old seed data if script is re-run
-- =========================
SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE alerts;
TRUNCATE TABLE daily_app_metrics;
TRUNCATE TABLE daily_campaign_metrics;
TRUNCATE TABLE events_clean;
TRUNCATE TABLE events_raw;
TRUNCATE TABLE ad_requests;
TRUNCATE TABLE experiments;
TRUNCATE TABLE users;
TRUNCATE TABLE campaigns;
TRUNCATE TABLE advertisers;
TRUNCATE TABLE apps;
TRUNCATE TABLE publishers;

SET FOREIGN_KEY_CHECKS = 1;

-- =========================
-- 1. Publishers
-- Mobile game studios / app owners
-- =========================
INSERT INTO publishers (publisher_id, publisher_name, country) VALUES
(1, 'PixelForge Games', 'DE'),
(2, 'Nordic Play Studio', 'SE'),
(3, 'UrbanTap Games', 'US'),
(4, 'LuckyFox Interactive', 'GB'),
(5, 'BlueRocket Mobile', 'AT');

-- =========================
-- 2. Apps / Games
-- Games where rewarded ads are shown
-- =========================
INSERT INTO apps (app_id, publisher_id, app_name, category, platform, country) VALUES
(1, 1, 'Puzzle Kingdom', 'puzzle', 'android', 'DE'),
(2, 1, 'Puzzle Kingdom iOS', 'puzzle', 'ios', 'DE'),
(3, 2, 'Battle Islands', 'strategy', 'android', 'SE'),
(4, 2, 'Battle Islands iOS', 'strategy', 'ios', 'SE'),
(5, 3, 'Rocket Runner', 'arcade', 'android', 'US'),
(6, 3, 'Rocket Runner iOS', 'arcade', 'ios', 'US'),
(7, 4, 'Lucky Slots', 'casino', 'android', 'GB'),
(8, 4, 'Lucky Slots iOS', 'casino', 'ios', 'GB'),
(9, 5, 'City Builder Pro', 'simulation', 'android', 'AT'),
(10, 5, 'City Builder Pro iOS', 'simulation', 'ios', 'AT');

-- =========================
-- 3. Advertisers
-- Companies paying for installs/conversions
-- =========================
INSERT INTO advertisers (advertiser_id, advertiser_name, industry) VALUES
(1, 'FastFood Hero', 'food_delivery'),
(2, 'FitLife App', 'health_fitness'),
(3, 'CryptoLearn', 'education'),
(4, 'ShopNow Mobile', 'ecommerce'),
(5, 'TravelBuddy', 'travel'),
(6, 'MegaGame Studio', 'gaming');

-- =========================
-- 4. Campaigns
-- Ad campaigns with country/platform/category targeting
-- bid_cpi means cost per install
-- =========================
INSERT INTO campaigns (
    campaign_id,
    advertiser_id,
    campaign_name,
    target_country,
    target_platform,
    target_category,
    bid_cpi,
    daily_budget,
    status
) VALUES
(1, 1, 'FastFood Germany Android Puzzle', 'DE', 'android', 'puzzle', 2.40, 5000.00, 'active'),
(2, 1, 'FastFood Germany iOS Puzzle', 'DE', 'ios', 'puzzle', 3.10, 4500.00, 'active'),

(3, 2, 'FitLife Sweden Android Strategy', 'SE', 'android', 'strategy', 2.80, 4000.00, 'active'),
(4, 2, 'FitLife Sweden iOS Strategy', 'SE', 'ios', 'strategy', 3.40, 4200.00, 'active'),

(5, 3, 'CryptoLearn US Android Arcade', 'US', 'android', 'arcade', 4.20, 7000.00, 'active'),
(6, 3, 'CryptoLearn US iOS Arcade', 'US', 'ios', 'arcade', 4.80, 6500.00, 'active'),

(7, 4, 'ShopNow UK Android Casino', 'GB', 'android', 'casino', 2.70, 3500.00, 'active'),
(8, 4, 'ShopNow UK iOS Casino', 'GB', 'ios', 'casino', 3.30, 3600.00, 'paused'),

(9, 5, 'TravelBuddy Austria Android Simulation', 'AT', 'android', 'simulation', 2.20, 3000.00, 'active'),
(10, 5, 'TravelBuddy Austria iOS Simulation', 'AT', 'ios', 'simulation', 2.90, 3200.00, 'active'),

(11, 6, 'MegaGame Germany Android Puzzle Retargeting', 'DE', 'android', 'puzzle', 3.60, 8000.00, 'active'),
(12, 6, 'MegaGame US iOS Arcade High Value', 'US', 'ios', 'arcade', 5.20, 9000.00, 'active');

-- =========================
-- 5. Users
-- Simulated users
-- Later Python will generate more, but this is enough for testing
-- =========================
INSERT INTO users (user_id, country, platform, device_type) VALUES
(1, 'DE', 'android', 'Samsung Galaxy S22'),
(2, 'DE', 'android', 'Google Pixel 7'),
(3, 'DE', 'ios', 'iPhone 13'),
(4, 'DE', 'ios', 'iPhone 14'),

(5, 'SE', 'android', 'Samsung Galaxy A54'),
(6, 'SE', 'android', 'OnePlus 11'),
(7, 'SE', 'ios', 'iPhone 12'),
(8, 'SE', 'ios', 'iPhone 15'),

(9, 'US', 'android', 'Google Pixel 8'),
(10, 'US', 'android', 'Samsung Galaxy S23'),
(11, 'US', 'ios', 'iPhone 14 Pro'),
(12, 'US', 'ios', 'iPhone 15 Pro'),

(13, 'GB', 'android', 'Samsung Galaxy S21'),
(14, 'GB', 'android', 'Xiaomi 13'),
(15, 'GB', 'ios', 'iPhone 13 Pro'),
(16, 'GB', 'ios', 'iPhone 14'),

(17, 'AT', 'android', 'Samsung Galaxy A53'),
(18, 'AT', 'android', 'Google Pixel 6'),
(19, 'AT', 'ios', 'iPhone 12 Pro'),
(20, 'AT', 'ios', 'iPhone 15'),

-- Extra users for mismatch/anomaly testing later
(21, 'FR', 'android', 'Samsung Galaxy S20'),
(22, 'FR', 'ios', 'iPhone 11'),
(23, 'TR', 'android', 'Xiaomi Redmi Note 12'),
(24, 'TR', 'ios', 'iPhone 13');

-- =========================
-- 6. Experiments
-- A/B test for ad delivery algorithm
-- Variant A = baseline
-- Variant B = optimized
-- =========================
INSERT INTO experiments (
    experiment_id,
    experiment_name,
    variant,
    algorithm_name,
    start_date,
    end_date
) VALUES
(1, 'Ad Delivery Algorithm Test', 'A', 'baseline_bid_priority', '2026-06-01', '2026-06-30'),
(2, 'Ad Delivery Algorithm Test', 'B', 'optimized_profit_score', '2026-06-01', '2026-06-30');