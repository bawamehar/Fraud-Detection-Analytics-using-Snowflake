# fraud-signal-analytics

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

## Analytical Approach

Four SQL queries, each answering a progressively deeper sub-question:

### Query 1 — Fraud Flag Rate by Merchant Category
Identifies which merchant categories concentrate the most fraud risk.

**Key finding:** Luxury Goods (51%) and ATM Withdrawals (44.2%) account for 55.7% of all flagged transactions despite representing only 25.8% of volume.

```sql
SELECT
    MERCHANT_CATEGORY,
    COUNT(*)                                     AS total_transactions,
    SUM(IS_FLAGGED)                              AS flagged_count,
    ROUND(SUM(IS_FLAGGED) * 100.0 / COUNT(*), 1) AS flag_rate_pct,
    ROUND(AVG(AMOUNT), 2)                        AS avg_transaction_amount,
    ROUND(SUM(AMOUNT), 2)                        AS total_volume
FROM TRANSACTIONS
GROUP BY MERCHANT_CATEGORY
ORDER BY flag_rate_pct DESC;
```

---

### Query 2 — Risk Tier Behavioral Segmentation
Compares transaction behavior across Low, Medium, and High risk customer tiers.

**Key finding:** High-risk customers are 2.5x more likely to generate a flagged transaction than Low-risk customers, and transact at higher average amounts — a compounding risk signal.

```sql
SELECT
    C.RISK_TIER,
    COUNT(DISTINCT T.CUSTOMER_ID)                AS customer_count,
    COUNT(T.TRANSACTION_ID)                      AS total_transactions,
    ROUND(AVG(T.AMOUNT), 2)                      AS avg_transaction_amount,
    SUM(T.IS_FLAGGED)                            AS flagged_count,
    ROUND(SUM(T.IS_FLAGGED) * 100.0 / COUNT(*), 1) AS flag_rate_pct
FROM TRANSACTIONS T
JOIN CUSTOMERS C ON T.CUSTOMER_ID = C.CUSTOMER_ID
GROUP BY C.RISK_TIER
ORDER BY CASE C.RISK_TIER WHEN 'High' THEN 1 WHEN 'Medium' THEN 2 ELSE 3 END;
```

---

### Query 3 — Repeat Offender Customer Profiling
Identifies customers with two or more flagged transactions — a significantly stronger fraud signal than a single event.

**Key finding:** Repeat flagging is not exclusive to High-risk customers. Four Low-risk customers appear in the top 15 most-flagged list with flag rates between 50–66.7%, demonstrating that static risk labels become stale over time.

```sql
SELECT
    T.CUSTOMER_ID, C.RISK_TIER,
    COUNT(T.TRANSACTION_ID)       AS total_transactions,
    MAX(T.AMOUNT)                 AS max_single_txn,
    SUM(T.IS_FLAGGED)             AS flagged_count,
    ROUND(SUM(T.IS_FLAGGED) * 100.0 / COUNT(*), 1) AS flag_rate_pct
FROM TRANSACTIONS T
JOIN CUSTOMERS C ON T.CUSTOMER_ID = C.CUSTOMER_ID
GROUP BY T.CUSTOMER_ID, C.RISK_TIER
HAVING SUM(T.IS_FLAGGED) >= 2
ORDER BY flagged_count DESC, flag_rate_pct DESC
LIMIT 15;
```

---

### Query 4 — Composite Risk Scoring Model
Constructs a multi-signal composite risk score per customer using five independent fraud signals, aggregated via two CTEs.

**Signals scored:**
| Signal | Weight |
|---|---|
| Merchant category risk | 1–3 |
| Off-hours activity (10pm–5am) | 0 or 2 |
| Online channel | 0 or 1 |
| Amount-to-credit-limit ratio | 1–3 |
| Customer risk tier | 1–3 |

**Score range:** 2 (minimal risk) to 12 (maximum risk)

**Derived risk labels:** Critical (≥8) · High (≥6) · Medium (≥4) · Low (<4)

**Key finding:** Customer C091, classified Low-risk by static account attributes, scored Critical under the composite model due to a $3,712 transaction — invisible to a static risk system.

```sql
WITH TRANSACTION_SCORES AS (
    SELECT
        T.TRANSACTION_ID, T.CUSTOMER_ID, C.RISK_TIER,
        T.MERCHANT_CATEGORY, T.AMOUNT, C.CREDIT_LIMIT,
        T.HOUR_OF_DAY, T.TRANSACTION_TYPE, T.IS_FLAGGED,
        CASE WHEN T.MERCHANT_CATEGORY IN ('Luxury_Goods','ATM_Withdrawal') THEN 3
             WHEN T.MERCHANT_CATEGORY IN ('Travel','Gas') THEN 2 ELSE 1
        END AS merchant_risk_score,
        CASE WHEN T.HOUR_OF_DAY >= 22 OR T.HOUR_OF_DAY <= 5 THEN 2 ELSE 0
        END AS off_hours_score,
        CASE WHEN T.TRANSACTION_TYPE = 'online' THEN 1 ELSE 0
        END AS online_score,
        CASE WHEN T.AMOUNT > (C.CREDIT_LIMIT * 0.5) THEN 3
             WHEN T.AMOUNT > (C.CREDIT_LIMIT * 0.25) THEN 2 ELSE 1
        END AS amount_ratio_score,
        CASE WHEN C.RISK_TIER = 'High' THEN 3
             WHEN C.RISK_TIER = 'Medium' THEN 2 ELSE 1
        END AS tier_risk_score
    FROM TRANSACTIONS T
    JOIN CUSTOMERS C ON T.CUSTOMER_ID = C.CUSTOMER_ID
),
CUSTOMER_SCORES AS (
    SELECT CUSTOMER_ID, RISK_TIER,
        COUNT(TRANSACTION_ID)                      AS total_transactions,
        ROUND(AVG(AMOUNT), 2)                      AS avg_amount,
        SUM(IS_FLAGGED)                            AS total_flagged,
        ROUND(AVG(merchant_risk_score + off_hours_score
              + online_score + amount_ratio_score
              + tier_risk_score), 2)               AS avg_composite_score,
        MAX(merchant_risk_score + off_hours_score
          + online_score + amount_ratio_score
          + tier_risk_score)                       AS max_composite_score
    FROM TRANSACTION_SCORES
    GROUP BY CUSTOMER_ID, RISK_TIER
)
SELECT CUSTOMER_ID, RISK_TIER, total_transactions, avg_amount,
    total_flagged, avg_composite_score, max_composite_score,
    CASE WHEN avg_composite_score >= 8 THEN 'Critical'
         WHEN avg_composite_score >= 6 THEN 'High'
         WHEN avg_composite_score >= 4 THEN 'Medium'
         ELSE 'Low'
    END AS derived_risk_label
FROM CUSTOMER_SCORES
ORDER BY avg_composite_score DESC, total_flagged DESC
LIMIT 15;
```

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
fraud-signal-analytics/
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
[LinkedIn](https://www.linkedin.com/in/meharsinghbawa) · [GitHub](https://github.com/meharsinghbawa)
