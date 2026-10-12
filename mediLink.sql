-- MediLink Health Network Enterprise Data Management Project
-- Consolidated MySQL 8.0+ phase scripts — Safe Update Mode revision 4
-- Revision 4 gap-fill against the coursework brief and strategy appendices:
--   Phase 2  - completed policy register (Data Quality, Billing Integrity,
--              Metadata and Source Trust) and expanded compliance_register;
--              requirement is now UNIQUE so the upsert is idempotent.
--   Phase 4  - added paper-digitisation staging (operator/capture/verification);
--              v_dq_scorecard now reports potential_dupes.
--   Phase 6  - added synthetic demo data (staff/patients/visits/billing) and
--              etl_load_log (batch id, row counts, status).
--   Phase 7  - completed glossary terms and lineage rows (idempotent upsert).
--   Phase 8  - added billing / v_patient_directory / master_audit to
--              data_classification; master INSERT/DELETE audit triggers;
--              auditor metadata/log grants.
--   Phase 10 - dq_scorecard_log now records potential_dupes.
-- READ BEFORE RUNNING:
-- 1) Execute phases in order, in a DEVELOPMENT database, and capture real outputs.
-- 2) Review each phase for local environment and legal requirements before production.
-- 3) Phase 8 role/trigger/event creation requires suitable privileges.
-- 4) Sample records are fictional project data; never load real patient data into a demo.
-- 5) Do not claim metrics or tests passed until the SQL has been run and evidence saved.
-- 6) Safe update mode is not disabled. UPDATE statements include indexed-key predicates.
-- 7) Run in MySQL 8.0+ using a SQL client that supports DELIMITER (e.g. mysql CLI/Workbench).


----------------------------------------------------------------------------------------
-- PHASE 0 — Environment setup and source inventory
----------------------------------------------------------------------------------------
-- MySQL 8.0+
-- Run once in a development environment. Choose an account with CREATE DATABASE privileges.
CREATE DATABASE IF NOT EXISTS medilink
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE medilink;

CREATE TABLE IF NOT EXISTS source_inventory (
  source_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  source_name VARCHAR(100) NOT NULL UNIQUE,
  source_owner VARCHAR(120) NOT NULL,
  source_format ENUM('RELATIONAL_DB','CSV','SPREADSHEET','PAPER','API','OTHER') NOT NULL,
  estimated_rows BIGINT NULL,
  quality_rating ENUM('HIGH','MEDIUM','LOW','UNKNOWN') NOT NULL DEFAULT 'UNKNOWN',
  contains_personal_data BOOLEAN NOT NULL DEFAULT TRUE,
  registered_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  notes VARCHAR(500)
);

INSERT INTO source_inventory
  (source_name, source_owner, source_format, estimated_rows, quality_rating, notes)
VALUES
  ('Legacy A', 'Kampala Clinic Data Owner', 'RELATIONAL_DB', NULL, 'LOW',
   'Legacy patient registration; mixed phone and date formats'),
  ('Legacy B', 'Network Booking Manager', 'RELATIONAL_DB', NULL, 'MEDIUM',
   'Online booking data; includes email and update timestamp'),
  ('Paper Scan', 'Gulu Clinic Records Officer', 'PAPER', NULL, 'UNKNOWN',
   'Paper registration records require controlled digitisation'),
  ('Pharmacy POS', 'Finance/Pharmacy Owner', 'CSV', NULL, 'UNKNOWN',
   'Register exact export location, frequency and owner before production use')
ON DUPLICATE KEY UPDATE
  source_owner = VALUES(source_owner),
  source_format = VALUES(source_format),
  quality_rating = VALUES(quality_rating),
  notes = VALUES(notes);

SELECT * FROM source_inventory ORDER BY source_name;

----------------------------------------------------------------------------------------
-- PHASE 1 — Data lifecycle policy
----------------------------------------------------------------------------------------
USE medilink;

CREATE TABLE IF NOT EXISTS data_lifecycle_policy (
  data_class VARCHAR(50) PRIMARY KEY,
  retention_years INT NOT NULL,
  archive_after_years INT NOT NULL,
  lawful_basis VARCHAR(150),
  owner VARCHAR(120) NOT NULL,
  lifecycle_notes VARCHAR(400),
  CONSTRAINT chk_lifecycle_years
    CHECK (retention_years >= 0 AND archive_after_years >= 0
           AND archive_after_years <= retention_years)
);

INSERT INTO data_lifecycle_policy
  (data_class, retention_years, archive_after_years, lawful_basis, owner, lifecycle_notes)
VALUES
  ('CLINICAL', 10, 7, 'Healthcare delivery / applicable legal duty',
   'Head of Clinical Services', 'Archive at year 7; review and purge only after retention expiry'),
  ('BILLING', 7, 5, 'Applicable financial/legal obligation',
   'Finance Manager', 'Confirm statutory retention with legal/finance advisers'),
  ('MARKETING_CONSENT', 2, 1, 'Consent where applicable',
   'Data Steward', 'Retain evidence of consent and withdrawal')
ON DUPLICATE KEY UPDATE
  retention_years = VALUES(retention_years),
  archive_after_years = VALUES(archive_after_years),
  lawful_basis = VALUES(lawful_basis),
  owner = VALUES(owner),
  lifecycle_notes = VALUES(lifecycle_notes);

SELECT * FROM data_lifecycle_policy ORDER BY data_class;

----------------------------------------------------------------------------------------
-- PHASE 2 — Governance framework registers
----------------------------------------------------------------------------------------
USE medilink;

CREATE TABLE IF NOT EXISTS data_ownership (
  object_name VARCHAR(64) PRIMARY KEY,
  data_owner VARCHAR(100) NOT NULL,
  data_steward VARCHAR(100) NOT NULL,
  custodian VARCHAR(100) NOT NULL
);

INSERT INTO data_ownership VALUES
 ('m_patient','Medical Director','Assigned Patient Data Steward','IT Custodian'),
 ('visits','Head of Clinical Services','Clinical Data Steward','IT Custodian'),
 ('billing','Finance Manager','Finance Data Steward','IT Custodian')
ON DUPLICATE KEY UPDATE data_owner=VALUES(data_owner),
  data_steward=VALUES(data_steward), custodian=VALUES(custodian);

CREATE TABLE IF NOT EXISTS raci (
  activity VARCHAR(80) PRIMARY KEY,
  cdo_role ENUM('R','A','C','I','A/R','') NOT NULL DEFAULT '',
  steward_role ENUM('R','A','C','I','A/R','') NOT NULL DEFAULT '',
  custodian_role ENUM('R','A','C','I','A/R','') NOT NULL DEFAULT '',
  clinician_role ENUM('R','A','C','I','A/R','') NOT NULL DEFAULT ''
);

INSERT INTO raci VALUES
 ('Approve new source system','A','R','C','I'),
 ('Resolve duplicate patient','I','A/R','C','C'),
 ('Grant database access','I','C','A/R','I'),
 ('Approve retention/purge','A','R','C','C')
ON DUPLICATE KEY UPDATE cdo_role=VALUES(cdo_role),
  steward_role=VALUES(steward_role), custodian_role=VALUES(custodian_role),
  clinician_role=VALUES(clinician_role);

CREATE TABLE IF NOT EXISTS policies (
  policy_id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(100) NOT NULL UNIQUE,
  rule_summary VARCHAR(500) NOT NULL,
  enforcement ENUM('MANUAL','TECHNICAL','BOTH') NOT NULL,
  policy_owner VARCHAR(120) NOT NULL
);

INSERT INTO policies (title, rule_summary, enforcement, policy_owner) VALUES
 ('Patient Identity Policy','One golden patient record; phone is a candidate match key; identity conflicts require steward review.','BOTH','Medical Director'),
 ('Data Quality Policy','Phone completeness >=97%; zero invalid normalised phones; weekly monitoring and logged exceptions with named owners.','BOTH','Data Steward'),
 ('Access Control Policy','Least privilege; reception uses masked directory; analysts access de-identified warehouse only.','TECHNICAL','IT Security Owner'),
 ('Retention Policy','Use approved lifecycle schedule; archive then authorised purge after retention expiry.','BOTH','Data Governance Lead'),
 ('Billing Integrity Policy','Billing rows are immutable; corrections are recorded as adjustment rows linked to the original bill, never edits.','TECHNICAL','Finance Manager'),
 ('Metadata and Source Trust Policy','Every source system must register owner, definitions and lineage before its data is trusted.','MANUAL','Data Steward')
ON DUPLICATE KEY UPDATE rule_summary=VALUES(rule_summary),
  enforcement=VALUES(enforcement), policy_owner=VALUES(policy_owner);

CREATE TABLE IF NOT EXISTS compliance_register (
  req_id INT AUTO_INCREMENT PRIMARY KEY,
  requirement VARCHAR(200) NOT NULL UNIQUE,
  current_state VARCHAR(300) NOT NULL,
  gap_status ENUM('CLOSED','PARTIAL','OPEN') NOT NULL,
  remediation VARCHAR(300) NOT NULL,
  evidence_reference VARCHAR(255) NULL,
  reviewed_at DATETIME NULL
);

INSERT INTO compliance_register
  (requirement,current_state,gap_status,remediation,evidence_reference)
VALUES
 ('National ID not stored in plaintext','Legacy extract may contain plaintext ID','OPEN',
  'Hash at controlled ingestion; restrict and remove plaintext staging data after validation',NULL),
 ('Sensitive data disclosure','Patient HIV status was emailed to an unintended recipient with no response procedure','OPEN',
  'Minimum-necessary exports, approved recipients, encrypted transfer, access logs and documented incident response',NULL),
 ('Access segregation','No reliable role-specific access in the legacy scenario','OPEN',
  'Masked reception view; clinician access; de-identified analyst access; auditor read-only audit access',NULL),
 ('Retention and disposal','Unclear what may be deleted','OPEN',
  'Approved lifecycle schedule, archive/purge approvals, logs and restore testing in non-production',NULL),
 ('Master-data change audit','Ownership and trust of master changes are unclear','OPEN',
  'Master audit trail capturing actor, timestamp and changed fields for every master change',NULL),
 ('Source trust and metadata','Owners, definitions and lineage not registered consistently','OPEN',
  'Catalogue registration gate and source approval checklist before any source is trusted',NULL),
 ('Incident response and notification','Formal process not yet evidenced','OPEN',
  'Approve breach playbook and validate applicable notification duties',NULL)
ON DUPLICATE KEY UPDATE current_state=VALUES(current_state),
  gap_status=VALUES(gap_status), remediation=VALUES(remediation);

SELECT * FROM data_ownership;
SELECT * FROM raci;
SELECT * FROM policies;
SELECT * FROM compliance_register;

----------------------------------------------------------------------------------------
-- PHASE 3 — Core master schema and operational model
----------------------------------------------------------------------------------------
USE medilink;

CREATE TABLE IF NOT EXISTS clinics (
  clinic_id INT AUTO_INCREMENT PRIMARY KEY,
  clinic_code VARCHAR(10) NOT NULL UNIQUE,
  clinic_name VARCHAR(100) NOT NULL,
  district VARCHAR(60) NOT NULL
);

INSERT INTO clinics (clinic_code,clinic_name,district) VALUES
 ('MP-KLA','MediLink Kampala','Kampala'),
 ('MP-MUK','MediLink Mukono','Mukono'),
 ('MP-MBR','MediLink Mbarara','Mbarara'),
 ('MP-GUL','MediLink Gulu','Gulu')
ON DUPLICATE KEY UPDATE clinic_name=VALUES(clinic_name), district=VALUES(district);

CREATE TABLE IF NOT EXISTS staff (
  staff_id INT AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(100) NOT NULL,
  staff_role ENUM('DOCTOR','NURSE','LAB','PHARMACIST','ADMIN') NOT NULL,
  clinic_id INT NOT NULL,
  CONSTRAINT fk_staff_clinic FOREIGN KEY (clinic_id) REFERENCES clinics(clinic_id)
);

CREATE TABLE IF NOT EXISTS m_patient (
  patient_key BIGINT AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(120) NOT NULL,
  phone VARCHAR(12) NULL,
  email VARCHAR(120) NULL,
  sex ENUM('M','F') NULL,
  date_of_birth DATE NULL,
  national_id_hash CHAR(64) NULL,
  blood_group ENUM('A+','A-','B+','B-','O+','O-','AB+','AB-') NULL,
  home_district VARCHAR(60) NULL,
  status ENUM('ACTIVE','ARCHIVED') NOT NULL DEFAULT 'ACTIVE',
  source_count SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT chk_patient_phone CHECK (phone IS NULL OR phone REGEXP '^256[0-9]{9}$'),
  INDEX idx_patient_phone (phone)
);

CREATE TABLE IF NOT EXISTS patient_source_links (
  link_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  patient_key BIGINT NOT NULL,
  source_system ENUM('LEGACY_A','LEGACY_B','PHARMACY_POS','PAPER_SCAN') NOT NULL,
  source_record_id VARCHAR(50) NOT NULL,
  matched_on VARCHAR(30) NOT NULL,
  confidence DECIMAL(4,3) NULL,
  linked_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_source_record (source_system,source_record_id),
  CONSTRAINT fk_psl_patient FOREIGN KEY (patient_key) REFERENCES m_patient(patient_key)
);

CREATE TABLE IF NOT EXISTS visits (
  visit_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  patient_key BIGINT NOT NULL,
  clinic_id INT NOT NULL,
  staff_id INT NULL,
  visit_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  visit_type ENUM('OPD','ANC','IMMUNIZATION','ADMISSION','LAB') NOT NULL,
  diagnosis_code VARCHAR(10) NULL COMMENT 'Use the approved clinical coding standard',
  diagnosis_note VARCHAR(200) NULL,
  status ENUM('ACTIVE','ARCHIVED') NOT NULL DEFAULT 'ACTIVE',
  CONSTRAINT fk_visit_patient FOREIGN KEY (patient_key) REFERENCES m_patient(patient_key),
  CONSTRAINT fk_visit_clinic FOREIGN KEY (clinic_id) REFERENCES clinics(clinic_id),
  CONSTRAINT fk_visit_staff FOREIGN KEY (staff_id) REFERENCES staff(staff_id),
  INDEX idx_visits_date (visit_date)
);

CREATE TABLE IF NOT EXISTS billing (
  bill_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  visit_id BIGINT NOT NULL,
  service ENUM('CONSULTATION','LAB','MEDICATION','ADMISSION','PROCEDURE') NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  payment_mode ENUM('CASH','MOBILE_MONEY','INSURANCE') NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_billing_amount CHECK (amount >= 0),
  CONSTRAINT fk_billing_visit FOREIGN KEY (visit_id) REFERENCES visits(visit_id)
);

CREATE TABLE IF NOT EXISTS billing_adjustments (
  adjustment_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  bill_id BIGINT NOT NULL,
  adjustment_amount DECIMAL(12,2) NOT NULL,
  reason VARCHAR(300) NOT NULL,
  approved_by VARCHAR(100) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_adjustment_bill FOREIGN KEY (bill_id) REFERENCES billing(bill_id)
);

SHOW TABLES;

----------------------------------------------------------------------------------------
-- PHASE 4 — Data quality profiling, cleansing and scorecard
----------------------------------------------------------------------------------------
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

-- Paper-digitisation staging (Gulu branch still uses paper). Captures the operator,
-- capture time and verification status so ambiguous scans stay quarantined until a
-- steward reviews them, rather than entering MDM unchecked.
CREATE TABLE IF NOT EXISTS stg_paper_scan (
  scan_id INT PRIMARY KEY,
  patient_name_raw VARCHAR(120) NULL,
  phone_raw VARCHAR(25) NULL,
  sex_raw VARCHAR(10) NULL,
  dob_raw VARCHAR(25) NULL,
  source_clinic VARCHAR(60) NULL,
  captured_by VARCHAR(100) NOT NULL,
  captured_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  verification_status ENUM('PENDING','VERIFIED','REJECTED') NOT NULL DEFAULT 'PENDING',
  verification_notes VARCHAR(300) NULL,
  name_clean VARCHAR(120) NULL,
  phone_norm VARCHAR(12) NULL
);

INSERT INTO stg_paper_scan
  (scan_id,patient_name_raw,phone_raw,sex_raw,dob_raw,source_clinic,captured_by,verification_status,verification_notes)
VALUES
  (201,'Aciro Mary','0772 555 010','F','1992-07-14','MediLink Gulu','Records Officer', 'PENDING','Handwriting ambiguous on surname'),
  (202,'Ochen Denis','0','M','','MediLink Gulu','Records Officer','PENDING','Phone missing; cannot match')
ON DUPLICATE KEY UPDATE patient_name_raw=VALUES(patient_name_raw), phone_raw=VALUES(phone_raw),
  sex_raw=VALUES(sex_raw), dob_raw=VALUES(dob_raw), source_clinic=VALUES(source_clinic),
  captured_by=VALUES(captured_by), verification_status=VALUES(verification_status),
  verification_notes=VALUES(verification_notes);

-- Only VERIFIED scans may be promoted to staging/MDM; the rest remain quarantined.
SELECT scan_id,patient_name_raw,source_clinic,captured_by,verification_notes
FROM stg_paper_scan
WHERE verification_status <> 'VERIFIED'
ORDER BY scan_id;

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
SET name_clean = CONCAT(
        UPPER(LEFT(TRIM(pname), 1)),
        LOWER(SUBSTRING(TRIM(pname), 2))
    ),
    phone_norm = CASE
        WHEN LENGTH(REGEXP_REPLACE(phone_no, '[^0-9]', '')) = 12
         AND REGEXP_REPLACE(phone_no, '[^0-9]', '') REGEXP '^256[0-9]{9}$'
            THEN REGEXP_REPLACE(phone_no, '[^0-9]', '')
        WHEN LENGTH(REGEXP_REPLACE(phone_no, '[^0-9]', '')) = 10
         AND REGEXP_REPLACE(phone_no, '[^0-9]', '') REGEXP '^0[0-9]{9}$'
            THEN CONCAT(
                '256',
                SUBSTRING(REGEXP_REPLACE(phone_no, '[^0-9]', ''), 2)
            )
        ELSE NULL
    END,
    sex_clean = CASE UPPER(TRIM(gender))
        WHEN 'M' THEN 'M'
        WHEN 'MALE' THEN 'M'
        WHEN 'F' THEN 'F'
        WHEN 'FEMALE' THEN 'F'
        ELSE NULL
    END,
    dob_clean = CASE
        WHEN TRIM(dob_raw) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN STR_TO_DATE(TRIM(dob_raw), '%Y-%m-%d')
        WHEN TRIM(dob_raw) REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
            THEN STR_TO_DATE(TRIM(dob_raw), '%d/%m/%Y')
        WHEN TRIM(dob_raw) REGEXP '^[0-9]{4}/[0-9]{2}/[0-9]{2}$'
            THEN STR_TO_DATE(TRIM(dob_raw), '%Y/%m/%d')
        ELSE NULL
    END
WHERE src_id > 0;
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
       SUM(phone IS NOT NULL AND phone NOT REGEXP '^256[0-9]{9}$') AS invalid_phones,
       COUNT(*) - COUNT(DISTINCT CONCAT(full_name,IFNULL(phone,'x'))) AS potential_dupes
FROM m_patient;

SELECT * FROM v_dq_scorecard;
SELECT * FROM dq_review_queue ORDER BY created_at DESC;

----------------------------------------------------------------------------------------
-- PHASE 5 — Master Data Management, survivorship and review queue
----------------------------------------------------------------------------------------
USE medilink;

UPDATE stg_legacy_b
SET name_clean = CONCAT(UPPER(LEFT(TRIM(name),1)),LOWER(SUBSTRING(TRIM(name),2))),
    phone_norm = CASE
      WHEN LENGTH(REGEXP_REPLACE(phone,'[^0-9]',''))=12
       AND REGEXP_REPLACE(phone,'[^0-9]','') REGEXP '^256[0-9]{9}$'
        THEN REGEXP_REPLACE(phone,'[^0-9]','')
      WHEN LENGTH(REGEXP_REPLACE(phone,'[^0-9]',''))=10
       AND REGEXP_REPLACE(phone,'[^0-9]','') REGEXP '^0[0-9]{9}$'
        THEN CONCAT('256',SUBSTRING(REGEXP_REPLACE(phone,'[^0-9]',''),2))
      ELSE NULL END,
    sex_clean = CASE UPPER(TRIM(sex))
      WHEN 'M' THEN 'M' WHEN 'MALE' THEN 'M'
      WHEN 'F' THEN 'F' WHEN 'FEMALE' THEN 'F' ELSE NULL END
WHERE src_id > 0;

CREATE OR REPLACE VIEW v_all_sources AS
SELECT 'LEGACY_A' AS src_system, CAST(src_id AS CHAR) AS src_id,
       phone_norm, name_clean, sex_clean AS sex, dob_clean AS dob,
       NULL AS email, CAST(last_visit AS DATETIME) AS updated_at
FROM stg_legacy_a
UNION ALL
SELECT 'LEGACY_B', CAST(src_id AS CHAR), phone_norm, name_clean,
       sex_clean, dob, email, CAST(updated_at AS DATETIME)
FROM stg_legacy_b;

CREATE TABLE IF NOT EXISTS mdm_review_queue (
  queue_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  src_system VARCHAR(30) NOT NULL,
  src_id VARCHAR(50) NOT NULL,
  reason VARCHAR(100) NOT NULL,
  raised_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  resolved_by VARCHAR(100) NULL,
  resolution VARCHAR(500) NULL,
  resolved_at DATETIME NULL,
  UNIQUE KEY uq_mdm_review (src_system,src_id,reason)
);

-- No-phone rows cannot be matched safely.
INSERT IGNORE INTO mdm_review_queue (src_system,src_id,reason)
SELECT src_system,src_id,'NO_VALID_PHONE'
FROM v_all_sources WHERE phone_norm IS NULL;

-- Stage one candidate per phone. Conflicting identity attributes are queued instead of silently merged.
CREATE TEMPORARY TABLE tmp_phone_groups AS
SELECT phone_norm,
       COUNT(*) AS source_count,
       COUNT(DISTINCT COALESCE(sex,'?')) AS sex_variants,
       COUNT(DISTINCT COALESCE(CAST(dob AS CHAR),'?')) AS dob_variants,
       COUNT(DISTINCT COALESCE(name_clean,'?')) AS name_variants
FROM v_all_sources
WHERE phone_norm IS NOT NULL
GROUP BY phone_norm;

INSERT IGNORE INTO mdm_review_queue (src_system,src_id,reason)
SELECT s.src_system,s.src_id,'IDENTITY_CONFLICT_SAME_PHONE'
FROM v_all_sources s
JOIN tmp_phone_groups g ON g.phone_norm=s.phone_norm
WHERE g.sex_variants>1 OR g.dob_variants>1 OR g.name_variants>1;

-- Initial consolidation is limited to phone groups without identity conflicts.
-- Most-recent source supplies contact fields; identity fields are loaded only when unambiguous.
INSERT INTO m_patient (full_name,phone,email,sex,date_of_birth,source_count)
SELECT ranked.name_clean, ranked.phone_norm, ranked.email, ranked.sex, ranked.dob, ranked.n_src
FROM (
  SELECT s.*,
         ROW_NUMBER() OVER (PARTITION BY phone_norm ORDER BY updated_at DESC,src_system,src_id) AS rn,
         COUNT(*) OVER (PARTITION BY phone_norm) AS n_src
  FROM v_all_sources s
  JOIN tmp_phone_groups g ON g.phone_norm=s.phone_norm
  WHERE s.phone_norm IS NOT NULL
    AND g.sex_variants=1 AND g.dob_variants=1 AND g.name_variants=1
) ranked
WHERE ranked.rn=1
  AND NOT EXISTS (SELECT 1 FROM m_patient m WHERE m.phone=ranked.phone_norm);

-- Crosswalk: link source records only to the approved phone-matched golden record.
INSERT IGNORE INTO patient_source_links
  (patient_key,source_system,source_record_id,matched_on,confidence)
SELECT m.patient_key,s.src_system,s.src_id,'PHONE',0.950
FROM v_all_sources s
JOIN m_patient m ON m.phone=s.phone_norm
WHERE s.phone_norm IS NOT NULL;

SELECT m.patient_key,m.full_name,m.phone,m.email,m.sex,m.date_of_birth,m.source_count,
       GROUP_CONCAT(CONCAT(l.source_system,':',l.source_record_id) ORDER BY l.source_system) AS source_records
FROM m_patient m
JOIN patient_source_links l ON l.patient_key=m.patient_key
GROUP BY m.patient_key,m.full_name,m.phone,m.email,m.sex,m.date_of_birth,m.source_count
ORDER BY m.patient_key;

SELECT * FROM mdm_review_queue WHERE resolved_at IS NULL;

----------------------------------------------------------------------------------------
-- PHASE 6 — ETL into dimensional warehouse
----------------------------------------------------------------------------------------
USE medilink;

-- --------------------------------------------------------------------------------------
-- PHASE 6.0 — Synthetic demo operational data (fictional; for warehouse/report demos only)
-- --------------------------------------------------------------------------------------
-- The hand-out supplies dirty staging data but no visit/billing extracts, so the
-- warehouse and the MoH report would otherwise be empty. The rows below are FICTIONAL
-- demo data inserted directly into the master/operational tables (they do NOT pass
-- through the MDM matching rules). Replace them with real, governed extracts outside a
-- demo. Identifiers are explicit and visit dates are relative to CURDATE() so the
-- monthly/MoH queries always return rows; re-running the script is safe.
--
-- 6.0.1 Staff
INSERT INTO staff (staff_id,full_name,staff_role,clinic_id)
SELECT s.staff_id,s.full_name,s.staff_role,c.clinic_id
FROM (
  SELECT 1 AS staff_id,'Dr Alice Namusoke' AS full_name,'DOCTOR' AS staff_role,'MP-KLA' AS clinic_code
  UNION ALL SELECT 2,'Nurse Brian Ochieng','NURSE','MP-KLA'
  UNION ALL SELECT 3,'Dr Grace Atim','DOCTOR','MP-MUK'
  UNION ALL SELECT 4,'Nurse Denis Ssemakula','NURSE','MP-MBR'
  UNION ALL SELECT 5,'Mary Achieng (Lab)','LAB','MP-GUL'
  UNION ALL SELECT 6,'Peter Tumusiime (Pharmacy)','PHARMACIST','MP-GUL'
  UNION ALL SELECT 7,'Sarah Nakato (Admin)','ADMIN','MP-KLA'
) s
JOIN clinics c ON c.clinic_code=s.clinic_code
ON DUPLICATE KEY UPDATE full_name=VALUES(full_name),staff_role=VALUES(staff_role),
  clinic_id=VALUES(clinic_id);

-- 6.0.2 Synthetic golden patient records (valid 256XXXXXXXXX phones)
INSERT INTO m_patient
  (patient_key,full_name,phone,email,sex,date_of_birth,blood_group,home_district,status,source_count)
VALUES
 (9001,'Namono Grace','256771000001','grace.namono@example.com','F','1990-05-12','O+','Kampala','ACTIVE',1),
 (9002,'Ochieng Brian','256771000002','brian.ochieng@example.com','M','1985-03-03','A+','Gulu','ACTIVE',1),
 (9003,'Auma Patricia','256771000003','patricia.auma@example.com','F','1998-11-20','B+','Mukono','ACTIVE',1),
 (9004,'Ssemakula Denis','256771000004','denis.ssemakula@example.com','M','1978-09-22','O-','Mbarara','ACTIVE',1),
 (9005,'Nabirye Alice','256771000005','alice.nabirye@example.com','F','2001-02-14','AB+','Kampala','ACTIVE',1),
 (9006,'Okello Samuel','256771000006','samuel.okello@example.com','M','1965-07-30','A-','Gulu','ACTIVE',1),
 (9007,'Achieng Mary','256771000007',NULL,'F','2015-06-01',NULL,'Gulu','ACTIVE',1),
 (9008,'Kato Joseph','256771000008',NULL,'M','2019-03-10',NULL,'Mukono','ACTIVE',1),
 (9009,'Nakato Sarah','256771000009','s.nakato@example.com','F','1990-05-12','O+','Kampala','ACTIVE',1),
 (9010,'Mwesigwa Robert','256771000010','robert.mwesigwa@example.com','M','1982-12-05','B-','Mbarara','ACTIVE',1),
 (9011,'Atim Betty','256771000011','betty.atim@example.com','F','1975-04-18','A+','Gulu','ACTIVE',1),
 (9012,'Tumusiime Peter','256771000012','peter.tumusiime@example.com','M','1995-08-25','O+','Mbarara','ACTIVE',1)
ON DUPLICATE KEY UPDATE full_name=VALUES(full_name),phone=VALUES(phone),email=VALUES(email),
  sex=VALUES(sex),date_of_birth=VALUES(date_of_birth),blood_group=VALUES(blood_group),
  home_district=VALUES(home_district),status=VALUES(status);

-- 6.0.3 Visits spread over the last ~4 months (day_offset days before CURDATE())
INSERT INTO visits (visit_id,patient_key,clinic_id,staff_id,visit_date,visit_type,diagnosis_code,diagnosis_note)
SELECT v.vid,v.pkey,c.clinic_id,v.sid,
       DATE_SUB(CURDATE(), INTERVAL v.day_offset DAY),v.vtype,v.dx,NULL
FROM (
  SELECT 1 AS vid,9001 AS pkey,'MP-KLA' AS ccode,1 AS sid,3 AS day_offset,'OPD' AS vtype,'J06' AS dx
  UNION ALL SELECT 2,9002,'MP-GUL',5,3,'OPD','B50'
  UNION ALL SELECT 3,9003,'MP-MUK',3,5,'OPD','J06'
  UNION ALL SELECT 4,9004,'MP-MBR',4,5,'OPD','I10'
  UNION ALL SELECT 5,9005,'MP-KLA',1,8,'OPD','A09'
  UNION ALL SELECT 6,9006,'MP-GUL',5,8,'OPD','E11'
  UNION ALL SELECT 7,9007,'MP-GUL',5,10,'IMMUNIZATION','Z27'
  UNION ALL SELECT 8,9008,'MP-MUK',3,12,'IMMUNIZATION','Z27'
  UNION ALL SELECT 9,9009,'MP-KLA',2,12,'OPD','J06'
  UNION ALL SELECT 10,9010,'MP-MBR',4,15,'OPD','M54'
  UNION ALL SELECT 11,9011,'MP-GUL',5,15,'OPD','I10'
  UNION ALL SELECT 12,9012,'MP-MBR',4,18,'OPD','A09'
  UNION ALL SELECT 13,9001,'MP-KLA',1,20,'ADMISSION','J18'
  UNION ALL SELECT 14,9004,'MP-MBR',4,22,'LAB','B50'
  UNION ALL SELECT 15,9006,'MP-GUL',5,25,'OPD','B50'
  UNION ALL SELECT 16,9002,'MP-GUL',5,25,'OPD','A15'
  UNION ALL SELECT 17,9003,'MP-MUK',3,29,'ANC','O26'
  UNION ALL SELECT 18,9005,'MP-KLA',2,29,'OPD','J06'
  UNION ALL SELECT 19,9008,'MP-MUK',3,32,'IMMUNIZATION','Z27'
  UNION ALL SELECT 20,9009,'MP-KLA',1,36,'OPD','A09'
  UNION ALL SELECT 21,9011,'MP-GUL',5,36,'OPD','E11'
  UNION ALL SELECT 22,9007,'MP-GUL',5,40,'OPD','J06'
  UNION ALL SELECT 23,9010,'MP-MBR',4,43,'ADMISSION','M54'
  UNION ALL SELECT 24,9012,'MP-MBR',4,46,'LAB','B50'
  UNION ALL SELECT 25,9001,'MP-KLA',1,50,'OPD','I10'
  UNION ALL SELECT 26,9004,'MP-MBR',4,50,'OPD','B50'
  UNION ALL SELECT 27,9006,'MP-GUL',5,55,'OPD','B50'
  UNION ALL SELECT 28,9003,'MP-MUK',3,58,'ANC','O26'
  UNION ALL SELECT 29,9002,'MP-GUL',5,60,'OPD','A15'
  UNION ALL SELECT 30,9005,'MP-KLA',1,65,'OPD','J06'
  UNION ALL SELECT 31,9007,'MP-GUL',5,70,'IMMUNIZATION','Z27'
  UNION ALL SELECT 32,9009,'MP-KLA',2,72,'OPD','K30'
  UNION ALL SELECT 33,9011,'MP-GUL',5,80,'OPD','I10'
  UNION ALL SELECT 34,9010,'MP-MBR',4,88,'OPD','M54'
  UNION ALL SELECT 35,9012,'MP-MBR',4,95,'OPD','A09'
  UNION ALL SELECT 36,9001,'MP-KLA',1,100,'OPD','J06'
  UNION ALL SELECT 37,9004,'MP-MBR',4,103,'LAB','B50'
  UNION ALL SELECT 38,9006,'MP-GUL',5,110,'OPD','B50'
  UNION ALL SELECT 39,9003,'MP-MUK',3,115,'ANC','O26'
  UNION ALL SELECT 40,9008,'MP-MUK',3,118,'IMMUNIZATION','Z27'
  UNION ALL SELECT 41,9011,'MP-GUL',5,108,'ADMISSION','I10'
  UNION ALL SELECT 42,9004,'MP-MBR',4,112,'ADMISSION','B50'
) v
JOIN clinics c ON c.clinic_code=v.ccode
ON DUPLICATE KEY UPDATE patient_key=VALUES(patient_key),clinic_id=VALUES(clinic_id),
  staff_id=VALUES(staff_id),visit_date=VALUES(visit_date),visit_type=VALUES(visit_type),
  diagnosis_code=VALUES(diagnosis_code);

-- 6.0.4 Billing. Deterministic bill_id = visit_id*10 + service slot. INSERT IGNORE keeps
-- the in-database billing immutability control intact when the script is re-run.
INSERT IGNORE INTO billing (bill_id,visit_id,service,amount,payment_mode)
SELECT v.visit_id*10+1,v.visit_id,'CONSULTATION',20000.00,
       CASE MOD(v.visit_id,3) WHEN 0 THEN 'CASH' WHEN 1 THEN 'MOBILE_MONEY' ELSE 'INSURANCE' END
FROM visits v WHERE v.visit_type IN ('OPD','ANC');

INSERT IGNORE INTO billing (bill_id,visit_id,service,amount,payment_mode)
SELECT v.visit_id*10+2,v.visit_id,'LAB',15000.00,'CASH'
FROM visits v WHERE v.visit_type='LAB' OR v.diagnosis_code IN ('B50','A15','I10');

INSERT IGNORE INTO billing (bill_id,visit_id,service,amount,payment_mode)
SELECT v.visit_id*10+3,v.visit_id,'MEDICATION',
       CASE WHEN v.diagnosis_code IN ('B50','A15') THEN 12000.00 ELSE 8000.00 END,
       CASE MOD(v.visit_id,2) WHEN 0 THEN 'CASH' ELSE 'MOBILE_MONEY' END
FROM visits v WHERE v.visit_type='OPD';

INSERT IGNORE INTO billing (bill_id,visit_id,service,amount,payment_mode)
SELECT v.visit_id*10+4,v.visit_id,'ADMISSION',120000.00,'INSURANCE'
FROM visits v WHERE v.visit_type='ADMISSION';

INSERT IGNORE INTO billing (bill_id,visit_id,service,amount,payment_mode)
SELECT v.visit_id*10+5,v.visit_id,'PROCEDURE',50000.00,'CASH'
FROM visits v WHERE v.visit_id IN (13,23,42);

SELECT (SELECT COUNT(*) FROM staff) AS staff_rows,
       (SELECT COUNT(*) FROM m_patient) AS patient_rows,
       (SELECT COUNT(*) FROM visits) AS visit_rows,
       (SELECT COUNT(*) FROM billing) AS billing_rows;

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

CREATE TABLE IF NOT EXISTS etl_load_log (
  load_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  load_name VARCHAR(80) NOT NULL,
  run_date DATE NOT NULL,
  source_objects VARCHAR(300) NOT NULL,
  target_object VARCHAR(150) NOT NULL,
  rows_read BIGINT NOT NULL DEFAULT 0,
  rows_loaded BIGINT NOT NULL DEFAULT 0,
  status ENUM('SUCCESS','PARTIAL','FAILED') NOT NULL DEFAULT 'SUCCESS',
  finished_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  notes VARCHAR(400) NULL,
  UNIQUE KEY uq_etl_load (load_name,run_date)
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

-- Operational metadata: record the load batch, row counts and outcome so reports can
-- prove which load they were built from and reruns can be reconciled (§8.1).
INSERT INTO etl_load_log
  (load_name,run_date,source_objects,target_object,rows_read,rows_loaded,status,notes)
SELECT 'WAREHOUSE_LOAD',CURDATE(),'visits + billing','fact_visits',
       (SELECT COUNT(*) FROM visits),(SELECT COUNT(*) FROM fact_visits),
       'SUCCESS','One fact row per visit; billing categories aggregated; idempotent upsert'
ON DUPLICATE KEY UPDATE source_objects=VALUES(source_objects),target_object=VALUES(target_object),
  rows_read=VALUES(rows_read),rows_loaded=VALUES(rows_loaded),status=VALUES(status),
  finished_at=CURRENT_TIMESTAMP,notes=VALUES(notes);

SELECT * FROM etl_load_log ORDER BY run_date DESC;

----------------------------------------------------------------------------------------
-- PHASE 7 — Metadata, glossary and lineage
----------------------------------------------------------------------------------------
USE medilink;

ALTER TABLE visits
  MODIFY diagnosis_code VARCHAR(10) NULL
    COMMENT 'Clinical diagnosis code; use the approved coding standard and version',
  MODIFY visit_type ENUM('OPD','ANC','IMMUNIZATION','ADMISSION','LAB') NOT NULL
    COMMENT 'OPD=outpatient; ANC=antenatal care';

CREATE TABLE IF NOT EXISTS glossary (
  term VARCHAR(80) PRIMARY KEY,
  definition VARCHAR(500) NOT NULL,
  owner VARCHAR(120) NOT NULL,
  sensitivity ENUM('PUBLIC','INTERNAL','CONFIDENTIAL','RESTRICTED') NOT NULL DEFAULT 'INTERNAL'
);

INSERT INTO glossary VALUES
 ('Golden Record','Single governed master record for one patient after approved matching and survivorship.','Patient Data Steward','RESTRICTED'),
 ('OPD Attendance','Count of visit records with visit_type=OPD in the reporting period.','Head of Clinical Services','INTERNAL'),
 ('Revenue','Sum of billing amounts, including approved adjustment handling in the reporting definition.','Finance Manager','CONFIDENTIAL'),
 ('Source Crosswalk','Mapping between a source system record ID and the patient master key.','Patient Data Steward','CONFIDENTIAL'),
 ('Staging','Temporary integration layer used to profile, clean and standardise source extracts before controlled loading.','Warehouse Custodian','CONFIDENTIAL'),
 ('Fact Grain','The business event represented by one row in a fact table; for fact_visits, one row per visit.','Analytics Lead','INTERNAL'),
 ('Data Lineage','Documented path from an original source through transformations to a downstream report or data asset.','Patient Data Steward','INTERNAL')
ON DUPLICATE KEY UPDATE definition=VALUES(definition),owner=VALUES(owner),sensitivity=VALUES(sensitivity);

CREATE TABLE IF NOT EXISTS data_lineage (
  lineage_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  source_object VARCHAR(150) NOT NULL,
  target_object VARCHAR(150) NOT NULL,
  transformation VARCHAR(600) NOT NULL,
  owner VARCHAR(120) NOT NULL,
  last_reviewed DATE NULL,
  UNIQUE KEY uq_lineage (source_object,target_object)
);

INSERT INTO data_lineage (source_object,target_object,transformation,owner) VALUES
 ('Legacy A + Legacy B','stg_legacy_a + stg_legacy_b',
  'Extract raw fields into staging; preserve source IDs and batch details; validate on arrival.',
  'Warehouse Custodian'),
 ('stg_legacy_a + stg_legacy_b','m_patient',
  'Normalize phones; phone groups are candidates; identity conflicts go to steward queue; survivorship applied only to approved groups.',
  'Patient Data Steward'),
 ('m_patient + clinics','dim_patient + dim_clinic',
  'Conform attributes and assign surrogate keys; derive age band without exposing direct identifiers.',
  'Warehouse Custodian'),
 ('visits + billing','fact_visits',
  'Join visit to clinic/patient dimensions; aggregate billing service categories per visit; load one fact row per visit.',
  'Warehouse Custodian'),
 ('fact_visits + dim_clinic + dim_patient','MoH report / dashboard',
  'Aggregate by month, clinic/district, diagnosis and service; release only after clinical and finance validation.',
  'Analytics Lead')
ON DUPLICATE KEY UPDATE transformation=VALUES(transformation),owner=VALUES(owner);

SELECT TABLE_NAME,COLUMN_NAME,DATA_TYPE,COLUMN_COMMENT
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA='medilink'
ORDER BY TABLE_NAME,ORDINAL_POSITION;

SELECT * FROM glossary ORDER BY term;
SELECT * FROM data_lineage ORDER BY lineage_id;

SELECT target_object,transformation
FROM data_lineage
WHERE source_object LIKE '%m_patient%' OR target_object LIKE '%m_patient%';

----------------------------------------------------------------------------------------
-- PHASE 8 — Security, privacy, RBAC, audit and immutable billing
----------------------------------------------------------------------------------------
USE medilink;

CREATE TABLE IF NOT EXISTS data_classification (
  object_name VARCHAR(64) PRIMARY KEY,
  sensitivity ENUM('PUBLIC','INTERNAL','CONFIDENTIAL','RESTRICTED') NOT NULL,
  owner VARCHAR(120) NOT NULL
);

INSERT INTO data_classification VALUES
 ('m_patient','RESTRICTED','Medical Director'),
 ('visits','RESTRICTED','Head of Clinical Services'),
 ('billing','CONFIDENTIAL','Finance Manager'),
 ('v_patient_directory','CONFIDENTIAL','Medical Director'),
 ('master_audit','RESTRICTED','Medical Director'),
 ('fact_visits','CONFIDENTIAL','EDM Lead'),
 ('dim_clinic','INTERNAL','Operations Manager')
ON DUPLICATE KEY UPDATE sensitivity=VALUES(sensitivity),owner=VALUES(owner);

-- SHA-256 only at ingestion. This assumes authorised access to the legacy extract.
-- Do not print, export, or retain plaintext National IDs beyond controlled migration.
-- Safe-update-compatible hashing: the WHERE clause restricts the scan using the
-- primary key (patient_key), which satisfies SQL_SAFE_UPDATES. A predicate that
-- built the key set with IN (subquery) would force a full table scan and be
-- rejected with error 1175. Instead the correlated scalar subquery in SET
-- resolves the hash only for rows that have a LEGACY_A National ID; every other
-- row evaluates to NULL and is left unchanged. Rows that are already hashed are
-- skipped so re-runs are idempotent.
UPDATE m_patient AS m
SET m.national_id_hash = (
    SELECT SHA2(TRIM(a.nid), 256)
    FROM patient_source_links AS l
    JOIN stg_legacy_a AS a
      ON CAST(a.src_id AS CHAR) = l.source_record_id
    WHERE l.patient_key = m.patient_key
      AND l.source_system = 'LEGACY_A'
      AND a.nid IS NOT NULL
      AND TRIM(a.nid) <> ''
    ORDER BY a.src_id
    LIMIT 1
)
WHERE m.patient_key > 0
  AND m.national_id_hash IS NULL;

CREATE OR REPLACE VIEW v_patient_directory AS
SELECT patient_key,
       CONCAT(LEFT(full_name,1),'***') AS name_masked,
       CASE WHEN phone IS NULL THEN NULL ELSE CONCAT('***',RIGHT(phone,3)) END AS phone_masked,
       sex,home_district
FROM m_patient WHERE status='ACTIVE';

CREATE TABLE IF NOT EXISTS master_audit (
  audit_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  patient_key BIGINT NOT NULL,
  changed_by VARCHAR(128) NOT NULL,
  changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  detail VARCHAR(1000) NOT NULL
);

DROP TRIGGER IF EXISTS trg_master_audit_after_update;
DELIMITER //
CREATE TRIGGER trg_master_audit_after_update
AFTER UPDATE ON m_patient
FOR EACH ROW
BEGIN
  INSERT INTO master_audit (patient_key,changed_by,detail)
  VALUES (NEW.patient_key,CURRENT_USER(),
    CONCAT('phone ',COALESCE(OLD.phone,'NULL'),' -> ',COALESCE(NEW.phone,'NULL'),
           '; name ',COALESCE(OLD.full_name,'NULL'),' -> ',COALESCE(NEW.full_name,'NULL'),
           '; email ',COALESCE(OLD.email,'NULL'),' -> ',COALESCE(NEW.email,'NULL')));
END//
DELIMITER ;

DROP TRIGGER IF EXISTS trg_master_audit_after_insert;
DELIMITER //
CREATE TRIGGER trg_master_audit_after_insert
AFTER INSERT ON m_patient
FOR EACH ROW
BEGIN
  INSERT INTO master_audit (patient_key,changed_by,detail)
  VALUES (NEW.patient_key,CURRENT_USER(),
    CONCAT('INSERT name ',COALESCE(NEW.full_name,'NULL'),
           '; phone ',COALESCE(NEW.phone,'NULL'),
           '; source_count ',NEW.source_count));
END//
DELIMITER ;

DROP TRIGGER IF EXISTS trg_master_audit_after_delete;
DELIMITER //
CREATE TRIGGER trg_master_audit_after_delete
AFTER DELETE ON m_patient
FOR EACH ROW
BEGIN
  INSERT INTO master_audit (patient_key,changed_by,detail)
  VALUES (OLD.patient_key,CURRENT_USER(),
    CONCAT('DELETE name ',COALESCE(OLD.full_name,'NULL'),
           '; phone ',COALESCE(OLD.phone,'NULL')));
END//
DELIMITER ;

DROP TRIGGER IF EXISTS trg_billing_no_update;
DELIMITER //
CREATE TRIGGER trg_billing_no_update
BEFORE UPDATE ON billing
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT='Billing rows are immutable; record a correction in billing_adjustments.';
END//
DELIMITER ;

-- Run as a DBA/admin in a controlled environment. Use unique, managed credentials.
CREATE ROLE IF NOT EXISTS 'ml_reception','ml_clinician','ml_analyst','ml_auditor';
GRANT SELECT ON medilink.v_patient_directory TO 'ml_reception';
GRANT SELECT ON medilink.m_patient TO 'ml_clinician';
GRANT INSERT,UPDATE ON medilink.m_patient TO 'ml_clinician';
GRANT SELECT ON medilink.fact_visits TO 'ml_analyst';
GRANT SELECT ON medilink.dim_clinic TO 'ml_analyst';
GRANT SELECT ON medilink.master_audit TO 'ml_auditor';
GRANT SELECT ON medilink.compliance_register TO 'ml_auditor';
GRANT SELECT ON medilink.data_classification TO 'ml_auditor';
GRANT SELECT ON medilink.glossary TO 'ml_auditor';
GRANT SELECT ON medilink.data_lineage TO 'ml_auditor';

-- Provision individual users separately; example syntax only. Never reuse this example password.
-- CREATE USER 'reception_user'@'10.%' IDENTIFIED BY '<use-a-secret-manager-generated-password>';
-- GRANT 'ml_reception' TO 'reception_user'@'10.%';
-- SET DEFAULT ROLE 'ml_reception' TO 'reception_user'@'10.%';

-- Verification queries; test attempted update in a rollback/test database because it should fail.
SELECT * FROM v_patient_directory LIMIT 5;
SELECT * FROM master_audit ORDER BY changed_at DESC LIMIT 20;
SELECT * FROM data_classification;

----------------------------------------------------------------------------------------
-- PHASE 9 — Ministry of Health reporting and analytics
----------------------------------------------------------------------------------------
USE medilink;

-- A. Monthly OPD attendance by district and clinic; detail plus roll-up rows.
SELECT dc.district,dc.clinic_name,DATE_FORMAT(f.visit_date,'%Y-%m') AS report_month,
       COUNT(*) AS visit_count
FROM fact_visits f
JOIN dim_clinic dc ON dc.clinic_sk=f.clinic_sk
WHERE f.visit_type='OPD'
GROUP BY dc.district,dc.clinic_name,report_month WITH ROLLUP;

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
SELECT DATE_FORMAT(v.visit_date,'%Y-%m') AS report_month,b.service,
       SUM(b.amount) AS revenue
FROM visits v
JOIN billing b ON b.visit_id=v.visit_id
WHERE v.visit_date >= @report_start AND v.visit_date < @report_end
GROUP BY report_month,b.service
ORDER BY report_month,b.service;

-- D. Three-month moving average of monthly visit counts.
SELECT report_month,visits,
       ROUND(AVG(visits) OVER (ORDER BY report_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),1)
         AS moving_average_3_month
FROM (
  SELECT DATE_FORMAT(visit_date,'%Y-%m') AS report_month,COUNT(*) AS visits
  FROM fact_visits GROUP BY DATE_FORMAT(visit_date,'%Y-%m')
) monthly
ORDER BY report_month;

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

----------------------------------------------------------------------------------------
-- PHASE 10 — DataOps automation and lifecycle enforcement
----------------------------------------------------------------------------------------
USE medilink;

CREATE TABLE IF NOT EXISTS dq_scorecard_log (
  run_date DATE PRIMARY KEY,
  total_patients BIGINT NOT NULL,
  phone_complete_pct DECIMAL(5,2) NULL,
  dob_complete_pct DECIMAL(5,2) NULL,
  sex_complete_pct DECIMAL(5,2) NULL,
  invalid_phones BIGINT NOT NULL DEFAULT 0,
  potential_dupes BIGINT NOT NULL DEFAULT 0,
  recorded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Auditor read access to the quality log (granted here because the table is created in Phase 10).
GRANT SELECT ON medilink.dq_scorecard_log TO 'ml_auditor';

-- MySQL Event Scheduler must be enabled by an authorised DBA.
-- Check: SHOW VARIABLES LIKE 'event_scheduler';
-- If approved: SET GLOBAL event_scheduler = ON;

DELIMITER //
CREATE EVENT IF NOT EXISTS ev_daily_dq_scorecard
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
DO
  INSERT INTO dq_scorecard_log
    (run_date,total_patients,phone_complete_pct,dob_complete_pct,sex_complete_pct,invalid_phones,potential_dupes)
  SELECT CURDATE(),total_patients,phone_complete_pct,dob_complete_pct,sex_complete_pct,invalid_phones,potential_dupes
  FROM v_dq_scorecard
  ON DUPLICATE KEY UPDATE total_patients=VALUES(total_patients),
    phone_complete_pct=VALUES(phone_complete_pct),dob_complete_pct=VALUES(dob_complete_pct),
    sex_complete_pct=VALUES(sex_complete_pct),invalid_phones=VALUES(invalid_phones),
    potential_dupes=VALUES(potential_dupes),
    recorded_at=CURRENT_TIMESTAMP//
DELIMITER ;

-- Production lifecycle example: archive clinical visits older than seven years,
-- while the governing policy retains clinical records for ten years.
-- Confirm the organisation's approved retention interpretation before enabling this event.
DELIMITER //
CREATE EVENT IF NOT EXISTS ev_archive_old_visits
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
DO
  UPDATE visits
  SET status='ARCHIVED'
  WHERE status='ACTIVE'
    AND visit_date < CURRENT_TIMESTAMP - INTERVAL 7 YEAR
    AND visit_id > 0//
DELIMITER ;

-- Purging is intentionally NOT automated in this starter script. A separate approved,
-- audited purge workflow must verify retention expiry, legal holds, backups and authorisation.
SELECT * FROM dq_scorecard_log ORDER BY run_date DESC LIMIT 30;
SHOW EVENTS FROM medilink;