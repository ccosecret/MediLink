-- PHASE 8 — Security, privacy, RBAC, audit and immutable billing
-- Implements masked directory, hash-at-ingestion pattern, audit trigger, immutable billing trigger and role grants.
--
-- Source: MediLink strategy, Appendix B — Phase-by-phase MySQL 8.0
-- SQL implementation scripts. Run phases sequentially in one schema.

Implements masked directory, hash-at-ingestion pattern, audit trigger, immutable billing trigger and role grants.
USE medilink;
 
CREATE TABLE IF NOT EXISTS data_classification (
  object_name VARCHAR(64) PRIMARY KEY,
  sensitivity ENUM('PUBLIC','INTERNAL','CONFIDENTIAL','RESTRICTED') NOT NULL,
  owner VARCHAR(120) NOT NULL
);
 
INSERT INTO data_classification VALUES
 ('m_patient','RESTRICTED','Medical Director'),
 ('visits','RESTRICTED','Head of Clinical Services'),
 ('fact_visits','CONFIDENTIAL','EDM Lead'),
 ('dim_clinic','INTERNAL','Operations Manager')
ON DUPLICATE KEY UPDATE sensitivity=VALUES(sensitivity),owner=VALUES(owner);
 
-- SHA-256 only at ingestion. This assumes authorised access to the legacy extract.
-- Do not print, export, or retain plaintext National IDs beyond controlled migration.
UPDATE m_patient m
JOIN patient_source_links l ON l.patient_key=m.patient_key AND l.source_system='LEGACY_A'
JOIN stg_legacy_a a ON CAST(a.src_id AS CHAR)=l.source_record_id
SET m.national_id_hash=SHA2(TRIM(a.nid),256)
WHERE a.nid IS NOT NULL AND TRIM(a.nid)<>''
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
 
-- Provision individual users separately; example syntax only. Never reuse this example password.
-- CREATE USER 'reception_user'@'10.%' IDENTIFIED BY '<use-a-secret-manager-generated-password>';
-- GRANT 'ml_reception' TO 'reception_user'@'10.%';
-- SET DEFAULT ROLE 'ml_reception' TO 'reception_user'@'10.%';
 
-- Verification queries; test attempted update in a rollback/test database because it should fail.
SELECT * FROM v_patient_directory LIMIT 5;
SELECT * FROM master_audit ORDER BY changed_at DESC LIMIT 20;
SELECT * FROM data_classification;

-- Required evidence: 8 | Masked-view output, audit row, blocked billing update in test DB, SHOW GRANTS | Access is least-privilege; billing update is blocked; audit works | To be completed after execution
