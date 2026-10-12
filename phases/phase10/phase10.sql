-- PHASE 10 — DataOps automation and lifecycle enforcement
-- Logs daily quality metrics and provides a scheduled archival event; purge remains separately approved and audited.
--
-- Source: MediLink strategy, Appendix B — Phase-by-phase MySQL 8.0
-- SQL implementation scripts. Run phases sequentially in one schema.

Logs daily quality metrics and provides a scheduled archival event; purge remains separately approved and audited.
USE medilink;
 
CREATE TABLE IF NOT EXISTS dq_scorecard_log (
  run_date DATE PRIMARY KEY,
  total_patients BIGINT NOT NULL,
  phone_complete_pct DECIMAL(5,2) NULL,
  dob_complete_pct DECIMAL(5,2) NULL,
  sex_complete_pct DECIMAL(5,2) NULL,
  invalid_phones BIGINT NOT NULL DEFAULT 0,
  recorded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
 
-- MySQL Event Scheduler must be enabled by an authorised DBA.
-- Check: SHOW VARIABLES LIKE 'event_scheduler';
-- If approved: SET GLOBAL event_scheduler = ON;
 
DELIMITER //
CREATE EVENT IF NOT EXISTS ev_daily_dq_scorecard
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
DO
  INSERT INTO dq_scorecard_log
    (run_date,total_patients,phone_complete_pct,dob_complete_pct,sex_complete_pct,invalid_phones)
  SELECT CURDATE(),total_patients,phone_complete_pct,dob_complete_pct,sex_complete_pct,invalid_phones
  FROM v_dq_scorecard
  ON DUPLICATE KEY UPDATE total_patients=VALUES(total_patients),
    phone_complete_pct=VALUES(phone_complete_pct),dob_complete_pct=VALUES(dob_complete_pct),
    sex_complete_pct=VALUES(sex_complete_pct),invalid_phones=VALUES(invalid_phones),
    recorded_at=CURRENT_TIMESTAMP;
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
    AND visit_date < CURRENT_TIMESTAMP - INTERVAL 7 YEAR;
DELIMITER ;
 
-- Purging is intentionally NOT automated in this starter script. A separate approved,
-- audited purge workflow must verify retention expiry, legal holds, backups and authorisation.
SELECT * FROM dq_scorecard_log ORDER BY run_date DESC LIMIT 30;
SHOW EVENTS FROM medilink;

-- Required evidence: 10 | SHOW EVENTS; dq_scorecard_log; archived-record sample | Scheduler enabled, events defined and logs populated | To be completed after execution
