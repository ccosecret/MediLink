-- PHASE 4 — Data quality profiling, cleansing and scorecard
-- Profiles source quality, standardises phone/sex/date fields and queues records that cannot be safely repaired.
--
-- Source: MediLink strategy, Appendix B — Phase-by-phase MySQL 8.0
-- SQL implementation scripts. Run phases sequentially in one schema.

Profiles source quality, standardises phone/sex/date fields and queues records that cannot be safely repaired.
USE medilink;
 
CREATE TABLE IF NOT EXISTS stg_legacy_a (
  src_id INT PRIMARY KEY,
  pname VARCHAR(120),
  phone_no VARCHAR(25),
  gender VARCHAR(10),
  dob_raw VARCHAR(25),
  nid VARCHAR(25),
  last_visit DATE,
  name_clean VARCHAR(120) NULL,
  phone_norm VARCHAR(12) NULL,
  sex_clean ENUM('M','F') NULL,
  dob_clean DATE NULL
);
 
INSERT INTO stg_legacy_a (src_id,pname,phone_no,gender,dob_raw,nid,last_visit) VALUES
 (1,'nakato sarah','0772 100 001','F','1990-05-12','CM90123456ABC','2024-11-02'),
 (2,'NAKATO SARAH','256772100001','Female','12/05/1990','','2025-01-15'),
 (3,'Okello John ','+256772100002','M','1985-3-3','CM85112233','2024-12-20'),
 (4,'acheb gloria','0771003003','f','','','2025-02-01'),
 (5,'Mwesigwa D','0782 455 901','male','1978/09/22','CM78998877','2024-10-30'),
 (6,'Unknown Child','0','M','','','2025-02-03')
ON DUPLICATE KEY UPDATE pname=VALUES(pname), phone_no=VALUES(phone_no),
 gender=VALUES(gender), dob_raw=VALUES(dob_raw), nid=VALUES(nid), last_visit=VALUES(last_visit);
 
CREATE TABLE IF NOT EXISTS stg_legacy_b (
  src_id INT PRIMARY KEY,
  name VARCHAR(120),
  phone VARCHAR(25),
  email VARCHAR(120),
  sex VARCHAR(10),
  dob DATE,
  updated_at DATE,
  name_clean VARCHAR(120) NULL,
  phone_norm VARCHAR(12) NULL,
  sex_clean ENUM('M','F') NULL
);
 
INSERT INTO stg_legacy_b (src_id,name,phone,email,sex,dob,updated_at) VALUES
 (101,'Sarah Nakato','256772100001','s.nakato@gmail.com','F','1990-05-12','2025-03-01'),
 (102,'J. Okello','0772100002','okello.j@outlook.com','M','1985-03-03','2025-02-10'),
 (103,'Gloria Acheb','256771003003',NULL,'F',NULL,'2025-01-20')
ON DUPLICATE KEY UPDATE name=VALUES(name), phone=VALUES(phone), email=VALUES(email),
 sex=VALUES(sex), dob=VALUES(dob), updated_at=VALUES(updated_at);
 
-- PROFILE BEFORE cleansing
SELECT COUNT(*) AS total_rows,
       ROUND(100.0*SUM(nid IS NOT NULL AND TRIM(nid)<> '')/NULLIF(COUNT(*),0),1) AS nid_complete_pct,
       ROUND(100.0*SUM(gender IS NOT NULL AND TRIM(gender)<> '')/NULLIF(COUNT(*),0),1) AS gender_complete_pct
FROM stg_legacy_a;
 
SELECT src_id, phone_no
FROM stg_legacy_a
WHERE phone_no IS NULL
   OR LENGTH(REGEXP_REPLACE(phone_no,'[^0-9]','')) NOT IN (10,12)
   OR (LENGTH(REGEXP_REPLACE(phone_no,'[^0-9]',''))=12
       AND REGEXP_REPLACE(phone_no,'[^0-9]','') NOT REGEXP '^256[0-9]{9}$');
 
SELECT DISTINCT gender FROM stg_legacy_a;
 
-- CLEANSE. Unknown or ambiguous values become NULL and are sent for review; do not guess.
UPDATE stg_legacy_a
SET name_clean = CONCAT(UPPER(LEFT(TRIM(pname),1)), LOWER(SUBSTRING(TRIM(pname),2))),
    phone_norm = CASE
      WHEN LENGTH(REGEXP_REPLACE(phone_no,'[^0-9]',''))=12
       AND REGEXP_REPLACE(phone_no,'[^0-9]','') REGEXP '^256[0-9]{9}$'
        THEN REGEXP_REPLACE(phone_no,'[^0-9]','')
      WHEN LENGTH(REGEXP_REPLACE(phone_no,'[^0-9]',''))=10
       AND REGEXP_REPLACE(phone_no,'[^0-9]','') REGEXP '^0[0-9]{9}$'
        THEN CONCAT('256',SUBSTRING(REGEXP_REPLACE(phone_no,'[^0-9]',''),2))
      ELSE NULL END,
    sex_clean = CASE UPPER(TRIM(gender))
      WHEN 'M' THEN 'M' WHEN 'MALE' THEN 'M'
      WHEN 'F' THEN 'F' WHEN 'FEMALE' THEN 'F' ELSE NULL END,
    dob_clean = CASE
      WHEN TRIM(dob_raw) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        THEN STR_TO_DATE(dob_raw,'%Y-%m-%d')
      WHEN TRIM(dob_raw) REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
        THEN STR_TO_DATE(dob_raw,'%d/%m/%Y')
      WHEN TRIM(dob_raw) REGEXP '^[0-9]{4}/[0-9]{2}/[0-9]{2}$'
        THEN STR_TO_DATE(dob_raw,'%Y/%m/%d')
      ELSE NULL END;
 
CREATE TABLE IF NOT EXISTS dq_review_queue (
  review_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  source_system VARCHAR(30) NOT NULL,
  source_record_id VARCHAR(50) NOT NULL,
  issue_code VARCHAR(50) NOT NULL,
  issue_detail VARCHAR(300) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  resolved_by VARCHAR(100) NULL,
  resolved_at DATETIME NULL,
  UNIQUE KEY uq_dq_issue (source_system,source_record_id,issue_code)
);
 
INSERT IGNORE INTO dq_review_queue (source_system,source_record_id,issue_code,issue_detail)
SELECT 'LEGACY_A',CAST(src_id AS CHAR),'INVALID_OR_MISSING_PHONE',
       CONCAT('Raw phone value: ',COALESCE(phone_no,'NULL'))
FROM stg_legacy_a WHERE phone_norm IS NULL;
 
CREATE OR REPLACE VIEW v_dq_scorecard AS
SELECT COUNT(*) AS total_patients,
       ROUND(100.0*SUM(phone IS NOT NULL)/NULLIF(COUNT(*),0),1) AS phone_complete_pct,
       ROUND(100.0*SUM(date_of_birth IS NOT NULL)/NULLIF(COUNT(*),0),1) AS dob_complete_pct,
       ROUND(100.0*SUM(sex IS NOT NULL)/NULLIF(COUNT(*),0),1) AS sex_complete_pct,
       SUM(phone IS NOT NULL AND phone NOT REGEXP '^256[0-9]{9}$') AS invalid_phones
FROM m_patient;
 
SELECT * FROM v_dq_scorecard;
SELECT * FROM dq_review_queue ORDER BY created_at DESC;

-- Required evidence: 4 | Before/after profiling and v_dq_scorecard | Measured completeness/invalid values, with counts and denominator | To be completed after execution
