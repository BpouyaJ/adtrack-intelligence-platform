DROP DATABASE IF EXISTS adtrack_intelligence;
CREATE DATABASE adtrack_intelligence;
USE adtrack_intelligence;

-- =========================
-- 1. Publishers
-- These are companies/studios that own mobile games/apps.
-- =========================
CREATE TABLE publishers (
    publisher_id INT AUTO_INCREMENT PRIMARY KEY,
    publisher_name VARCHAR(100) NOT NULL,
    country VARCHAR(2) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- =========================
-- 2. Apps / Games
-- These are mobile games where ads are shown.
-- =========================
CREATE TABLE apps (
    app_id INT AUTO_INCREMENT PRIMARY KEY,
    publisher_id INT NOT NULL,
    app_name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    platform ENUM('android', 'ios') NOT NULL,
    country VARCHAR(2) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (publisher_id) REFERENCES publishers(publisher_id)
);

-- =========================
-- 3. Advertisers
-- These are companies that pay for user installs/conversions.
-- =========================
CREATE TABLE advertisers (
    advertiser_id INT AUTO_INCREMENT PRIMARY KEY,
    advertiser_name VARCHAR(100) NOT NULL,
    industry VARCHAR(50),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- =========================
-- 4. Campaigns
-- Campaigns define targeting and bid price.
-- bid_cpi = cost per install.
-- =========================
CREATE TABLE campaigns (
    campaign_id INT AUTO_INCREMENT PRIMARY KEY,
    advertiser_id INT NOT NULL,
    campaign_name VARCHAR(100) NOT NULL,
    target_country VARCHAR(2) NOT NULL,
    target_platform ENUM('android', 'ios') NOT NULL,
    target_category VARCHAR(50) NOT NULL,
    bid_cpi DECIMAL(10,2) NOT NULL,
    daily_budget DECIMAL(12,2) NOT NULL,
    status ENUM('active', 'paused') DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (advertiser_id) REFERENCES advertisers(advertiser_id)
);

-- =========================
-- 5. Users
-- Simulated users who interact with ads.
-- =========================
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    country VARCHAR(2) NOT NULL,
    platform ENUM('android', 'ios') NOT NULL,
    device_type VARCHAR(50),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- =========================
-- 6. Experiments
-- Used for A/B testing ad delivery algorithms.
-- =========================
CREATE TABLE experiments (
    experiment_id INT AUTO_INCREMENT PRIMARY KEY,
    experiment_name VARCHAR(100) NOT NULL,
    variant ENUM('A', 'B') NOT NULL,
    algorithm_name VARCHAR(100) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- =========================
-- 7. Ad Requests
-- One ad request happens when a user opens an app and the system selects a campaign.
-- tracking_id connects the ad request to later events.
-- =========================
CREATE TABLE ad_requests (
    ad_request_id INT AUTO_INCREMENT PRIMARY KEY,
    tracking_id VARCHAR(100) NOT NULL UNIQUE,
    user_id INT NOT NULL,
    app_id INT NOT NULL,
    campaign_id INT NOT NULL,
    experiment_id INT,
    request_time DATETIME NOT NULL,
    country VARCHAR(2) NOT NULL,
    platform ENUM('android', 'ios') NOT NULL,

    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (app_id) REFERENCES apps(app_id),
    FOREIGN KEY (campaign_id) REFERENCES campaigns(campaign_id),
    FOREIGN KEY (experiment_id) REFERENCES experiments(experiment_id)
);

-- =========================
-- 8. Raw Events
-- Raw event stream: impressions, clicks, installs, conversions, rewards.
-- This table intentionally allows some bad data so we can detect anomalies later.
-- =========================
CREATE TABLE events_raw (
    raw_event_id INT AUTO_INCREMENT PRIMARY KEY,
    event_id VARCHAR(100) NOT NULL,
    tracking_id VARCHAR(100),
    campaign_id INT,
    app_id INT,
    user_id INT,
    event_type ENUM('impression', 'click', 'install', 'conversion', 'reward') NOT NULL,
    event_time DATETIME NOT NULL,
    revenue DECIMAL(10,2) DEFAULT 0.00,
    reward_cost DECIMAL(10,2) DEFAULT 0.00,
    country VARCHAR(2),
    platform ENUM('android', 'ios'),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- =========================
-- 9. Clean Events
-- Later Python pipeline will validate raw events and insert only clean records here.
-- =========================
CREATE TABLE events_clean (
    clean_event_id INT AUTO_INCREMENT PRIMARY KEY,
    event_id VARCHAR(100) NOT NULL UNIQUE,
    tracking_id VARCHAR(100) NOT NULL,
    campaign_id INT NOT NULL,
    app_id INT NOT NULL,
    user_id INT NOT NULL,
    event_type ENUM('impression', 'click', 'install', 'conversion', 'reward') NOT NULL,
    event_time DATETIME NOT NULL,
    revenue DECIMAL(10,2) DEFAULT 0.00,
    reward_cost DECIMAL(10,2) DEFAULT 0.00,
    country VARCHAR(2) NOT NULL,
    platform ENUM('android', 'ios') NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (tracking_id) REFERENCES ad_requests(tracking_id),
    FOREIGN KEY (campaign_id) REFERENCES campaigns(campaign_id),
    FOREIGN KEY (app_id) REFERENCES apps(app_id),
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- =========================
-- 10. Daily Campaign Metrics
-- Reporting table for dashboard and analysis.
-- =========================
CREATE TABLE daily_campaign_metrics (
    metric_id INT AUTO_INCREMENT PRIMARY KEY,
    metric_date DATE NOT NULL,
    campaign_id INT NOT NULL,
    impressions INT DEFAULT 0,
    clicks INT DEFAULT 0,
    installs INT DEFAULT 0,
    conversions INT DEFAULT 0,
    rewards INT DEFAULT 0,
    ctr DECIMAL(10,4) DEFAULT 0.0000,
    install_rate DECIMAL(10,4) DEFAULT 0.0000,
    conversion_rate DECIMAL(10,4) DEFAULT 0.0000,
    spend DECIMAL(12,2) DEFAULT 0.00,
    revenue DECIMAL(12,2) DEFAULT 0.00,
    profit DECIMAL(12,2) DEFAULT 0.00,
    ecpm DECIMAL(12,2) DEFAULT 0.00,

    FOREIGN KEY (campaign_id) REFERENCES campaigns(campaign_id)
);

-- =========================
-- 11. Daily App Metrics
-- Reporting table for publisher/game performance.
-- =========================
CREATE TABLE daily_app_metrics (
    metric_id INT AUTO_INCREMENT PRIMARY KEY,
    metric_date DATE NOT NULL,
    app_id INT NOT NULL,
    impressions INT DEFAULT 0,
    clicks INT DEFAULT 0,
    installs INT DEFAULT 0,
    conversions INT DEFAULT 0,
    revenue DECIMAL(12,2) DEFAULT 0.00,
    reward_cost DECIMAL(12,2) DEFAULT 0.00,

    FOREIGN KEY (app_id) REFERENCES apps(app_id)
);

-- =========================
-- 12. Alerts
-- Stores data quality and performance problems.
-- =========================
CREATE TABLE alerts (
    alert_id INT AUTO_INCREMENT PRIMARY KEY,
    alert_type ENUM('data_quality', 'performance', 'experiment') NOT NULL,
    severity ENUM('low', 'medium', 'high') NOT NULL,
    entity_type ENUM('campaign', 'app', 'tracking_id', 'experiment', 'system') NOT NULL,
    entity_id VARCHAR(100),
    alert_message TEXT NOT NULL,
    detected_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    is_resolved BOOLEAN DEFAULT FALSE
);