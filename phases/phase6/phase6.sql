-- PHASE 6 — ETL into dimensional warehouse
-- Builds dimensions and visit fact table and performs an upsert-style ETL load.
--
-- Source: MediLink strategy, Appendix B — Phase-by-phase MySQL 8.0
-- SQL implementation scripts. Run phases sequentially in one schema.

Builds dimensions and visit fact table and performs an upsert-style ETL load.
USE medilink;
 
CREATE TABLE IF NOT EXISTS dim_clinic (
  clinic_sk INT AUTO_INCREMENT PRIMARY KEY,
  clinic_id INT NOT NULL UNIQUE,
  clinic_code VARCHAR(10) NOT NULL,
  clinic_name VARCHAR(100) NOT NULL,
  district VARCHAR(60) NOT NULL
);
 
CREATE TABLE IF NOT EXISTS dim_patient (
  patient_sk BIGINT AUTO_INCREMENT PRIMARY KEY,
  patient_key BIGINT NOT NULL UNIQUE,
  sex CHAR(1) NULL,
  age_band VARCHAR(10) NOT NULL,
  home_district VARCHAR(60) NULL
);
 
CREATE TABLE IF NOT EXISTS dim_date (
  date_key DATE PRIMARY KEY,
  yr SMALLINT NOT NULL,
  qtr TINYINT NOT NULL,
  mo TINYINT NOT NULL,
  mo_name VARCHAR(12) NOT NULL,
  dow VARCHAR(10) NOT NULL
);
 
CREATE TABLE IF NOT EXISTS fact_visits (
  visit_sk BIGINT AUTO_INCREMENT PRIMARY KEY,
  source_visit_id BIGINT NOT NULL UNIQUE,
  visit_date DATE NOT NULL,
  clinic_sk INT NOT NULL,
  patient_sk BIGINT NOT NULL,
  visit_type VARCHAR(20) NOT NULL,
  diagnosis_code VARCHAR(10) NULL,
  consult_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  lab_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  med_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  other_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  total_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  KEY idx_fact_visit_date (visit_date),
  CONSTRAINT fk_fact_clinic FOREIGN KEY (clinic_sk) REFERENCES dim_clinic(clinic_sk),
  CONSTRAINT fk_fact_patient FOREIGN KEY (patient_sk) REFERENCES dim_patient(patient_sk)
);
 
INSERT INTO dim_clinic (clinic_id,clinic_code,clinic_name,district)
SELECT clinic_id,clinic_code,clinic_name,district FROM clinics
ON DUPLICATE KEY UPDATE clinic_code=VALUES(clinic_code),
  clinic_name=VALUES(clinic_name),district=VALUES(district);
 
INSERT INTO dim_patient (patient_key,sex,age_band,home_district)
SELECT patient_key,sex,
 CASE WHEN date_of_birth IS NULL THEN 'UNKNOWN'
      WHEN TIMESTAMPDIFF(YEAR,date_of_birth,CURDATE())<5 THEN '0-4'
      WHEN TIMESTAMPDIFF(YEAR,date_of_birth,CURDATE())<18 THEN '5-17'
      WHEN TIMESTAMPDIFF(YEAR,date_of_birth,CURDATE())<60 THEN '18-59'
      ELSE '60+' END,
 home_district
FROM m_patient WHERE status='ACTIVE'
ON DUPLICATE KEY UPDATE sex=VALUES(sex),age_band=VALUES(age_band),
  home_district=VALUES(home_district);
 
-- Date dimension from observed visits, with a 30-day margin.
-- Populate observed visit dates. Extend this to a full calendar range if the BI model needs dates without visits.
INSERT IGNORE INTO dim_date (date_key,yr,qtr,mo,mo_name,dow)
SELECT DISTINCT DATE(visit_date), YEAR(visit_date), QUARTER(visit_date),
       MONTH(visit_date), MONTHNAME(visit_date), DAYNAME(visit_date)
FROM visits
WHERE visit_date IS NOT NULL;
 
-- Idempotent load: one fact per source visit; billing categories are aggregated first.
INSERT INTO fact_visits
 (source_visit_id,visit_date,clinic_sk,patient_sk,visit_type,diagnosis_code,
  consult_amount,lab_amount,med_amount,other_amount,total_amount)
SELECT v.visit_id,DATE(v.visit_date),dc.clinic_sk,dp.patient_sk,v.visit_type,v.diagnosis_code,
       SUM(CASE WHEN b.service='CONSULTATION' THEN b.amount ELSE 0 END),
       SUM(CASE WHEN b.service='LAB' THEN b.amount ELSE 0 END),
       SUM(CASE WHEN b.service='MEDICATION' THEN b.amount ELSE 0 END),
       SUM(CASE WHEN b.service IN ('ADMISSION','PROCEDURE') THEN b.amount ELSE 0 END),
       SUM(COALESCE(b.amount,0))
FROM visits v
JOIN dim_clinic dc ON dc.clinic_id=v.clinic_id
JOIN dim_patient dp ON dp.patient_key=v.patient_key
LEFT JOIN billing b ON b.visit_id=v.visit_id
GROUP BY v.visit_id,DATE(v.visit_date),dc.clinic_sk,dp.patient_sk,v.visit_type,v.diagnosis_code
ON DUPLICATE KEY UPDATE visit_date=VALUES(visit_date),clinic_sk=VALUES(clinic_sk),
 patient_sk=VALUES(patient_sk),visit_type=VALUES(visit_type),diagnosis_code=VALUES(diagnosis_code),
 consult_amount=VALUES(consult_amount),lab_amount=VALUES(lab_amount),
 med_amount=VALUES(med_amount),other_amount=VALUES(other_amount),total_amount=VALUES(total_amount);
 
SELECT COUNT(*) AS loaded_visits, SUM(total_amount) AS loaded_revenue FROM fact_visits;

-- Required evidence: 6 | Row counts and sample fact rows | Warehouse rows reconcile to source visits and billing totals | To be completed after execution
