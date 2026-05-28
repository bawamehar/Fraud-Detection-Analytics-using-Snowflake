-- Add primary key on CUSTOMERS
ALTER TABLE Z_DB_BISON.PUBLIC.CUSTOMERS
ADD PRIMARY KEY (CUSTOMER_ID);

-- Add primary key on TRANSACTIONS
ALTER TABLE Z_DB_BISON.PUBLIC.TRANSACTIONS
ADD PRIMARY KEY (TRANSACTION_ID);


-- Add foreign key linking transactions to customers
ALTER TABLE Z_DB_BISON.PUBLIC.TRANSACTIONS
ADD FOREIGN KEY (CUSTOMER_ID) REFERENCES Z_DB_BISON.PUBLIC.CUSTOMERS(CUSTOMER_ID);

SELECT COLUMN_NAME, DATA_TYPE
FROM Z_DB_BISON.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'PUBLIC'
  AND TABLE_NAME IN ('CUSTOMERS', 'TRANSACTIONS')
ORDER BY TABLE_NAME, ORDINAL_POSITION;

SELECT 'CUSTOMERS' AS table_name, COUNT(*) AS row_count FROM Z_DB_BISON.PUBLIC.CUSTOMERS
UNION ALL
SELECT 'TRANSACTIONS', COUNT(*) FROM Z_DB_BISON.PUBLIC.TRANSACTIONS;

SELECT
    COUNT(CUSTOMER_ID)                          AS total_customers,
    MIN(AGE)                                    AS min_age,
    MAX(AGE)                                    AS max_age,
    ROUND(AVG(AGE), 1)                          AS avg_age,
    MIN(ACCOUNT_TENURE_DAYS)                    AS min_tenure_days,
    MAX(ACCOUNT_TENURE_DAYS)                    AS max_tenure_days,
    ROUND(AVG(ACCOUNT_TENURE_DAYS), 1)          AS avg_tenure_days,
    MIN(CREDIT_LIMIT)                           AS min_credit_limit,
    MAX(CREDIT_LIMIT)                           AS max_credit_limit,
    ROUND(AVG(CREDIT_LIMIT), 2)                 AS avg_credit_limit,
    ROUND(MIN(AVG_MONTHLY_SPEND), 2)            AS min_monthly_spend,
    ROUND(MAX(AVG_MONTHLY_SPEND), 2)            AS max_monthly_spend,
    ROUND(AVG(AVG_MONTHLY_SPEND), 2)            AS avg_monthly_spend,
    COUNT(DISTINCT RISK_TIER)                   AS distinct_risk_tiers
FROM Z_DB_BISON.PUBLIC.CUSTOMERS;

SELECT
    RISK_TIER,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_of_total
FROM Z_DB_BISON.PUBLIC.CUSTOMERS
GROUP BY RISK_TIER
ORDER BY customer_count DESC;

SELECT
    COUNT(TRANSACTION_ID)                           AS total_transactions,
    ROUND(MIN(AMOUNT), 2)                           AS min_amount,
    ROUND(MAX(AMOUNT), 2)                           AS max_amount,
    ROUND(AVG(AMOUNT), 2)                           AS avg_amount,
    ROUND(STDDEV(AMOUNT), 2)                        AS stddev_amount,
    MIN(TRANSACTION_DATE)                           AS earliest_date,
    MAX(TRANSACTION_DATE)                           AS latest_date,
    MIN(HOUR_OF_DAY)                                AS min_hour,
    MAX(HOUR_OF_DAY)                                AS max_hour,
    ROUND(AVG(HOUR_OF_DAY), 1)                      AS avg_hour,
    SUM(IS_FLAGGED)                                 AS total_flagged,
    ROUND(SUM(IS_FLAGGED) * 100.0 / COUNT(*), 1)    AS pct_flagged,
    COUNT(DISTINCT MERCHANT_CATEGORY)               AS distinct_merchants,
    COUNT(DISTINCT TRANSACTION_TYPE)                AS distinct_txn_types,
    COUNT(DISTINCT LOCATION)                        AS distinct_locations
FROM Z_DB_BISON.PUBLIC.TRANSACTIONS;

SELECT
    MERCHANT_CATEGORY,
    COUNT(*)                                        AS txn_count,
    ROUND(AVG(AMOUNT), 2)                           AS avg_amount,
    SUM(IS_FLAGGED)                                 AS flagged_count,
    ROUND(SUM(IS_FLAGGED) * 100.0 / COUNT(*), 1)    AS flag_rate_pct
FROM Z_DB_BISON.PUBLIC.TRANSACTIONS
GROUP BY MERCHANT_CATEGORY
ORDER BY txn_count DESC;


--Query 1
SELECT
    MERCHANT_CATEGORY,
    COUNT(*)                                            AS total_transactions,
    SUM(IS_FLAGGED)                                     AS flagged_count,
    ROUND(SUM(IS_FLAGGED) * 100.0 / COUNT(*), 1)        AS flag_rate_pct,
    ROUND(AVG(AMOUNT), 2)                               AS avg_transaction_amount,
    ROUND(SUM(AMOUNT), 2)                               AS total_volume
FROM Z_DB_BISON.PUBLIC.TRANSACTIONS
GROUP BY MERCHANT_CATEGORY
ORDER BY flag_rate_pct DESC;

SELECT
    C.RISK_TIER,
    COUNT(DISTINCT T.CUSTOMER_ID)                           AS customer_count,
    COUNT(T.TRANSACTION_ID)                                 AS total_transactions,
    ROUND(COUNT(T.TRANSACTION_ID) / COUNT(DISTINCT T.CUSTOMER_ID), 1) AS avg_txns_per_customer,
    ROUND(AVG(T.AMOUNT), 2)                                 AS avg_transaction_amount,
    ROUND(SUM(T.AMOUNT), 2)                                 AS total_spend,
    SUM(T.IS_FLAGGED)                                       AS flagged_count,
    ROUND(SUM(T.IS_FLAGGED) * 100.0 / COUNT(*), 1)          AS flag_rate_pct
FROM Z_DB_BISON.PUBLIC.TRANSACTIONS T
JOIN Z_DB_BISON.PUBLIC.CUSTOMERS C
    ON T.CUSTOMER_ID = C.CUSTOMER_ID
GROUP BY C.RISK_TIER
ORDER BY CASE C.RISK_TIER WHEN 'High' THEN 1 WHEN 'Medium' THEN 2 WHEN 'Low' THEN 3 END;

SELECT
    T.CUSTOMER_ID,
    C.RISK_TIER,
    COUNT(T.TRANSACTION_ID)                                 AS total_transactions,
    COUNT(DISTINCT T.TRANSACTION_DATE)                      AS active_days,
    ROUND(AVG(T.AMOUNT), 2)                                 AS avg_transaction_amount,
    MAX(T.AMOUNT)                                           AS max_single_txn,
    SUM(T.IS_FLAGGED)                                       AS flagged_count,
    ROUND(SUM(T.IS_FLAGGED) * 100.0 / COUNT(*), 1)          AS flag_rate_pct
FROM Z_DB_BISON.PUBLIC.TRANSACTIONS T
JOIN Z_DB_BISON.PUBLIC.CUSTOMERS C
    ON T.CUSTOMER_ID = C.CUSTOMER_ID
GROUP BY T.CUSTOMER_ID, C.RISK_TIER
HAVING SUM(T.IS_FLAGGED) >= 2
ORDER BY flagged_count DESC, flag_rate_pct DESC
LIMIT 15;

select * from transactions
limit 20;

WITH TRANSACTION_SCORES AS (
    SELECT
        T.TRANSACTION_ID,
        T.CUSTOMER_ID,
        C.RISK_TIER,
        T.MERCHANT_CATEGORY,
        T.AMOUNT,
        C.CREDIT_LIMIT,
        T.HOUR_OF_DAY,
        T.TRANSACTION_TYPE,
        T.IS_FLAGGED,

        -- Signal 1: Merchant category risk
        CASE
            WHEN T.MERCHANT_CATEGORY IN ('Luxury_Goods', 'ATM_Withdrawal') THEN 3
            WHEN T.MERCHANT_CATEGORY IN ('Travel', 'Gas')                   THEN 2
            ELSE 1
        END AS merchant_risk_score,

        -- Signal 2: Off-hours transaction (10pm to 5am)
        CASE
            WHEN T.HOUR_OF_DAY >= 22 OR T.HOUR_OF_DAY <= 5 THEN 2
            ELSE 0
        END AS off_hours_score,

        -- Signal 3: Online channel
        CASE
            WHEN T.TRANSACTION_TYPE = 'online' THEN 1
            ELSE 0
        END AS online_score,

        -- Signal 4: Amount exceeds 50% of credit limit
        CASE
            WHEN T.AMOUNT > (C.CREDIT_LIMIT * 0.5) THEN 3
            WHEN T.AMOUNT > (C.CREDIT_LIMIT * 0.25) THEN 2
            ELSE 1
        END AS amount_ratio_score,

        -- Signal 5: Customer risk tier
        CASE
            WHEN C.RISK_TIER = 'High'   THEN 3
            WHEN C.RISK_TIER = 'Medium' THEN 2
            ELSE 1
        END AS tier_risk_score

    FROM Z_DB_BISON.PUBLIC.TRANSACTIONS T
    JOIN Z_DB_BISON.PUBLIC.CUSTOMERS C
        ON T.CUSTOMER_ID = C.CUSTOMER_ID
),

CUSTOMER_SCORES AS (
    SELECT
        CUSTOMER_ID,
        RISK_TIER,
        COUNT(TRANSACTION_ID)                                       AS total_transactions,
        ROUND(AVG(AMOUNT), 2)                                       AS avg_amount,
        SUM(IS_FLAGGED)                                             AS total_flagged,
        ROUND(AVG(
            merchant_risk_score +
            off_hours_score     +
            online_score        +
            amount_ratio_score  +
            tier_risk_score
        ), 2)                                                       AS avg_composite_score,
        MAX(
            merchant_risk_score +
            off_hours_score     +
            online_score        +
            amount_ratio_score  +
            tier_risk_score
        )                                                           AS max_composite_score
    FROM TRANSACTION_SCORES
    GROUP BY CUSTOMER_ID, RISK_TIER
)

SELECT
    CUSTOMER_ID,
    RISK_TIER,
    total_transactions,
    avg_amount,
    total_flagged,
    avg_composite_score,
    max_composite_score,
    CASE
        WHEN avg_composite_score >= 8  THEN 'Critical'
        WHEN avg_composite_score >= 6  THEN 'High'
        WHEN avg_composite_score >= 4  THEN 'Medium'
        ELSE                                'Low'
    END AS derived_risk_label
FROM CUSTOMER_SCORES
ORDER BY avg_composite_score DESC, total_flagged DESC
LIMIT 15;


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
    FROM Z_DB_BISON.PUBLIC.TRANSACTIONS T
    JOIN Z_DB_BISON.PUBLIC.CUSTOMERS C ON T.CUSTOMER_ID = C.CUSTOMER_ID
),
CUSTOMER_SCORES AS (
    SELECT
        CUSTOMER_ID, RISK_TIER,
        COUNT(TRANSACTION_ID)                                     AS total_transactions,
        ROUND(AVG(AMOUNT), 2)                                     AS avg_amount,
        SUM(IS_FLAGGED)                                           AS total_flagged,
        ROUND(AVG(merchant_risk_score + off_hours_score + online_score + amount_ratio_score
                + tier_risk_score), 2)                            AS avg_composite_score,
        MAX(merchant_risk_score + off_hours_score
          + online_score + amount_ratio_score
          + tier_risk_score)                                      AS max_composite_score
    FROM TRANSACTION_SCORES
    GROUP BY CUSTOMER_ID, RISK_TIER
)
SELECT
    CUSTOMER_ID, RISK_TIER, total_transactions, avg_amount,
    total_flagged, avg_composite_score, max_composite_score,
    CASE WHEN avg_composite_score >= 8 THEN 'Critical'
         WHEN avg_composite_score >= 6 THEN 'High'
         WHEN avg_composite_score >= 4 THEN 'Medium'
         ELSE 'Low'
    END AS derived_risk_label
FROM CUSTOMER_SCORES
ORDER BY avg_composite_score DESC, total_flagged DESC
LIMIT 15;