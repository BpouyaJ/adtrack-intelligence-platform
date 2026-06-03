\# AdTrack Intelligence Platform



SQL-first analytics and monitoring platform for simulated mobile ad delivery events.



\## Overview



AdTrack Intelligence Platform is a portfolio project that simulates a mobile advertising analytics system. It models ad delivery events such as ad requests, impressions, clicks, installs, rewards, and conversions, then processes them through a SQL and Python-based analytics pipeline.



The project focuses on the type of work performed in advertising analytics teams: event tracking, campaign performance analysis, data quality validation, A/B experiment evaluation, monitoring alerts, and dashboard reporting.


## Project Highlights

- Generated 5,000 simulated ad requests and thousands of ad events using Python.
- Designed a MySQL schema for publishers, apps, advertisers, campaigns, ad requests, raw events, clean events, experiments, reporting metrics, and alerts.
- Built SQL reporting tables for campaign and app-level KPIs including CTR, install rate, conversion rate, spend, revenue, profit, and eCPM.
- Implemented a raw-to-clean validation pipeline that rejects invalid tracking events and stores validation errors.
- Compared two simulated ad delivery algorithms using A/B experiment analysis.
- Built SQL-based monitoring alerts for negative-profit campaigns, weak CTR, high spend, KPI drops, and experiment tradeoffs.
- Created a Streamlit dashboard for campaign performance, app/game performance, A/B results, alerts, and validation errors.


\## Why I Built This Project



I built this project to understand how ad delivery systems can be analyzed from a data perspective. Instead of only reporting numbers, the project investigates whether event data is valid, whether campaigns are profitable, how users move through the funnel, and whether a new delivery algorithm performs better than a baseline algorithm.



The project follows this workflow:



```text

Raw ad events

&#x20;   ↓

Validation and cleaning

&#x20;   ↓

Clean event table

&#x20;   ↓

Campaign and app reporting metrics

&#x20;   ↓

A/B experiment analysis

&#x20;   ↓

Monitoring alerts

&#x20;   ↓

Streamlit dashboard

```



\## Tech Stack



\* Python

\* MySQL

\* SQL

\* Pandas

\* Streamlit

\* python-dotenv

\* mysql-connector-python

\* Git / GitHub



\## Main Features



\### 1. Simulated Ad Delivery Data



The Python generator creates realistic adtech data:



\* Users

\* Apps / games

\* Publishers

\* Advertisers

\* Campaigns

\* Ad requests

\* Impressions

\* Clicks

\* Installs

\* Rewards

\* Conversions

\* A/B experiment variants



The generated event flow follows a typical advertising funnel:



```text

Ad request → impression → click → install → reward / conversion

```



\### 2. Campaign KPI Analysis



The project calculates campaign-level KPIs using SQL:



\* Impressions

\* Clicks

\* Installs

\* Conversions

\* Rewards

\* CTR

\* Install rate

\* Conversion rate

\* Spend

\* Revenue

\* Profit

\* eCPM



These metrics are stored in `daily\_campaign\_metrics` and used by the dashboard.



\### 3. App and Publisher Performance



The project also tracks performance at app/game level using `daily\_app\_metrics`.



This allows analysis of:



\* Best performing games

\* Publisher performance

\* App category performance

\* Platform performance

\* Revenue and reward cost by app



\### 4. Data Quality Validation Pipeline



Raw event data is validated before being used for trusted reporting.



Invalid events are stored in `event\_validation\_errors`.



The validation pipeline detects:



\* Missing tracking IDs

\* Unknown tracking IDs

\* Duplicate event IDs

\* Campaign mismatches

\* App mismatches

\* User mismatches

\* Country mismatches

\* Platform mismatches



Clean events are inserted into `events\_clean`.



\### 5. A/B Experiment Analysis



The project compares two simulated ad delivery algorithms:



\* Variant A: `baseline\_bid\_priority`

\* Variant B: `optimized\_profit\_score`



The experiment analysis compares:



\* CTR

\* Install rate

\* Conversion rate

\* Revenue

\* Spend

\* Profit

\* eCPM



After tuning the generator, Variant B showed stronger performance:



```text

CTR lift: +20.58%

Conversion rate lift: +63.44%

Revenue delta: +493.87

Profit delta: +336.80

eCPM delta: +200.62

```



This means Variant B generated higher-quality traffic and turned profitable, even though it also increased spend.



\### 6. Monitoring Alerts



The project creates SQL-based monitoring alerts for business and data issues.



Examples:



\* Campaigns with very negative profit

\* High spend compared to revenue

\* Low CTR campaigns

\* Good CTR but weak install rate

\* Daily CTR drops

\* A/B experiment tradeoff warnings



Alerts are stored in the `alerts` table and shown in the dashboard.



\### 7. Streamlit Dashboard



The Streamlit dashboard visualizes the main analytical layers:



\* Campaign Performance

\* App/Game Performance

\* A/B Experiment

\* Monitoring Alerts

\* Validation Errors



The dashboard reads from the reporting and monitoring tables created by the SQL pipeline.



\## Project Structure



```text

adtrack-intelligence-platform/

│

├── dashboard/

│   └── 12\_streamlit\_dashboard.py

│

├── sql/

│   ├── 01\_create\_schema.sql

│   ├── 02\_insert\_seed\_data.sql

│   ├── 03\_manual\_ad\_requests\_and\_events.sql

│   ├── 04\_campaign\_kpi\_analysis.sql

│   ├── 05\_data\_quality\_alerts.sql

│   ├── 07\_generated\_kpi\_analysis.sql

│   ├── 08\_ab\_experiment\_analysis.sql

│   ├── 09\_performance\_monitoring\_alerts.sql

│   ├── 10\_clean\_events\_pipeline.sql

│   └── 11\_clean\_reporting\_metrics.sql

│

├── src/

│   └── 06\_generate\_events.py

│

├── requirements.txt

├── .gitignore

└── README.md

```



\## Database Tables



Main tables:



\* `publishers`

\* `apps`

\* `advertisers`

\* `campaigns`

\* `users`

\* `experiments`

\* `ad\_requests`

\* `events\_raw`

\* `events\_clean`

\* `event\_validation\_errors`

\* `daily\_campaign\_metrics`

\* `daily\_app\_metrics`

\* `experiment\_results`

\* `alerts`



\## How to Run the Project



\### 1. Install dependencies



```powershell

py -m pip install -r requirements.txt

```



\### 2. Create `.env`



Create a `.env` file in the project root:



```env

DB\_HOST=localhost

DB\_USER=root

DB\_PASSWORD=your\_mysql\_password

DB\_NAME=adtrack\_intelligence

```



\### 3. Run SQL setup scripts



Run these files in MySQL Workbench in order:



```text

01\_create\_schema.sql

02\_insert\_seed\_data.sql

03\_manual\_ad\_requests\_and\_events.sql

04\_campaign\_kpi\_analysis.sql

05\_data\_quality\_alerts.sql

```



\### 4. Generate simulated event data



```powershell

py src/06\_generate\_events.py

```



\### 5. Run analytics pipeline scripts



Run these SQL files in MySQL Workbench:



```text

07\_generated\_kpi\_analysis.sql

10\_clean\_events\_pipeline.sql

11\_clean\_reporting\_metrics.sql

08\_ab\_experiment\_analysis.sql

09\_performance\_monitoring\_alerts.sql

```



\### 6. Start the dashboard



```powershell

py -m streamlit run dashboard/12\_streamlit\_dashboard.py

```



\## Key Learning Outcomes



This project helped me practice:



\* SQL-based analytical thinking

\* Event tracking and attribution logic

\* KPI calculation for advertising systems

\* Data quality validation

\* Raw-to-clean data pipeline design

\* A/B experiment analysis

\* Monitoring and alert logic

\* Dashboard reporting with Streamlit

\* Git/GitHub project workflow



\## Future Improvements



Possible next improvements:



\* Add Airflow orchestration

\* Add Docker support

\* Add Tableau dashboard version

\* Add more advanced anomaly detection

\* Add statistical significance testing for A/B experiments

\* Add automated tests for validation rules

\* Add larger-scale synthetic event generation



