-- PHASE 1 — Data lifecycle policy
-- Stores approved data-class retention and archival decisions; legal basis wording must be validated locally.
--
-- Source: MediLink strategy, Appendix B — Phase-by-phase MySQL 8.0
-- SQL implementation scripts. Run phases sequentially in one schema.

Stores approved data-class retention and archival decisions; legal basis wording must be validated locally.
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

-- Required evidence: 1 | SELECT from data_lifecycle_policy | Lifecycle schedule is stored and internally consistent | To be completed after execution
