-- PHASE 7 — Metadata, glossary and lineage
-- Documents schema comments, business terms and source-to-target transformations.
--
-- Source: MediLink strategy, Appendix B — Phase-by-phase MySQL 8.0
-- SQL implementation scripts. Run phases sequentially in one schema.

Documents schema comments, business terms and source-to-target transformations.
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
 ('Revenue','Sum of billing amounts, including approved adjustment handling in the reporting definition.','Finance Manager','CONFIDENTIAL')
ON DUPLICATE KEY UPDATE definition=VALUES(definition),owner=VALUES(owner),sensitivity=VALUES(sensitivity);
 
CREATE TABLE IF NOT EXISTS data_lineage (
  lineage_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  source_object VARCHAR(150) NOT NULL,
  target_object VARCHAR(150) NOT NULL,
  transformation VARCHAR(600) NOT NULL,
  owner VARCHAR(120) NOT NULL,
  last_reviewed DATE NULL
);
 
INSERT INTO data_lineage (source_object,target_object,transformation,owner) VALUES
 ('stg_legacy_a + stg_legacy_b','m_patient',
  'Normalize phones; phone groups are candidates; identity conflicts go to steward queue; survivorship applied only to approved groups.',
  'Patient Data Steward'),
 ('visits + billing','fact_visits',
  'Join visit to clinic/patient dimensions; aggregate billing service categories per visit; load one fact row per visit.',
  'Warehouse Custodian')
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

-- Required evidence: 7 | information_schema.COLUMNS, glossary, lineage | A new analyst can find a field definition and its lineage | To be completed after execution
