# Phase scripts (MySQL 8.0+)

Each phase is a self-contained, executable script. Run them in order.

Execution order: Phase 0 → Phase 1 → … → Phase 10.

> These scripts have **not** been executed against a MySQL instance. Capture
> actual MySQL Workbench outputs and replace the placeholder evidence fields
> before submission. Test destructive or privilege-sensitive operations only
> in a controlled development database.

APPENDIX B — PHASE-BY-PHASE MYSQL 8.0 SQL IMPLEMENTATION SCRIPTS
Purpose. This appendix supplies executable starter SQL aligned to the ten project phases. Run the phases sequentially in a development database, inspect the outputs, and retain screenshots/logs as evidence. The scripts use the project’s stated MySQL 8.0+ platform and are included here because the phase SQL is a required part of the build.
Important execution and evidence note. These scripts have not been executed against the student's MySQL instance. Therefore, this document does not assert that tables, controls, events, metrics, or dashboards have been successfully deployed. Capture actual Workbench results and replace illustrative/empty evidence fields in the main report. Test destructive or privilege-sensitive operations only in a controlled development database.
Execution order: Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 → Phase 7 → Phase 8 → Phase 9 → Phase 10.
Compatibility note. The SQL below is written for MySQL 8.0+. Some administrative statements (roles, triggers, events and global Event Scheduler configuration) require DBA privileges. The project’s original examples contain a few malformed aggregate expressions and omitted identifiers; the scripts below use explicit MySQL syntax while preserving the stated business rules. Review local law and organisational policy before operational use, especially retention, lawful basis, breach notification, and handling of National ID values.
PHASE 0 — Environment setup and source inventory

## Appendix B.1 — Required execution evidence register

Appendix B.1 — Required execution evidence register
Phase	Evidence to capture from MySQL Workbench	Expected proof	Actual result / screenshot reference
0	CREATE DATABASE / source_inventory query	Database exists; sources have owner/format/quality metadata	To be completed after execution
1	SELECT from data_lifecycle_policy	Lifecycle schedule is stored and internally consistent	To be completed after execution
2	SELECT ownership, RACI, policies, compliance_register	Governance registers are populated; gaps are not falsely marked closed	To be completed after execution
3	SHOW TABLES; SHOW CREATE TABLE m_patient	Core schema and phone constraint exist	To be completed after execution
4	Before/after profiling and v_dq_scorecard	Measured completeness/invalid values, with counts and denominator	To be completed after execution
5	Golden-record/crosswalk query and unresolved review queue	One approved master for safe matches; conflicts remain in queue	To be completed after execution
6	Row counts and sample fact rows	Warehouse rows reconcile to source visits and billing totals	To be completed after execution
7	information_schema.COLUMNS, glossary, lineage	A new analyst can find a field definition and its lineage	To be completed after execution
8	Masked-view output, audit row, blocked billing update in test DB, SHOW GRANTS	Access is least-privilege; billing update is blocked; audit works	To be completed after execution
9	Three MoH report result sets and dashboard screenshots	Attendance, top-10 diagnoses and revenue by service are reproducible	To be completed after execution
10	SHOW EVENTS; dq_scorecard_log; archived-record sample	Scheduler enabled, events defined and logs populated	To be completed after execution
Appendix B.2 — Technical limitations and safe-use controls
    • The SQL is a reproducible starter implementation, not proof of execution. Save actual query outputs, error messages and screenshots from your MySQL Workbench environment.
    • The supplied source records are fictional test data. Do not copy production patient data into a classroom/demo environment.
    • Phone is a candidate match key, not sufficient evidence to auto-merge conflicting identity fields. The script queues differing name, sex or date-of-birth groups for a steward.
    • The SHA-256 pattern is a one-way hash, not encryption; hashes can remain personal data and National ID processing requires a lawful, approved purpose. Plaintext staging should be access-restricted and securely removed after verified migration.
    • The main project specifies ten-year clinical retention. The automation example archives after seven years as an archival milestone, not a deletion rule. Purging is intentionally excluded until an authorised, legally validated purge workflow exists.
    • The analyst role is granted access to the fact table and clinic dimension, but this alone does not guarantee de-identification if other fact fields can identify people. Verify the warehouse contains only approved, minimised attributes before granting analyst access.
    • The Phase 6 ETL uses a fact table with one row per visit. Reconcile total_amount against source billing, and decide how billing adjustment rows should affect the official revenue definition before production reporting.
    • The SQL assumes sequential execution in one medilink schema. Re-running DDL with existing triggers/events may require controlled drop/recreate handling; do not casually drop production objects.
