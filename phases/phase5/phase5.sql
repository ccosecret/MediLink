-- PHASE 5 — Master Data Management, survivorship and review queue
-- Creates candidate golden records for unambiguous phone groups and sends identity conflicts to steward review rather than silently merging them.
--
-- Source: MediLink strategy, Appendix B — Phase-by-phase MySQL 8.0
-- SQL implementation scripts. Run phases sequentially in one schema.

Creates candidate golden records for unambiguous phone groups and sends identity conflicts to steward review rather than silently merging them.
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
      WHEN 'F' THEN 'F' WHEN 'FEMALE' THEN 'F' ELSE NULL END;
 
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

-- Required evidence: 5 | Golden-record/crosswalk query and unresolved review queue | One approved master for safe matches; conflicts remain in queue | To be completed after execution
