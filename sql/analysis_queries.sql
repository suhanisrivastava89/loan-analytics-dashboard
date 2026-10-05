-- Loan Analytics: SQL analysis (SQLite)
-- Table: loans (cleaned data from data/processed/loans_clean.csv)
-- Default rate = Charged Off / (Charged Off + Fully Paid).
-- "Current" loans have no known outcome (default_flag is NULL) and are excluded from default-rate denominators.

-- 1. Monthly loan volume and amount funded
SELECT issue_month,
       COUNT(*) AS loans,
       SUM(loan_amount) AS total_funded,
       ROUND(AVG(loan_amount), 0) AS avg_loan
FROM loans
GROUP BY issue_month
ORDER BY issue_month;

-- 2. Default rate by grade
SELECT grade,
       COUNT(*) AS loans_with_outcome,
       SUM(default_flag) AS defaults,
       ROUND(100.0 * SUM(default_flag) / COUNT(*), 2) AS default_rate_pct
FROM loans
WHERE default_flag IS NOT NULL
GROUP BY grade
ORDER BY grade;

-- 3. Month-over-month growth in loan volume
WITH monthly AS (
    SELECT issue_month, COUNT(*) AS loans
    FROM loans
    GROUP BY issue_month
)
SELECT issue_month,
       loans,
       LAG(loans) OVER (ORDER BY issue_month) AS prev_month_loans,
       ROUND(100.0 * (loans - LAG(loans) OVER (ORDER BY issue_month))
             / LAG(loans) OVER (ORDER BY issue_month), 1) AS growth_pct
FROM monthly;

-- 4. Regional performance
SELECT region,
       COUNT(*) AS loans,
       SUM(loan_amount) AS total_funded,
       ROUND(AVG(loan_amount), 0) AS avg_loan,
       ROUND(100.0 * SUM(default_flag) / COUNT(default_flag), 2) AS default_rate_pct
FROM loans
GROUP BY region
ORDER BY total_funded DESC;

-- 5. Top 5 states by amount funded
SELECT address_state,
       COUNT(*) AS loans,
       SUM(loan_amount) AS total_funded,
       ROUND(AVG(loan_amount), 0) AS avg_loan
FROM loans
GROUP BY address_state
ORDER BY total_funded DESC
LIMIT 5;

-- 6. Default rate by employment length
SELECT CASE WHEN emp_length_years = 0 THEN '0 (under 1 yr)'
            WHEN emp_length_years <= 4 THEN '1-4 yrs'
            WHEN emp_length_years <= 9 THEN '5-9 yrs'
            ELSE '10+ yrs' END AS emp_group,
       COUNT(default_flag) AS loans_with_outcome,
       ROUND(100.0 * SUM(default_flag) / COUNT(default_flag), 2) AS default_rate_pct
FROM loans
GROUP BY emp_group
ORDER BY MIN(emp_length_years);

-- 7. Default rate by income verification status
SELECT verification_status,
       COUNT(default_flag) AS loans_with_outcome,
       ROUND(100.0 * SUM(default_flag) / COUNT(default_flag), 2) AS default_rate_pct
FROM loans
GROUP BY verification_status
ORDER BY default_rate_pct DESC;

-- 8. Term vs interest rate vs default rate
SELECT term_months,
       COUNT(*) AS loans,
       ROUND(AVG(int_rate) * 100, 2) AS avg_interest_pct,
       ROUND(100.0 * SUM(default_flag) / COUNT(default_flag), 2) AS default_rate_pct
FROM loans
GROUP BY term_months;

-- 9. High-DTI customers (DTI >= 20%) and their observed outcomes
SELECT loan_status,
       COUNT(*) AS loans
FROM loans
WHERE dti_pct >= 20
GROUP BY loan_status;

-- 10. Highest-risk segments (grade x purpose, at least 100 loans with known outcome)
SELECT grade,
       purpose,
       COUNT(default_flag) AS loans_with_outcome,
       ROUND(100.0 * SUM(default_flag) / COUNT(default_flag), 2) AS default_rate_pct
FROM loans
WHERE default_flag IS NOT NULL
GROUP BY grade, purpose
HAVING COUNT(default_flag) >= 100
ORDER BY default_rate_pct DESC
LIMIT 5;