import os
import random
import uuid
from datetime import datetime, timedelta

import mysql.connector
from dotenv import load_dotenv


load_dotenv()


DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "user": os.getenv("DB_USER", "root"),
    "password": os.getenv("DB_PASSWORD"),
    "database": os.getenv("DB_NAME", "adtrack_intelligence"),
}


NUM_AD_REQUESTS = 5000
START_TIME = datetime(2026, 6, 1, 0, 0, 0)
DAYS_TO_SIMULATE = 7


def get_connection():
    return mysql.connector.connect(**DB_CONFIG)


def fetch_seed_data(cursor):
    cursor.execute("""
        SELECT campaign_id, target_country, target_platform, target_category, bid_cpi, status
        FROM campaigns
        WHERE status = 'active'
    """)
    campaigns = cursor.fetchall()

    cursor.execute("""
        SELECT app_id, category, platform, country
        FROM apps
    """)
    apps = cursor.fetchall()

    cursor.execute("""
        SELECT user_id, country, platform
        FROM users
    """)
    users = cursor.fetchall()

    cursor.execute("""
        SELECT experiment_id, variant, algorithm_name
        FROM experiments
    """)
    experiments = cursor.fetchall()

    return campaigns, apps, users, experiments


def choose_matching_app(campaign, apps):
    campaign_id, country, platform, category, bid_cpi, status = campaign

    matching_apps = [
        app for app in apps
        if app[1] == category and app[2] == platform
    ]

    if not matching_apps:
        return None

    return random.choice(matching_apps)


def choose_matching_user(campaign, users):
    campaign_id, country, platform, category, bid_cpi, status = campaign

    matching_users = [
        user for user in users
        if user[1] == country and user[2] == platform
    ]

    if not matching_users:
        return None

    return random.choice(matching_users)


def event_probability_by_variant(variant):
    """
    Variant B is designed as an optimized delivery algorithm.
    It creates better engagement and post-install quality than Variant A.
    """
    if variant == "B":
        return {
            "impression": 0.98,
            "click": 0.28,
            "install": 0.35,
            "conversion": 0.32,
            "reward": 0.75,
        }

    return {
        "impression": 0.96,
        "click": 0.22,
        "install": 0.28,
        "conversion": 0.20,
        "reward": 0.70,
    }

def generate_conversion_revenue(campaign_id, bid_cpi, variant):
    """
    Generates more realistic post-install conversion revenue.

    Some campaigns are high-value and can become profitable.
    Others remain weaker, creating a realistic mix for analytics.
    Variant B receives a small quality boost.
    """
    high_value_campaigns = {
        5: (2.0, 5.5),    # CryptoLearn US Android Arcade
        6: (2.0, 5.5),    # CryptoLearn US iOS Arcade
        9: (3.0, 7.0),    # TravelBuddy Austria Android Simulation
        10: (3.0, 7.0),   # TravelBuddy Austria iOS Simulation
        12: (2.5, 6.5),   # MegaGame US iOS Arcade High Value
    }

    default_range = (1.3, 3.5)

    low_multiplier, high_multiplier = high_value_campaigns.get(
        campaign_id,
        default_range
    )

    variant_boost = 1.15 if variant == "B" else 1.00

    bid_cpi_float = float(bid_cpi)
    revenue = bid_cpi_float * random.uniform(low_multiplier, high_multiplier) * variant_boost

    return round(revenue, 2)

def generate_event_id(event_type):
    return f"py_{event_type}_{uuid.uuid4().hex}"


def insert_ad_request(cursor, tracking_id, user_id, app_id, campaign_id, experiment_id, request_time, country, platform):
    cursor.execute("""
        INSERT INTO ad_requests (
            tracking_id,
            user_id,
            app_id,
            campaign_id,
            experiment_id,
            request_time,
            country,
            platform
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
    """, (
        tracking_id,
        user_id,
        app_id,
        campaign_id,
        experiment_id,
        request_time,
        country,
        platform,
    ))


def insert_raw_event(cursor, event_id, tracking_id, campaign_id, app_id, user_id, event_type, event_time, revenue, reward_cost, country, platform):
    cursor.execute("""
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
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """, (
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
        platform,
    ))


def clean_generated_data(cursor):
    """
    Deletes only Python-generated data in the correct dependency order.

    Important:
    events_clean references ad_requests through tracking_id,
    so clean events must be deleted before generated ad_requests.
    """
    cursor.execute("SET SQL_SAFE_UPDATES = 0")

    # Delete validation errors connected to generated raw events, if they exist.
    # This prevents foreign key problems when deleting events_raw.
    cursor.execute("""
        DELETE eve
        FROM event_validation_errors eve
        JOIN events_raw er
            ON eve.raw_event_id = er.raw_event_id
        WHERE er.event_id LIKE 'py_%'
           OR er.tracking_id LIKE 'trk_py_%'
    """)

    # Delete generated clean events before deleting ad_requests.
    cursor.execute("""
        DELETE FROM events_clean
        WHERE event_id LIKE 'py_%'
           OR tracking_id LIKE 'trk_py_%'
    """)

    # Delete generated raw events.
    cursor.execute("""
        DELETE FROM events_raw
        WHERE event_id LIKE 'py_%'
           OR tracking_id LIKE 'trk_py_%'
    """)

    # Now it is safe to delete generated ad requests.
    cursor.execute("""
        DELETE FROM ad_requests
        WHERE tracking_id LIKE 'trk_py_%'
    """)

    cursor.execute("SET SQL_SAFE_UPDATES = 1")


def main():
    connection = get_connection()
    cursor = connection.cursor()

    print("Connected to database.")

    clean_generated_data(cursor)
    connection.commit()

    campaigns, apps, users, experiments = fetch_seed_data(cursor)

    if not campaigns or not apps or not users or not experiments:
        raise RuntimeError("Seed data is missing. Run Step 2 seed data script first.")

    inserted_requests = 0
    inserted_events = 0

    for _ in range(NUM_AD_REQUESTS):
        campaign = random.choice(campaigns)
        campaign_id, target_country, target_platform, target_category, bid_cpi, status = campaign

        app = choose_matching_app(campaign, apps)
        user = choose_matching_user(campaign, users)
        experiment = random.choice(experiments)

        if app is None or user is None:
            continue

        app_id = app[0]
        user_id = user[0]
        experiment_id = experiment[0]
        variant = experiment[1]

        tracking_id = f"trk_py_{uuid.uuid4().hex}"

        request_time = START_TIME + timedelta(
            days=random.randint(0, DAYS_TO_SIMULATE - 1),
            hours=random.randint(0, 23),
            minutes=random.randint(0, 59),
            seconds=random.randint(0, 59),
        )

        insert_ad_request(
            cursor,
            tracking_id,
            user_id,
            app_id,
            campaign_id,
            experiment_id,
            request_time,
            target_country,
            target_platform,
        )

        inserted_requests += 1

        probs = event_probability_by_variant(variant)

        # Impression normally happens shortly after request.
        if random.random() < probs["impression"]:
            impression_time = request_time + timedelta(seconds=random.randint(1, 5))

            insert_raw_event(
                cursor,
                generate_event_id("impression"),
                tracking_id,
                campaign_id,
                app_id,
                user_id,
                "impression",
                impression_time,
                0.00,
                0.00,
                target_country,
                target_platform,
            )
            inserted_events += 1

            # Click can happen only after impression.
            if random.random() < probs["click"]:
                click_time = impression_time + timedelta(seconds=random.randint(2, 60))

                insert_raw_event(
                    cursor,
                    generate_event_id("click"),
                    tracking_id,
                    campaign_id,
                    app_id,
                    user_id,
                    "click",
                    click_time,
                    0.00,
                    0.00,
                    target_country,
                    target_platform,
                )
                inserted_events += 1

                # Install can happen only after click.
                if random.random() < probs["install"]:
                    install_time = click_time + timedelta(minutes=random.randint(1, 30))

                    insert_raw_event(
                        cursor,
                        generate_event_id("install"),
                        tracking_id,
                        campaign_id,
                        app_id,
                        user_id,
                        "install",
                        install_time,
                        0.00,
                        0.00,
                        target_country,
                        target_platform,
                    )
                    inserted_events += 1

                    # Reward after valid install.
                    if random.random() < probs["reward"]:
                        reward_time = install_time + timedelta(seconds=random.randint(5, 60))
                        reward_cost = round(random.uniform(0.15, 0.45), 2)

                        insert_raw_event(
                            cursor,
                            generate_event_id("reward"),
                            tracking_id,
                            campaign_id,
                            app_id,
                            user_id,
                            "reward",
                            reward_time,
                            0.00,
                            reward_cost,
                            target_country,
                            target_platform,
                        )
                        inserted_events += 1

                    # Conversion after install.
                    if random.random() < probs["conversion"]:
                        conversion_time = install_time + timedelta(minutes=random.randint(10, 180))
                        revenue = generate_conversion_revenue(campaign_id, bid_cpi, variant)

                        insert_raw_event(
                            cursor,
                            generate_event_id("conversion"),
                            tracking_id,
                            campaign_id,
                            app_id,
                            user_id,
                            "conversion",
                            conversion_time,
                            revenue,
                            0.00,
                            target_country,
                            target_platform,
                        )
                        inserted_events += 1

    connection.commit()

    print(f"Inserted ad requests: {inserted_requests}")
    print(f"Inserted raw events: {inserted_events}")

    cursor.close()
    connection.close()

    print("Done.")


if __name__ == "__main__":
    main()