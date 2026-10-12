-- PHASE 3 — Core master schema and operational model
-- Creates clinic, staff, patient master, crosswalk, visit, billing and adjustment structures.
--
-- Source: MediLink strategy, Appendix B — Phase-by-phase MySQL 8.0
-- SQL implementation scripts. Run phases sequentially in one schema.

Creates clinic, staff, patient master, crosswalk, visit, billing and adjustment structures.
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

-- Required evidence: 3 | SHOW TABLES; SHOW CREATE TABLE m_patient | Core schema and phone constraint exist | To be completed after execution
