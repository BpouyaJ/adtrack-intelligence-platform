import os
from pathlib import Path

import mysql.connector
import pandas as pd
import streamlit as st
from dotenv import load_dotenv


# =====================================================
# Database connection
# =====================================================

PROJECT_ROOT = Path(__file__).resolve().parents[1]
load_dotenv(PROJECT_ROOT / ".env")

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "user": os.getenv("DB_USER", "root"),
    "password": os.getenv("DB_PASSWORD"),
    "database": os.getenv("DB_NAME", "adtrack_intelligence"),
}


def get_connection():
    return mysql.connector.connect(**DB_CONFIG)


@st.cache_data
def run_query(query: str) -> pd.DataFrame:
    connection = get_connection()
    try:
        return pd.read_sql(query, connection)
    finally:
        connection.close()


# =====================================================
# Page setup
# =====================================================

st.set_page_config(
    page_title="AdTrack Intelligence Platform",
    layout="wide"
)

st.title("AdTrack Intelligence Platform")
st.caption(
    "SQL-first analytics and monitoring dashboard for simulated mobile ad delivery events."
)


# =====================================================
# Overview
# =====================================================

try:
    overview_query = """
    SELECT
        SUM(impressions) AS impressions,
        SUM(clicks) AS clicks,
        SUM(installs) AS installs,
        SUM(conversions) AS conversions,
        COALESCE(ROUND(SUM(clicks) / NULLIF(SUM(impressions), 0), 4), 0) AS ctr,
        COALESCE(ROUND(SUM(installs) / NULLIF(SUM(clicks), 0), 4), 0) AS install_rate,
        COALESCE(ROUND(SUM(conversions) / NULLIF(SUM(installs), 0), 4), 0) AS conversion_rate,
        ROUND(SUM(spend), 2) AS spend,
        ROUND(SUM(revenue), 2) AS revenue,
        ROUND(SUM(profit), 2) AS profit
    FROM daily_campaign_metrics;
    """

    overview = run_query(overview_query)

    if not overview.empty:
        row = overview.iloc[0]

        col1, col2, col3, col4, col5 = st.columns(5)
        col1.metric("Impressions", int(row["impressions"] or 0))
        col2.metric("Clicks", int(row["clicks"] or 0))
        col3.metric("Installs", int(row["installs"] or 0))
        col4.metric("Revenue", f"{row['revenue']:.2f}")
        col5.metric("Profit", f"{row['profit']:.2f}")

        col6, col7, col8 = st.columns(3)
        col6.metric("CTR", f"{row['ctr']:.2%}")
        col7.metric("Install Rate", f"{row['install_rate']:.2%}")
        col8.metric("Conversion Rate", f"{row['conversion_rate']:.2%}")

except Exception as error:
    st.error(f"Overview failed to load: {error}")


tab1, tab2, tab3, tab4, tab5 = st.tabs([
    "Campaign Performance",
    "App/Game Performance",
    "A/B Experiment",
    "Monitoring Alerts",
    "Validation Errors"
])


# =====================================================
# Campaign Performance
# =====================================================

with tab1:
    st.subheader("Campaign Performance")

    try:
        campaign_query = """
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
            COALESCE(ROUND(SUM(d.clicks) / NULLIF(SUM(d.impressions), 0), 4), 0) AS ctr,
            COALESCE(ROUND(SUM(d.installs) / NULLIF(SUM(d.clicks), 0), 4), 0) AS install_rate,
            COALESCE(ROUND(SUM(d.conversions) / NULLIF(SUM(d.installs), 0), 4), 0) AS conversion_rate,
            ROUND(SUM(d.spend), 2) AS spend,
            ROUND(SUM(d.revenue), 2) AS revenue,
            ROUND(SUM(d.profit), 2) AS profit,
            COALESCE(ROUND(SUM(d.revenue) / NULLIF(SUM(d.impressions), 0) * 1000, 2), 0) AS ecpm
        FROM daily_campaign_metrics d
        JOIN campaigns c
            ON d.campaign_id = c.campaign_id
        GROUP BY
            c.campaign_id,
            c.campaign_name,
            c.target_country,
            c.target_platform,
            c.target_category
        ORDER BY profit DESC;
        """

        campaign_df = run_query(campaign_query)
        st.dataframe(campaign_df, use_container_width=True)

        if not campaign_df.empty:
            chart_df = campaign_df.set_index("campaign_name")[["revenue", "spend", "profit"]]
            st.bar_chart(chart_df)

    except Exception as error:
        st.error(f"Campaign Performance failed to load: {error}")


# =====================================================
# App/Game Performance
# =====================================================

with tab2:
    st.subheader("App/Game Performance")

    try:
        app_query = """
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
            COALESCE(ROUND(SUM(d.clicks) / NULLIF(SUM(d.impressions), 0), 4), 0) AS ctr,
            COALESCE(ROUND(SUM(d.installs) / NULLIF(SUM(d.clicks), 0), 4), 0) AS install_rate,
            ROUND(SUM(d.revenue), 2) AS revenue,
            ROUND(SUM(d.reward_cost), 2) AS reward_cost
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
        ORDER BY revenue DESC;
        """

        app_df = run_query(app_query)
        st.dataframe(app_df, use_container_width=True)

        if not app_df.empty:
            chart_df = app_df.set_index("app_name")[["revenue", "reward_cost"]]
            st.bar_chart(chart_df)

    except Exception as error:
        st.error(f"App/Game Performance failed to load: {error}")


# =====================================================
# A/B Experiment
# =====================================================

with tab3:
    st.subheader("A/B Experiment Results")

    try:
        experiment_query = """
        SELECT
            variant,
            algorithm_name,
            ad_requests,
            impressions,
            clicks,
            installs,
            conversions,
            ctr,
            install_rate,
            conversion_rate,
            spend,
            revenue,
            reward_cost,
            profit,
            ecpm
        FROM experiment_results
        ORDER BY variant;
        """

        experiment_df = run_query(experiment_query)
        st.dataframe(experiment_df, use_container_width=True)

        uplift_query = """
        SELECT
            a.variant AS baseline_variant,
            b.variant AS test_variant,
            a.algorithm_name AS baseline_algorithm,
            b.algorithm_name AS test_algorithm,
            ROUND((b.ctr - a.ctr) / NULLIF(a.ctr, 0) * 100, 2) AS ctr_lift_percent,
            ROUND((b.install_rate - a.install_rate) / NULLIF(a.install_rate, 0) * 100, 2) AS install_rate_lift_percent,
            ROUND((b.conversion_rate - a.conversion_rate) / NULLIF(a.conversion_rate, 0) * 100, 2) AS conversion_rate_lift_percent,
            ROUND(b.revenue - a.revenue, 2) AS revenue_delta,
            ROUND(b.spend - a.spend, 2) AS spend_delta,
            ROUND(b.profit - a.profit, 2) AS profit_delta,
            ROUND(b.ecpm - a.ecpm, 2) AS ecpm_delta
        FROM experiment_results a
        JOIN experiment_results b
            ON a.experiment_name = b.experiment_name
        WHERE a.variant = 'A'
          AND b.variant = 'B';
        """

        uplift_df = run_query(uplift_query)

        if not uplift_df.empty:
            st.subheader("Variant B Uplift vs Variant A")
            st.dataframe(uplift_df, use_container_width=True)

            uplift = uplift_df.iloc[0]
            st.info(
                f"Variant B improved CTR by {uplift['ctr_lift_percent']}%, "
                f"install rate by {uplift['install_rate_lift_percent']}%, "
                f"conversion rate by {uplift['conversion_rate_lift_percent']}%, "
                f"with a profit delta of {uplift['profit_delta']}."
            )

    except Exception as error:
        st.error(f"A/B Experiment failed to load: {error}")


# =====================================================
# Monitoring Alerts
# =====================================================

with tab4:
    st.subheader("Monitoring Alerts")

    try:
        alerts_query = """
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
            detected_at DESC;
        """

        alerts_df = run_query(alerts_query)
        st.dataframe(alerts_df, use_container_width=True)

        if not alerts_df.empty:
            summary_df = (
                alerts_df.groupby(["alert_type", "severity"])
                .size()
                .reset_index(name="alert_count")
            )

            st.subheader("Alert Summary")
            st.dataframe(summary_df, use_container_width=True)

    except Exception as error:
        st.error(f"Monitoring Alerts failed to load: {error}")


# =====================================================
# Validation Errors
# =====================================================

with tab5:
    st.subheader("Event Validation Errors")

    try:
        validation_summary_query = """
        SELECT
            error_type,
            COUNT(*) AS error_count
        FROM event_validation_errors
        GROUP BY error_type
        ORDER BY error_count DESC;
        """

        validation_summary_df = run_query(validation_summary_query)
        st.dataframe(validation_summary_df, use_container_width=True)

        validation_detail_query = """
        SELECT
            validation_error_id,
            raw_event_id,
            event_id,
            tracking_id,
            error_type,
            error_message,
            detected_at
        FROM event_validation_errors
        ORDER BY detected_at DESC;
        """

        validation_detail_df = run_query(validation_detail_query)

        st.subheader("Rejected Raw Events")
        st.dataframe(validation_detail_df, use_container_width=True)

    except Exception as error:
        st.error(f"Validation Errors failed to load: {error}")