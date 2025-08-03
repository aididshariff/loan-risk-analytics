-- ============================================================
-- LOAN RISK ANALYTICS PROJECT
-- Author: Aidid Alwi
-- Description: End-to-end SQL project for cleaning, transforming,
-- and analyzing a messy financial loan dataset to uncover risk patterns,
-- borrower behavior, and business insights.
-- ============================================================

-- ============================================================
-- STEP 1: INITIAL DATA QUALITY CHECKS
-- Purpose: Detect missing values and duplicates
-- ============================================================

-- 1.1 Missing values

SELECT
   SUM(CASE WHEN loan_id IS NULL THEN 1 ELSE 0 END) AS missing_loan_id,
   SUM(CASE WHEN loan_amnt IS NULL THEN 1 ELSE 0 END) AS missing_loan_amnt,
   SUM(CASE WHEN term IS NULL THEN 1 ELSE 0 END) AS missing_term,
   SUM(CASE WHEN int_rate IS NULL THEN 1 ELSE 0 END) AS missing_int_rate,
   SUM(CASE WHEN grade IS NULL THEN 1 ELSE 0 END) AS missing_grade,
   SUM(CASE WHEN annual_inc IS NULL THEN 1 ELSE 0 END) AS missing_annual_inc,
   SUM(CASE WHEN loan_status IS NULL THEN 1 ELSE 0 END) AS missing_loan_status,
   SUM(CASE WHEN purpose IS NULL THEN 1 ELSE 0 END) AS missing_purpose,
   SUM(CASE WHEN dti IS NULL THEN 1 ELSE 0 END) AS missing_dti,
   SUM(CASE WHEN risk_score IS NULL THEN 1 ELSE 0 END) AS missing_risk_score,
   SUM(CASE WHEN issue_date IS NULL THEN 1 ELSE 0 END) AS missing_issue_date
FROM my-project-1999-467013.loan_practice.loan

--1.2 Check for duplicates
SELECT loan_id, COUNT(*) AS duplicate_count
FROM my-project-1999-467013.loan_practice.loan
GROUP BY loan_id
HAVING COUNT(*) > 1

--1.3 Check distinct combinations 
SELECT DISTINCT loan_status,purpose
FROM my-project-1999-467013.loan_practice.loan

--1.4 Create a cleaned version of loan table
CREATE TABLE my-project-1999-467013.loan_practice.loan_cleaned AS
  SELECT *,
  CASE 
    WHEN TRIM(LOWER(loan_status)) IN ('charged off','charged offf')THEN 'Charged Off'
    WHEN TRIM(LOWER(loan_status)) = 'fully paid' THEN 'Fully Paid'
    ELSE 'Unknown'
    END AS loan_status_cleaned,
  TRIM(LOWER(purpose)) AS purpose_cleaned
FROM my-project-1999-467013.loan_practice.loan
WHERE annual_inc IS NOT NULL
     AND dti IS NOT NULL
     AND risk_score IS NOT NULL

--1.5 Check for duplicate rows
SELECT *,
       COUNT(*) OVER (PARTITION BY loan_status, purpose, loan_amnt) AS row_count
FROM my-project-1999-467013.loan_practice.loan_cleaned

--1.6 Clean and standardize the issue date
-- STEP 1: Load and Clean the Raw Data into `loan_cleaned2`
CREATE TABLE `my-project-1999-467013.loan_practice.loan_cleaned2` AS
SELECT *,
  -- Clean and standardize the issue date
  CASE 
    WHEN REGEXP_CONTAINS(issue_date, r'^\d{4}-\d{2}$') 
      THEN PARSE_DATE('%Y-%m', issue_date)
    WHEN REGEXP_CONTAINS(issue_date, r'^\d{4}/\d{2}$') 
      THEN PARSE_DATE('%Y-%m', REPLACE(issue_date, '/', '-'))
    WHEN REGEXP_CONTAINS(issue_date, r'^\d{4}\.\d{2}$') 
      THEN PARSE_DATE('%Y-%m', REPLACE(issue_date, '.', '-'))
    WHEN REGEXP_CONTAINS(issue_date, r'^[A-Za-z]{3}-\d{4}$') 
      THEN PARSE_DATE('%d-%b-%Y', CONCAT('01-', issue_date))
    ELSE NULL
  END AS issue_date_cleaned,

  -- Standardize the loan term
  CASE 
    WHEN TRIM(term) IN ('36', '36 months') THEN '36 months'
    WHEN TRIM(term) IN ('60', '60') THEN '60 months'
    ELSE 'Unknown'
  END AS term_cleaned,

  -- Standardize interest rate as percentage (if it was a decimal)
  CASE 
    WHEN int_rate <= 1 THEN ROUND(int_rate * 100, 2)
    ELSE int_rate
  END AS int_rate_percent

FROM `my-project-1999-467013.loan_practice.loan_cleaned`
WHERE int_rate > 0;


--==========================
--STEP 2: DATA ANALYSIS
--==========================

-- 2.1: Loan Status Distribution
SELECT loan_status, COUNT(*) AS total_loans
FROM `my-project-1999-467013.loan_practice.loan_cleaned2`
GROUP BY loan_status;

-- 2.2: Average Interest Rate by Purpose
SELECT purpose, ROUND(AVG(int_rate_percent), 2) AS avg_int_rate
FROM `my-project-1999-467013.loan_practice.loan_cleaned2`
GROUP BY purpose
ORDER BY avg_int_rate DESC;

-- 2.3: Average Risk Score by Loan Status
SELECT loan_status, ROUND(AVG(risk_score), 2) AS avg_risk_score
FROM `my-project-1999-467013.loan_practice.loan_cleaned2`
WHERE risk_score IS NOT NULL
GROUP BY loan_status;

-- 2.4: Default Rate by Term
SELECT 
  term_cleaned,
  COUNTIF(loan_status = 'Charged Off') * 100.0 / COUNT(*) AS default_rate_percent
FROM `my-project-1999-467013.loan_practice.loan_cleaned2`
GROUP BY term_cleaned;

-- 2.5: Income vs Default
SELECT 
  loan_status,
  ROUND(AVG(annual_inc), 2) AS avg_income
FROM `my-project-1999-467013.loan_practice.loan_cleaned2`
WHERE annual_inc IS NOT NULL
GROUP BY loan_status;

-- 2.5.1: Income Brackets vs Default
SELECT 
  CASE 
    WHEN annual_inc < 25000 THEN '<25K'
    WHEN annual_inc < 50000 THEN '25K–50K'
    WHEN annual_inc < 75000 THEN '50K–75K'
    WHEN annual_inc < 100000 THEN '75K–100K'
    ELSE '>100K'
  END AS income_bracket,
  COUNT(*) AS total_loans,
  COUNTIF(loan_status = 'Charged Off') * 100.0 / COUNT(*) AS default_rate_percent
FROM `my-project-1999-467013.loan_practice.loan_final`
GROUP BY income_bracket
ORDER BY income_bracket;


-- 2.6: Monthly Default Trends
SELECT 
  FORMAT_DATE('%Y-%m', issue_date_cleaned) AS issue_month,
  COUNTIF(loan_status = 'Charged Off') AS num_defaults,
  COUNT(*) AS total_loans,
  ROUND(COUNTIF(loan_status = 'Charged Off') * 100.0 / COUNT(*), 2) AS default_rate_percent
FROM `my-project-1999-467013.loan_practice.loan_cleaned2`
WHERE issue_date_cleaned IS NOT NULL
GROUP BY issue_month
ORDER BY issue_month;

