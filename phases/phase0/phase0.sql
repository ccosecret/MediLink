-- PHASE 0 — Environment setup and source inventory
-- Creates the project database and registers source systems before they are trusted.
--
-- Source: MediLink strategy, Appendix B — Phase-by-phase MySQL 8.0
-- SQL implementation scripts. Run phases sequentially in one schema.

Creates the project database and registers source systems before they are trusted.
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

-- Required evidence: 0 | CREATE DATABASE / source_inventory query | Database exists; sources have owner/format/quality metadata | To be completed after execution
