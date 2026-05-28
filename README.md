# Fraud-Signal-Analytics

> SQL-based exploratory analysis and composite risk scoring framework for financial fraud detection, built on Snowflake — designed as the feature engineering foundation for an ML classification pipeline.

---

## Overview

This project applies structured SQL analysis to a financial transactions dataset to identify behavioral fraud signals, profile high-risk customers, and construct a composite risk scoring model — entirely in SQL. The analytical work mirrors the **data exploration and feature engineering phase** that precedes model training in production fraud detection systems.

The project was built and executed in **Snowflake** using a purpose-designed synthetic dataset modeled after real-world financial transaction patterns.

---

## Business Question

> Can transaction behavior patterns in financial data be used to identify high-risk customers and flag anomalous activity — laying the analytical groundwork for a machine learning fraud detection system?

---

## Dataset

Two tables, synthetic, designed to reflect realistic fraud distribution patterns.

| Table | Rows | Columns | Description |
|---|---|---|---|
| `CUSTOMERS` | 100 | 6 | Demographics, credit limit, account tenure, risk tier |
| `TRANSACTIONS` | 400 | 9 | Transaction amount, merchant category, channel, location, hour, fraud flag |

**Key dataset characteristics:**
- 22% overall fraud flag rate
- 8 merchant categories with flag rates ranging from 6.8% to 51%
- Risk tier distribution: 55% Low, 29% Medium, 16% High
- Full calendar year 2024 (Jan–Dec)

---

## Analytical Queries

Four SQL queries were developed, each answering a progressively deeper sub-question:

| Query | Sub-question | Key SQL Concepts |
|---|---|---|
| 1 — Merchant Flag Rate | Which merchant categories concentrate the most fraud risk? | GROUP BY, aggregation, ratio calculation |
| 2 — Risk Tier Segmentation | Do high-risk customers transact differently from low-risk ones? | JOIN, conditional aggregation, CASE |
| 3 — Repeat Offender Profiling | Which customers show recurring flagging behavior? | HAVING, multi-table JOIN, filtering |
| 4 — Composite Risk Scoring | Can multiple fraud signals be combined into a single risk score? | CTEs, multi-signal CASE scoring, derived labels |

Full query code is available in the `/queries` folder.

---

## Key Findings

- Fraud is **merchant-concentrated**: two categories account for 55.7% of all flagged transactions
- Risk tier shows a **monotonic fraud gradient** (14.8% → 26.4% → 36.9%) but is insufficient as a standalone signal
- **Static risk labels go stale**: Low-risk customers appeared repeatedly among the highest-flagged individuals
- A **composite SQL scoring model** successfully stratifies customers into four risk tiers, catching high-risk behavior that static classification misses entirely

---

## ML Pipeline Connection

This project deliberately mirrors the **feature engineering phase** of a production fraud ML pipeline. The five signals identified and validated here translate directly into model input features:

| SQL Signal | ML Feature Type |
|---|---|
| Merchant category risk score | Ordinal encoded categorical |
| Off-hours flag | Binary indicator |
| Online channel flag | Binary indicator |
| Amount-to-credit-limit ratio | Continuous ratio feature |
| Customer risk tier score | Ordinal encoded categorical |

The `IS_FLAGGED` column serves as the **binary target variable**. The logical next step is training a gradient boosted classifier (XGBoost or LightGBM) on these engineered features to move from rule-based scoring to probabilistic fraud prediction at scale.

---

## Tech Stack

- **Snowflake** — data warehouse and SQL execution
- **SQL** — CTEs, window functions, conditional aggregation, multi-table joins
- **Dataset** — synthetic, purpose-built (500 rows, 15 columns across 2 tables)

---

## Repository Structure

```
fraud-signal-analytics-using-snowflake/
├── data/
│   ├── customers.csv
│   └── transactions.csv
├── queries/
│   ├── 01_merchant_flag_rate.sql
│   ├── 02_risk_tier_segmentation.sql
│   ├── 03_repeat_offender_profiling.sql
│   └── 04_composite_risk_scoring.sql
├── README.md
└── report/
    └── fraud_signal_analytics_report.pdf
```

---

## Author

**Mehar Singh Bawa**  
MS Computer Information Systems — Colorado State University  
[LinkedIn](https://www.linkedin.com/in/bawamehar) · [GitHub](https://github.com/bawamehar)
