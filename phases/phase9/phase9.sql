-- PHASE 9 — Ministry of Health reporting and analytics
-- Supplies monthly OPD, top diagnosis, revenue by service, moving-average and return-visit queries.
--
-- Source: MediLink strategy, Appendix B — Phase-by-phase MySQL 8.0
-- SQL implementation scripts. Run phases sequentially in one schema.

Supplies monthly OPD, top diagnosis, revenue by service, moving-average and return-visit queries.
USE medilink;
 
-- A. Monthly OPD attendance by district and clinic; detail plus roll-up rows.
SELECT dc.district,dc.clinic_name,DATE_FORMAT(f.visit_date,'%Y-%m') AS year_month,
       COUNT(*) AS visit_count
FROM fact_visits f
JOIN dim_clinic dc ON dc.clinic_sk=f.clinic_sk
WHERE f.visit_type='OPD'
GROUP BY dc.district,dc.clinic_name,year_month WITH ROLLUP;
 
-- B. Top 10 diagnosis codes for the reporting period.
SET @report_start = DATE_SUB(DATE_FORMAT(CURDATE(),'%Y-%m-01'), INTERVAL 1 MONTH);
SET @report_end = DATE_FORMAT(CURDATE(),'%Y-%m-01');
 
SELECT diagnosis_code,COUNT(*) AS cases
FROM fact_visits
WHERE visit_date >= @report_start AND visit_date < @report_end
  AND diagnosis_code IS NOT NULL
GROUP BY diagnosis_code
ORDER BY cases DESC,diagnosis_code
LIMIT 10;
 
-- C. Revenue by service category. This query reads operational billing to preserve service detail.
SELECT DATE_FORMAT(v.visit_date,'%Y-%m') AS year_month,b.service,
       SUM(b.amount) AS revenue
FROM visits v
JOIN billing b ON b.visit_id=v.visit_id
WHERE v.visit_date >= @report_start AND v.visit_date < @report_end
GROUP BY year_month,b.service
ORDER BY year_month,b.service;
 
-- D. Three-month moving average of monthly visit counts.
SELECT year_month,visits,
       ROUND(AVG(visits) OVER (ORDER BY year_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),1)
         AS moving_average_3_month
FROM (
  SELECT DATE_FORMAT(visit_date,'%Y-%m') AS year_month,COUNT(*) AS visits
  FROM fact_visits GROUP BY DATE_FORMAT(visit_date,'%Y-%m')
) monthly
ORDER BY year_month;
 
-- E. Return-visit indicator: next visit within 30 days. This is an operational indicator,
-- not a clinical readmission measure unless approved clinical definitions support that label.
WITH ordered_visits AS (
  SELECT patient_sk,visit_date,
         LEAD(visit_date) OVER (PARTITION BY patient_sk ORDER BY visit_date) AS next_visit_date
  FROM fact_visits
)
SELECT ROUND(100.0*SUM(next_visit_date IS NOT NULL
                        AND DATEDIFF(next_visit_date,visit_date)<=30)
             / NULLIF(SUM(next_visit_date IS NOT NULL),0),1) AS next_visit_within_30d_pct
FROM ordered_visits;

-- Required evidence: 9 | Three MoH report result sets and dashboard screenshots | Attendance, top-10 diagnoses and revenue by service are reproducible | To be completed after execution
