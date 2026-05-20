-- =====================================================
-- FRAUD DETECTION ANALYTICS - SQL MONITORING LAYER
-- Project: Fraud Monitoring & Operational Risk Analytics
-- Author: Celya Taklit
--
-- Purpose:
-- Convert machine learning fraud prediction outputs into
-- operational fraud monitoring KPIs, investigation views,
-- alert quality analysis, and executive reporting indicators.
--
-- Input file:
-- data/processed/fraud_detection_predictions.csv
--
-- Recommended database: MySQL
-- =====================================================

-- =====================================================
-- 0. DATABASE AND TABLE SETUP
-- =====================================================

CREATE DATABASE IF NOT EXISTS fraud_analysis;
USE fraud_analysis;

DROP TABLE IF EXISTS fraud_predictions;

CREATE TABLE fraud_predictions (
    step INT,
    typeTransaction VARCHAR(20),
    amount DECIMAL(18,2),
    oldbalanceOrg DECIMAL(18,2),
    oldbalanceDest DECIMAL(18,2),
    isHighRiskType TINYINT,
    actual_isFraud TINYINT,
    predicted_isFraud TINYINT,
    predicted_probability DECIMAL(10,8)
);

-- Import note:
-- Import fraud_detection_predictions.csv into fraud_predictions.
-- In MySQL Workbench, use: Table Data Import Wizard.
-- In a local MySQL CLI workflow, use LOAD DATA INFILE according to your local security settings.

-- =====================================================
-- 1. DATA QUALITY AND DATASET OVERVIEW
-- =====================================================

SELECT COUNT(*) AS total_transactions
FROM fraud_predictions;

SELECT
    SUM(CASE WHEN step IS NULL THEN 1 ELSE 0 END) AS null_step,
    SUM(CASE WHEN typeTransaction IS NULL THEN 1 ELSE 0 END) AS null_typeTransaction,
    SUM(CASE WHEN amount IS NULL THEN 1 ELSE 0 END) AS null_amount,
    SUM(CASE WHEN actual_isFraud IS NULL THEN 1 ELSE 0 END) AS null_actual_isFraud,
    SUM(CASE WHEN predicted_isFraud IS NULL THEN 1 ELSE 0 END) AS null_predicted_isFraud,
    SUM(CASE WHEN predicted_probability IS NULL THEN 1 ELSE 0 END) AS null_predicted_probability
FROM fraud_predictions;

SELECT
    typeTransaction,
    COUNT(*) AS transaction_count,
    ROUND(COUNT(*) / (SELECT COUNT(*) FROM fraud_predictions) * 100, 2) AS transaction_share_percent
FROM fraud_predictions
GROUP BY typeTransaction
ORDER BY transaction_count DESC;

-- Business interpretation:
-- This first block validates the SQL dataset before analytical use.
-- The table should contain 101,643 transactions, no missing critical fields,
-- and five transaction categories: CASH_OUT, PAYMENT, CASH_IN, TRANSFER and DEBIT.

-- =====================================================
-- 2. EXECUTIVE FRAUD MONITORING KPIS
-- =====================================================

SELECT
    COUNT(*) AS total_transactions,
    SUM(actual_isFraud) AS confirmed_frauds,
    SUM(predicted_isFraud) AS model_alerts,
    SUM(CASE WHEN actual_isFraud = 1 AND predicted_isFraud = 1 THEN 1 ELSE 0 END) AS detected_frauds,
    SUM(CASE WHEN actual_isFraud = 1 AND predicted_isFraud = 0 THEN 1 ELSE 0 END) AS missed_frauds,
    SUM(CASE WHEN actual_isFraud = 0 AND predicted_isFraud = 1 THEN 1 ELSE 0 END) AS false_alerts,
    ROUND(AVG(actual_isFraud) * 100, 2) AS fraud_rate_percent,
    ROUND(AVG(predicted_probability) * 100, 2) AS average_fraud_probability_percent
FROM fraud_predictions;

-- Business interpretation:
-- This query provides the executive view required for Power BI KPI cards:
-- total transactions, confirmed frauds, model alerts, detected frauds,
-- missed frauds, false alerts and average fraud probability.

-- =====================================================
-- 3. MODEL PERFORMANCE - CONFUSION MATRIX
-- =====================================================

SELECT
    SUM(CASE WHEN actual_isFraud = 1 AND predicted_isFraud = 1 THEN 1 ELSE 0 END) AS true_positives,
    SUM(CASE WHEN actual_isFraud = 0 AND predicted_isFraud = 1 THEN 1 ELSE 0 END) AS false_positives,
    SUM(CASE WHEN actual_isFraud = 1 AND predicted_isFraud = 0 THEN 1 ELSE 0 END) AS false_negatives,
    SUM(CASE WHEN actual_isFraud = 0 AND predicted_isFraud = 0 THEN 1 ELSE 0 END) AS true_negatives
FROM fraud_predictions;

SELECT
    ROUND(
        SUM(CASE WHEN actual_isFraud = 1 AND predicted_isFraud = 1 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN predicted_isFraud = 1 THEN 1 ELSE 0 END), 0) * 100,
        2
    ) AS precision_percent,
    ROUND(
        SUM(CASE WHEN actual_isFraud = 1 AND predicted_isFraud = 1 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN actual_isFraud = 1 THEN 1 ELSE 0 END), 0) * 100,
        2
    ) AS recall_percent,
    ROUND(
        SUM(CASE WHEN actual_isFraud = predicted_isFraud THEN 1 ELSE 0 END)
        / COUNT(*) * 100,
        2
    ) AS accuracy_percent
FROM fraud_predictions;

-- Business interpretation:
-- The model follows a high-recall fraud monitoring strategy.
-- This is appropriate when the business priority is reducing missed fraud,
-- even if additional false positive alerts increase investigation workload.

-- =====================================================
-- 4. FRAUD EXPOSURE BY TRANSACTION TYPE
-- =====================================================

SELECT
    typeTransaction,
    COUNT(*) AS total_transactions,
    SUM(actual_isFraud) AS confirmed_fraud_cases,
    SUM(predicted_isFraud) AS model_alerts,
    ROUND(AVG(actual_isFraud) * 100, 2) AS fraud_rate_percent,
    ROUND(AVG(amount), 2) AS average_transaction_amount,
    ROUND(SUM(CASE WHEN actual_isFraud = 1 THEN amount ELSE 0 END), 2) AS confirmed_fraud_amount
FROM fraud_predictions
GROUP BY typeTransaction
ORDER BY fraud_rate_percent DESC, confirmed_fraud_amount DESC;

-- Business interpretation:
-- This query identifies transaction types with the highest fraud exposure.
-- TRANSFER and CASH_OUT should be monitored more closely because they are
-- the most fraud-sensitive transaction categories in this dataset.

-- =====================================================
-- 5. ALERT QUALITY BY TRANSACTION TYPE
-- =====================================================

SELECT
    typeTransaction,
    COUNT(*) AS total_transactions,
    SUM(predicted_isFraud) AS total_alerts,
    SUM(CASE WHEN actual_isFraud = 1 AND predicted_isFraud = 1 THEN 1 ELSE 0 END) AS confirmed_alerts,
    SUM(CASE WHEN actual_isFraud = 0 AND predicted_isFraud = 1 THEN 1 ELSE 0 END) AS false_alerts,
    COALESCE(
        ROUND(
            SUM(CASE WHEN actual_isFraud = 1 AND predicted_isFraud = 1 THEN 1 ELSE 0 END)
            / NULLIF(SUM(CASE WHEN predicted_isFraud = 1 THEN 1 ELSE 0 END), 0) * 100,
            2
        ),
        0
    ) AS alert_precision_percent
FROM fraud_predictions
GROUP BY typeTransaction
ORDER BY alert_precision_percent DESC;

-- Business interpretation:
-- This analysis helps fraud operations understand where alerts are most reliable
-- and where false positives create more analyst workload.

-- =====================================================
-- 6. RISK BAND SEGMENTATION
-- =====================================================

SELECT
    risk_band,
    COUNT(*) AS transaction_count,
    SUM(actual_isFraud) AS confirmed_fraud_cases,
    SUM(predicted_isFraud) AS model_alerts,
    ROUND(AVG(actual_isFraud) * 100, 2) AS fraud_rate_percent,
    ROUND(AVG(predicted_probability) * 100, 2) AS average_probability_percent
FROM (
    SELECT
        actual_isFraud,
        predicted_isFraud,
        predicted_probability,
        CASE
            WHEN predicted_probability >= 0.80 THEN 'Very High Risk'
            WHEN predicted_probability >= 0.50 THEN 'High Risk'
            WHEN predicted_probability >= 0.20 THEN 'Medium Risk'
            ELSE 'Low Risk'
        END AS risk_band
    FROM fraud_predictions
) AS risk_band_analysis
GROUP BY risk_band
ORDER BY
    CASE
        WHEN risk_band = 'Very High Risk' THEN 1
        WHEN risk_band = 'High Risk' THEN 2
        WHEN risk_band = 'Medium Risk' THEN 3
        ELSE 4
    END;

-- Business interpretation:
-- Risk bands convert model probabilities into operational categories.
-- Very High Risk transactions should be reviewed first, while lower-risk bands
-- may be monitored with lighter controls or secondary rules.

-- =====================================================
-- 7. INVESTIGATION PRIORITIZATION - TOP ALERTS
-- =====================================================

SELECT
    step,
    typeTransaction,
    amount,
    actual_isFraud,
    predicted_isFraud,
    ROUND(predicted_probability, 4) AS fraud_probability
FROM fraud_predictions
ORDER BY predicted_probability DESC, amount DESC
LIMIT 50;

-- Business interpretation:
-- This query gives fraud analysts a prioritized investigation list based on
-- model confidence and potential transaction exposure.

-- =====================================================
-- 8. MISSED FRAUD ANALYSIS - FALSE NEGATIVES
-- =====================================================

SELECT
    step,
    typeTransaction,
    amount,
    oldbalanceOrg,
    oldbalanceDest,
    ROUND(predicted_probability, 4) AS fraud_probability
FROM fraud_predictions
WHERE actual_isFraud = 1
  AND predicted_isFraud = 0
ORDER BY amount DESC
LIMIT 50;

-- Business interpretation:
-- False negatives are critical because they represent fraud cases that were not
-- flagged by the model. Reviewing them helps identify blind spots and improve
-- future thresholds, rules and feature engineering.

-- =====================================================
-- 9. FALSE POSITIVE ANALYSIS - ALERT WORKLOAD
-- =====================================================

SELECT
    step,
    typeTransaction,
    amount,
    oldbalanceOrg,
    oldbalanceDest,
    ROUND(predicted_probability, 4) AS fraud_probability
FROM fraud_predictions
WHERE actual_isFraud = 0
  AND predicted_isFraud = 1
ORDER BY predicted_probability DESC, amount DESC
LIMIT 50;

-- Business interpretation:
-- False positives increase investigation workload and can create customer friction.
-- Monitoring false positives is essential for alert quality and operational capacity.

-- =====================================================
-- 10. FINANCIAL EXPOSURE - DETECTED VS MISSED FRAUD
-- =====================================================

SELECT
    ROUND(SUM(CASE WHEN actual_isFraud = 1 THEN amount ELSE 0 END), 2) AS total_fraud_amount,
    ROUND(SUM(CASE WHEN actual_isFraud = 1 AND predicted_isFraud = 1 THEN amount ELSE 0 END), 2) AS detected_fraud_amount,
    ROUND(SUM(CASE WHEN actual_isFraud = 1 AND predicted_isFraud = 0 THEN amount ELSE 0 END), 2) AS missed_fraud_amount,
    ROUND(
        SUM(CASE WHEN actual_isFraud = 1 AND predicted_isFraud = 1 THEN amount ELSE 0 END)
        / NULLIF(SUM(CASE WHEN actual_isFraud = 1 THEN amount ELSE 0 END), 0) * 100,
        2
    ) AS detected_fraud_amount_percent
FROM fraud_predictions;

-- Business interpretation:
-- This KPI measures fraud exposure in financial value, not only in number of cases.
-- It is highly relevant for executive reporting and risk appetite monitoring.

-- =====================================================
-- 11. THRESHOLD CALIBRATION AND ALERT WORKLOAD
-- =====================================================

SELECT
    threshold_level,
    COUNT(*) AS transactions_reviewed,
    SUM(actual_isFraud) AS confirmed_frauds_detected,
    SUM(CASE WHEN actual_isFraud = 0 THEN 1 ELSE 0 END) AS false_alerts,
    ROUND(AVG(actual_isFraud) * 100, 2) AS alert_precision_percent
FROM (
    SELECT
        actual_isFraud,
        predicted_probability,
        CASE
            WHEN predicted_probability >= 0.90 THEN '90% - 100%'
            WHEN predicted_probability >= 0.80 THEN '80% - 89%'
            WHEN predicted_probability >= 0.70 THEN '70% - 79%'
            WHEN predicted_probability >= 0.50 THEN '50% - 69%'
            ELSE 'Below 50%'
        END AS threshold_level
    FROM fraud_predictions
) AS threshold_analysis
WHERE threshold_level <> 'Below 50%'
GROUP BY threshold_level
ORDER BY
    CASE
        WHEN threshold_level = '90% - 100%' THEN 1
        WHEN threshold_level = '80% - 89%' THEN 2
        WHEN threshold_level = '70% - 79%' THEN 3
        WHEN threshold_level = '50% - 69%' THEN 4
    END;

-- Business interpretation:
-- This query helps decide how strict the alerting threshold should be.
-- Higher score bands produce more reliable alerts, while lower bands increase
-- analyst workload and should be handled with additional rules or triage logic.

-- =====================================================
-- 12. SQL ANALYSIS CONCLUSION
-- =====================================================
-- This SQL layer transforms model predictions into fraud operations insights:
-- 1. executive fraud monitoring KPIs,
-- 2. model performance and alert quality metrics,
-- 3. transaction-type fraud exposure analysis,
-- 4. investigation prioritization lists,
-- 5. threshold calibration indicators,
-- 6. financial exposure monitoring.
--
-- This makes the project suitable for a portfolio targeting Fraud Analytics,
-- Financial Crime Analytics, Risk Data Analytics, and Fintech Risk roles.
-- =====================================================
