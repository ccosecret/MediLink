-- PHASE 2 — Governance framework registers
-- Implements ownership, RACI, policy and compliance-gap registers.
--
-- Source: MediLink strategy, Appendix B — Phase-by-phase MySQL 8.0
-- SQL implementation scripts. Run phases sequentially in one schema.

Implements ownership, RACI, policy and compliance-gap registers.
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
 ('Access Control Policy','Least privilege; reception uses masked directory; analysts access de-identified warehouse only.','TECHNICAL','IT Security Owner'),
 ('Retention Policy','Use approved lifecycle schedule; archive then authorised purge after retention expiry.','BOTH','Data Governance Lead')
ON DUPLICATE KEY UPDATE rule_summary=VALUES(rule_summary),
  enforcement=VALUES(enforcement), policy_owner=VALUES(policy_owner);
 
CREATE TABLE IF NOT EXISTS compliance_register (
  req_id INT AUTO_INCREMENT PRIMARY KEY,
  requirement VARCHAR(200) NOT NULL,
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
 ('Incident response and notification','Formal process not yet evidenced','OPEN',
  'Approve breach playbook and validate applicable notification duties',NULL)
ON DUPLICATE KEY UPDATE current_state=VALUES(current_state),
  gap_status=VALUES(gap_status), remediation=VALUES(remediation);
 
SELECT * FROM data_ownership;
SELECT * FROM raci;
SELECT * FROM policies;
SELECT * FROM compliance_register;

-- Required evidence: 2 | SELECT ownership, RACI, policies, compliance_register | Governance registers are populated; gaps are not falsely marked closed | To be completed after execution
