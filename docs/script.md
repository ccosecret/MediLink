MEDILINK HEALTH NETWORK
Integrated Enterprise Data
Management Strategy



Group name: __________________________________________
Course: ____________________________________
 Lecturer: _________________________________________
Course Code: __________________________________________




Document purpose and evidence status
This strategy translates the MediLink Health Network capstone brief into an end-to-end EDM operating model. It follows the course notes’ treatment of EDM as a coordinated combination of people, policies, processes and technology across the data lifecycle, and uses the taught database, data warehouse, ETL, KDD/CRISP-DM, security and privacy concepts.
Important evidence boundary: the two reference PDFs define the scenario, business rules, seed data, SQL exercises and required deliverables. They do not include this student team’s actual MySQL Workbench execution results, screenshots, production volumes, dashboard exports or individual contribution records. Accordingly, this document distinguishes specified requirements and proposed controls from results that must be measured and evidenced. Do not submit planned targets as achieved results.
Contents
    • 1. Executive summary
    • 2. Governance charter, RACI, policies and compliance register
    • 3. Architecture and database design
    • 4. Data quality assessment and monitoring
    • 5. Master data management and steward review
    • 6. Metadata catalogue and lineage
    • 7. Security, privacy, DPIA and incident response
    • 8. Analytics and Ministry of Health reporting pipeline
    • 9. Roadmap: deployment, data mesh and AI candidates
    • 10. Individual reflection and contribution log
    • Appendix A. Workbench evidence checklist
    • Appendix B. References

1. Executive summary
1.1 Business problem
MediLink is a Ugandan network formed by combining four previously independent clinics in Kampala, Mukono, Mbarara and Gulu. The clinics have separate patient-registration systems and one branch still relies on paper. The project brief describes duplicate records for Sarah Nakato, inconsistent spellings and phone numbers, a spreadsheet containing HIV-status information sent to an unintended recipient, a manual Ministry of Health (MoH) report that takes three staff members two weeks, and unclear ownership, data trust and deletion rules.
1.2 Proposed platform and value
The proposed solution is a MySQL 8.0+ hub-and-spoke enterprise data platform implemented and tested in MySQL Workbench. Clinic and paper-derived records enter a controlled staging area; profiling and cleansing standardize data; Master Data Management (MDM) assigns each patient one golden record and preserves source crosswalks; ETL loads a dimensional warehouse; and BI queries support monthly MoH reporting and management analysis.
    • Reliable patient identity: one master record per real patient, with ambiguous identity conflicts sent to a data steward rather than silently merged.
    • Measured quality: weekly scorecards monitor phone completeness, invalid phone values, missing demographics and potential duplicates.
    • Governance and accountability: named owners, stewards and custodians; documented RACI; policy register; and a compliance gap register.
    • Privacy and security: National ID stored only as a SHA-256 hash in the master, least-privilege roles, masked reception directory, de-identified analyst access, audit logging and controlled retention.
    • Timely reporting: a repeatable ETL pipeline supports clinic/district attendance, top diagnoses and revenue-by-service reporting with a target delivery date of the 5th of each month.
    • Operational sustainability: metadata and lineage, event-driven quality logging, lifecycle automation, backups, and a controlled roadmap.
1.3 Scope and success criteria
Outcome	Project requirement / acceptance criterion	Evidence required
Patient master	One golden record per patient; phone normalized as 256XXXXXXXXX; identity conflicts reviewed	Query showing Sarah’s three source rows linked to one patient_key; crosswalk extract; review-queue evidence
Data quality	At least 97% phone completeness and zero invalid normalized phones, measured weekly	Before/after scorecard results with denominator, timestamp and screenshot/export
Billing integrity	Billing rows immutable; corrections use adjustment rows	Attempted UPDATE rejected by trigger; adjustment-row test
Access	Reception masked directory; clinicians full record; analysts de-identified warehouse only	SHOW GRANTS and role-based query tests
Reporting	MoH monthly attendance, top-10 diagnoses, revenue by service delivered by day 5	SQL result exports, dashboard screenshots, reconciliation totals
Automation	Daily quality log and lifecycle process enabled and monitored	SHOW EVENTS, event execution log, test output

These are acceptance criteria, not claims that the implementation has already passed them.
2. Governance charter, RACI, policies and compliance register
2.1 Governance charter
Purpose: establish clear authority, accountability and repeatable rules for MediLink’s collection, storage, integration, use, sharing, retention and disposal of data. Governance is an operating responsibility shared by business owners, data stewards and technical custodians, not a task owned by IT alone.
Charter element	Decision
Scope	Patient identity and demographics, clinic/staff reference data, visits/diagnoses, billing, reporting extracts, source metadata and paper-digitization records.
Principles	Purpose limitation; minimum necessary access; accuracy; traceability; accountable ownership; privacy by design; controlled retention; auditable changes.
Decision rights	Data owners approve definitions and access purposes; stewards resolve quality and identity exceptions; custodians implement controls; clinicians validate clinical meaning.
Cadence	Weekly data-quality review; monthly MoH reporting sign-off; quarterly access and compliance review; incident reviews after any privacy/security event.
Change control	New sources, fields, transformations and retention rules require owner approval, catalogue registration, impact analysis, test evidence and version-controlled SQL.

2.2 Roles and accountability
Role	Accountability	Example responsibilities
Executive sponsor / CDO-equivalent	Accountable for EDM outcomes and cross-clinic priorities	Approve policy, resolve cross-domain disputes, sponsor remediation.
Data owner	Accountable for meaning, permitted use and quality of a data domain	Medical Director for patient/clinical data; Finance Manager for billing.
Data steward	Operationally responsible for definitions and data quality	Review duplicate candidates, approve identity conflicts, maintain glossary and exception queue.
Data custodian / DBA	Responsible for technical storage and controls	Schema, access grants, backup/recovery, event scheduler, audit logging, deployment.
Clinician / clinical lead	Consulted on clinical accuracy and safe interpretation	Validate diagnosis codes, clinical identity corrections and clinical reports.
Analyst / BI developer	Uses authorized de-identified data for analysis	Build queries, validate metrics, document assumptions and avoid re-identification.
Privacy / compliance lead	Advises on lawful processing, DPIA and incidents	Review notices, retention, data-subject requests and breach response.

2.3 RACI matrix
R = Responsible; A = Accountable; C = Consulted; I = Informed. The matrix below adapts the project handout’s example roles and should be ratified by the team.
Activity	Sponsor/CDO	Steward	Custodian/DBA	Clinician/Owner	Analyst
Approve new source system	A	R	C	C	I
Register source metadata	I	A/R	R	C	I
Resolve patient duplicate	I	A/R	C	C	I
Approve access request	A	C	R	C	I
Apply database role/grant	I	C	A/R	I	I
Approve clinical definition	I	R	I	A	C
Run ETL and reconcile counts	I	C	A/R	C	R
Approve MoH report release	I	C	R	A	R
Handle privacy incident	A	C	R	C	I
Approve retention/disposal	A	C	R	C	I

2.4 Policy register
Policy	Core rule	Technical / operational enforcement	Owner
Patient Identity and MDM	Exactly one master per patient; normalized phone is primary match key; conflicting name/DOB/sex must not auto-merge.	Unique source crosswalk; phone validation; MDM review queue; audit table; steward sign-off.	Medical Director
Data Quality	Phone completeness ≥97%; zero invalid normalized phones; weekly monitoring and logged exceptions.	CHECK/validation rules, staging cleansing, v_dq_scorecard, dq_scorecard_log, steward exception workflow.	Data Steward
Access Control and Privacy	Least privilege; reception sees masked directory; clinicians see full record for care; analysts see de-identified warehouse only.	MySQL roles and GRANTs; masked view; separate warehouse access; periodic access review.	Privacy lead + DBA
Retention and Disposal	Clinical records retained for 10 years then archived and purged according to approved policy and applicable obligations.	data_lifecycle_policy, status/archive process, scheduled events, purge approval and audit log.	Clinical data owner
Billing Integrity	Billing rows are immutable; correction is a new adjustment row, never an UPDATE of the original.	BEFORE UPDATE trigger; adjustment ledger; audit/reconciliation.	Finance Manager
Metadata and Source Trust	Every source must register owner, definitions and lineage before trusted use.	Glossary, data_lineage, INFORMATION_SCHEMA export and source approval checklist.	Data Steward

2.5 Compliance register — before/after evidence
The project brief identifies the Uganda Data Protection and Privacy Act as the relevant local context and suggests a Uganda DPA / GDPR mapping. The course notes also discuss privacy, confidentiality and ethical handling, but include references to a different jurisdiction’s Data Privacy Act. For this Ugandan project, the legal register must be validated against current Ugandan law by the responsible privacy/legal adviser; GDPR should be treated as a mapping reference only where applicable, not assumed to apply automatically.
Control / risk	Before (scenario / initial state)	Required after-state	Evidence to attach	Status rule
National ID	Plaintext appears in Legacy A staging extract.	SHA-256 hash only in master; restrict raw staging; remove plaintext after controlled migration where retention/legal rules permit.	Schema showing nid_sha; query confirming no plaintext in master; migration log.	Do not mark closed until verified.
Sensitive spreadsheet disclosure	Patient HIV status was emailed to wrong recipient; no response procedure specified.	Minimum-necessary exports, approved recipients, encrypted transfer, access logs and documented incident response.	Export-control policy, RBAC test, incident playbook and tabletop record.	Open until controls tested.
Access segregation	No reliable role-specific access in scenario.	Reception masked view; clinician access; analyst de-identified warehouse only; auditor read-only audit access.	SHOW GRANTS and screenshots of each role’s view/query.	Close only after tests.
Retention	Unclear what may be deleted.	Approved lifecycle rules, archive/purge approvals, logs and restore testing.	Lifecycle register, SHOW EVENTS, archive/purge test in non-production.	Close only after safe end-to-end test.
Master-data changes	Ownership and trust are unclear.	Every master change auditable with actor, timestamp and changed fields.	Trigger test and master_audit rows.	Close only after verified.
Source trust	Owners, definitions and lineage not registered consistently.	Metadata registration is a gate before onboarding source data.	Catalog extract and source approval checklist.	Close only after all active sources are catalogued.

Evidence rule: retain a dated screenshot or exported query result for each before/after claim. The scenario’s initial-state descriptions come from the project brief; the after-state is a target until actual Workbench output demonstrates it.
3. Architecture and database design
The project specifies a hub-and-spoke design: the clinic systems and paper digitization are spokes, while a central master database is the hub. This is suitable because it gives MediLink a shared patient identity and consistent governance while allowing clinic source systems to remain operationally distinct. The course notes describe hub-and-spoke warehousing as scalable and maintainable, with customization for user instances and reports.

3.1 Data flow and controls
Layer	Main objects / examples	Purpose and control
Source systems	Legacy A, Legacy B, pharmacy/POS, paper scans; clinics and staff	Preserve source identifiers and capture provenance. Register owner, format, volume, definitions and known quality issues.
Staging	stg_legacy_a, stg_legacy_b; import batches	Retain raw source values for traceability; add cleaned columns; quarantine invalid rows; record batch ID and load time.
Master / MDM	m_patient, patient_source_links, mdm_review_queue	One golden patient record; source crosswalk; survivorship; unresolved conflicts routed to steward.
Operational model	clinics, staff, visits, billing	Normalized relational model; each visit references one patient, clinic and staff member; immutable billing.
Warehouse	dim_clinic, dim_patient, dim_date, fact_visits	Star schema for analytical workloads; avoid exposing direct identifiers to analysts; reconcile facts to operational totals.
BI and reporting	MoH monthly report, dashboard, KPI extracts	Aggregate attendance, diagnosis and service revenue; release after clinical/finance validation.

3.2 Relational and dimensional design
Operational data should be normalized to reduce redundancy and update anomalies, consistent with the course notes’ treatment of normalization and ER modeling. The patient master is keyed by patient_key; visits reference patient, clinic and staff; billing references visit. The warehouse uses a dimensional/star-schema approach: dimensions provide descriptive context and the fact table records visit-level measures for aggregation.
    • Operational constraints: primary/foreign keys, required columns, controlled ENUM domains where appropriate, and phone-format validation.
    • Warehouse grain: one fact_visits row per visit, with amounts aggregated from billing by service. The grain must be documented and validated to prevent double-counting.
    • Billing corrections: preserve the original transaction and record a separate adjustment linked to the original bill; do not overwrite financial history.
    • Paper records: digitize with source ID, operator, capture date and verification status; ambiguous records remain quarantined until reviewed.
3.3 Design decisions and trade-offs
Decision	Rationale	Risk / mitigation
Hub-and-spoke	Central master and warehouse make cross-clinic integration and standardized reporting feasible.	Central hub becomes critical; mitigate with backups, monitoring, restore tests and documented recovery objectives.
Separate staging	Raw data can be profiled and corrected without changing source systems.	Staging may contain sensitive raw identifiers; restrict access and set controlled deletion/archival rules.
Separate warehouse	Analytics avoids heavy reporting queries against live clinical operations.	ETL latency can cause stale reports; record last successful load and reconcile completeness.
Phone as primary candidate match key	Required by project brief and convenient across source records.	Phones can be shared, recycled, mistyped or missing; do not use phone alone to silently resolve conflicting identity attributes.
SHA-256 National ID hash	Required by project brief to avoid storing plain National ID in master.	Hashing is not anonymization; access to source data and linkage risk remain. Protect salt/keys if introduced and restrict raw source handling.

4. Data quality assessment and monitoring
The project’s supplied seed records are intentionally dirty. Legacy A has six rows with inconsistent name casing, phone formats, sex values and date formats; one record has phone value '0' and several demographic values are blank. Legacy B contains three booking records with normalized and unnormalized phones, emails and different update dates. These are sample inputs, not a real production baseline.
4.1 Quality dimensions
Dimension	Metric	Target / rule	Action when failing
Completeness	Valid non-null phone count ÷ master patient count × 100	≥97%	Queue missing phone for verification; never invent a number.
Validity	Count of phones not matching ^256[0-9]{9}$	0 invalid normalized phones	Reject/quarantine invalid values; correct only when source evidence supports it.
Consistency	Distinct sex/gender values after standardization	Only M or F for the supplied schema	Map recognized aliases; leave unknown values null and flag.
Accuracy	Sample-based verification against source evidence	Target to be set by owner; report measured sample size	Steward validates against source records; avoid treating format validity as factual accuracy.
Uniqueness	Potential duplicate candidate count after normalization	No unresolved duplicate candidates without owner/queue status	Match on normalized phone, then review conflicts.
Timeliness	Age of last successful ETL / report refresh	MoH report by day 5 each month	Alert owner, rerun failed job and record reason.
Integrity	Visits with valid patient/clinic/staff references; billing-to-visit reconciliation	100% referential integrity; totals reconcile	Stop/report failed batch and investigate.

4.2 Baseline and after-scorecard
The instructor’s example 'phone 71% → 100%' is an illustration of how to present improvement; it is not evidence that MediLink’s seed data has achieved those numbers. Calculate the actual baseline from the records loaded into Workbench and use the same denominator and rules for the after-measurement.
Metric	Baseline result	After-cleansing result	Target	Evidence / interpretation
Phone completeness	[Run SQL; enter %]	[Run SQL; enter %]	≥97%	Include row count and query timestamp.
Invalid normalized phones	[Count]	[Count]	0	Invalid phone means not exactly 12 digits beginning 256.
DOB completeness	[Run SQL; enter %]	[Run SQL; enter %]	Monitor; owner to approve target	Missing DOB should remain unknown, not inferred.
Sex completeness / consistency	[Run SQL; enter % and distinct values]	[Run SQL; enter % and distinct values]	Valid domain only	Map M/Male and F/Female; unrecognized values go to review.
Potential duplicates	[Count]	[Count and steward status]	No unresolved duplicate without disposition	Use source crosswalk and review queue.

4.3 Profiling and cleansing method
    1. Profile raw data first: row counts, null/blank percentages, distinct domains, invalid phone patterns, malformed dates and duplicate candidates.
    2. Preserve raw fields; write normalized values to clean columns so corrections remain traceable.
    3. Normalize Ugandan phone values by removing punctuation, recognizing local 10-digit formats beginning with 0, and converting to 256 plus the final nine national digits. Invalid values such as '0' become NULL and enter a review queue.
    4. Standardize sex values only when the source value is recognized. Do not guess unknown values.
    5. Parse dates using explicitly recognized formats; ambiguous dates are reviewed rather than silently converted.
    6. Apply master-table constraints and run a weekly scorecard; assign each failed metric to an owner and log remediation.
4.4 Root cause and monitoring
Likely root causes to investigate include separate legacy schemas, manual data entry, absence of validation at capture, inconsistent training, free-text fields and migration without shared reference standards. Confirm these causes through interviews or source-system inspection; do not state them as proven facts from the seed alone. The steward reviews exceptions weekly, the DBA maintains the scorecard/event, and the data owner approves remediation and target changes.
5. Master data management: matching, survivorship and review
The project brief requires every real patient to have exactly one master record, with phone normalized to 256XXXXXXXXX as the primary matching key. The MDM design is a consolidation style: source records are cleaned, matched, merged under controlled rules and linked back to the golden record through patient_source_links.
5.1 Matching and survivorship rules
Field / issue	Rule	Why / safeguard
Phone	Normalize to 256XXXXXXXXX; use as primary candidate match key.	Cross-system comparison becomes consistent; missing/invalid phone cannot be used as a match.
Source identity	Keep source_system + source_record_id unique in patient_source_links.	Preserves traceability and prevents one source row linking to multiple master records.
Phone / email	Most recently updated trustworthy source wins, as required by brief.	Contact details change over time; record source and update timestamp.
Name / DOB / sex	Never auto-merge conflicting identity values; send conflict to steward queue.	A wrong merge can combine different patients and create clinical harm.
National ID	Store SHA-256 hash only in master; never plain text.	Meets project rule; hashing still requires privacy controls.
No usable phone	Do not guess or force-match; send to mdm_review_queue.	Avoid false-positive merges.
Match confidence	Treat phone match as candidate match; high-impact or conflicting records need steward review.	Phone may be shared, recycled or mistyped.

5.2 Sarah Nakato example
The supplied example identifies Legacy A rows 1 and 2 and Legacy B row 101 as Sarah Nakato’s three source records. The intended demonstration is that all three source identifiers link to one patient_key after normalization, with source_count = 3. The handout expects a single golden record. Before presenting the result, verify it by querying m_patient joined to patient_source_links; do not rely on a comment in a SQL script as proof.
Attribute	Proposed survivorship treatment	Required verification
Phone	Normalized shared phone 256772100001 if source records agree	All three source rows normalize to same value.
Email	Use latest trusted non-null email; supplied Legacy B email is s.nakato@gmail.com	Email lineage and updated_at shown.
Name	Prefer verified canonical display name; conflicting identity spellings should be reviewed	Steward decision recorded; no silent overwrite.
DOB	Source values both indicate 1990-05-12 in the supplied sample	Confirm date parsing and source agreement.
Sex	F in supplied rows	Confirm consistency; store M/F domain.
National ID	Hash only after controlled extraction; no plaintext in master	Query schema and access controls.

5.3 Steward review workflow
    7. Detect: staging validation or MDM matching identifies missing phone, shared phone, conflicting DOB/sex/name or uncertain match.
    8. Queue: create a row in mdm_review_queue with source system, source ID, reason, timestamp and status.
    9. Investigate: steward compares approved source records and documents the decision; clinician is consulted for clinical identity conflicts.
    10. Decide: merge, keep separate, correct source mapping, or request more evidence. Never merge solely because names look similar.
    11. Apply: update the master and source crosswalk through controlled transaction; preserve before/after values in audit log.
    12. Verify: rerun uniqueness and quality checks; confirm source_count and crosswalk links; close queue item with reviewer and resolution timestamp.
A production-grade queue should include status, priority, evidence reference, resolution, and reviewer. The supplied handout’s minimal queue can be extended to support these fields without changing the required business rules.
6. Metadata catalogue and lineage
The course notes describe metadata management as a data dictionary that defines structure and meaning and supports discovery and knowledge sharing. The project makes metadata registration a trust gate: every source system must register its owner, definitions and lineage before it is trusted.
6.1 Catalogue minimum fields
Metadata category	Required fields	Example
Technical	schema, table, column, data type, nullability, key, constraint, comment	visits.diagnosis_code VARCHAR(10); code set/definition documented.
Business	business term, definition, owner, permitted use, sensitivity	OPD Attendance = count of visits where visit_type='OPD' in a defined period.
Operational	source system, source record key, load frequency, last successful load, row counts	Legacy B → staging → MDM, batch timestamp and rejected-row count.
Lineage	source object, target object, transformation, responsible owner, version	stg_legacy_a + stg_legacy_b → m_patient: phone normalization and controlled survivorship.
Governance	classification, retention class, access roles, approval status	m_patient = RESTRICTED; access limited to authorized clinical role.

6.2 Initial glossary extract
Term	Definition	Owner
Golden Record	Single trusted patient representation produced through MDM and survivorship.	Medical Director / Data Steward
OPD Attendance	Count of visit records with visit_type='OPD' in a specified period and approved scope.	Head of Clinical Services
Revenue	Sum of approved billing amounts attributed to services for the reporting period, excluding cancelled transactions where such status is modeled.	Finance Manager
Source Crosswalk	Mapping between a source system record ID and the patient master key.	Data Steward
Staging	Temporary integration layer used to profile, clean and standardize source extracts before controlled loading.	DBA / Data Engineer
Fact Grain	The business event represented by one row in a fact table; for fact_visits, one row per visit.	Analytics Lead
Data Lineage	Documented path from original source through transformations to downstream report or data asset.	Data Steward / DBA

6.3 Lineage extract
Source	Target	Transformation	Validation
Legacy A + Legacy B	stg_legacy_a / stg_legacy_b	Extract raw fields; preserve source IDs and batch details.	Source and staging row counts reconcile.
Staging records	m_patient	Normalize phone/name; standardize recognized sex values; parse valid dates; apply matching and survivorship.	Invalid values quarantined; identity conflicts queued.
m_patient + clinics	dim_patient / dim_clinic	Conform attributes and surrogate keys; derive age band without exposing direct identifiers unnecessarily.	Dimension row counts and keys checked.
visits + billing + dimensions	fact_visits	Join keys; aggregate billing by service; load one row per visit.	No duplicate fact grain; revenue totals reconcile.
Warehouse facts/dimensions	MoH report/dashboard	Aggregate by month, clinic/district, diagnosis and service.	Report filters, date range and totals signed off.

Workbench evidence: export INFORMATION_SCHEMA.COLUMNS with column comments; query glossary and data_lineage; demonstrate impact analysis for a change to m_patient or diagnosis_code; retain screenshots/CSV extracts with dates.
7. Security and privacy: RBAC, masking, DPIA and breach playbook
7.1 Classification and role-based access control
Data asset	Classification	Reception	Clinician	Analyst	Auditor / DBA
m_patient	RESTRICTED	No direct table access	Authorized clinical access	No direct access	Auditor metadata/logs only; DBA privileged administration
v_patient_directory	CONFIDENTIAL / masked	SELECT only	Optional where needed	No direct access unless explicitly approved	Read for audit testing
visits	RESTRICTED	No direct access	Authorized clinical access	No direct access to identifiable operational table	Auditor access only where approved
billing	CONFIDENTIAL / financial	No direct access	Read only if care workflow requires it	De-identified aggregates only	Finance/audit access by approved purpose
fact_visits	CONFIDENTIAL / de-identified	No access	Not normally needed	SELECT only	Audit access where approved
dim_clinic	INTERNAL	Limited directory if needed	SELECT	SELECT	SELECT
master_audit	RESTRICTED	No access	No routine access	No access	Auditor SELECT; DBA administers

Apply least privilege with MySQL roles and GRANTs. The project handout’s example grants reception SELECT on a masked view, clinician access to the master, analyst access to the warehouse, and auditor access to relevant audit objects. Do not grant analysts direct access to raw staging or identifiable operational tables. Use named accounts rather than shared logins, MFA at the application/cloud layer where available, credential rotation and periodic grant reviews.
7.2 Masking and National ID handling
    • Reception directory: expose only fields required to identify a patient for the reception workflow; mask name and phone consistently. Avoid exposing sex or home district unless operationally necessary.
    • Analyst access: remove direct identifiers and suppress small-cell outputs where re-identification is plausible; access to de-identified data still requires governance.
    • National ID: master stores a 64-character SHA-256 digest only. Hashing is pseudonymization, not proof of anonymization; linked or guessable identifiers may still be personal data.
    • Raw staging: limit access to the migration team, encrypt backups and storage, record batch access, and define a short approved retention period for raw copies.
    • Secrets: do not place production passwords in SQL scripts or shared Git repositories. Use individual credentials and secret-management controls.
7.3 DPIA: patient SMS reminders
DPIA element	Assessment
Purpose	Send appointment reminders to reduce missed appointments; this is a proposed service, not confirmed as deployed.
Data involved	Patient contact number, appointment date/time, clinic name and minimum reminder content. Exclude diagnosis, HIV status and other sensitive clinical details from SMS.
People affected	Patients with a valid contact number and an approved basis/permission for reminders; include shared-phone and number-reassignment scenarios.
Necessity / proportionality	Use only the minimum data needed; offer a clear opt-out; avoid revealing the clinic specialty or sensitive condition in message content.
Key risks	SMS visible to another person; recycled/shared numbers; wrong recipient due to poor phone quality; provider access; mistaken consent/lawful basis assumptions.
Mitigations	Verify numbers, confirm contact preference, generic message wording, no sensitive diagnosis, restricted service account, transmission logs, retention limits, opt-out suppression and vendor review.
Approval gate	Privacy lead and clinical owner document lawful basis, notice, vendor controls and residual risk before pilot. Legal basis must be checked against applicable Ugandan requirements.

7.4 Breach response playbook
    13. Detect and report immediately to the designated incident contact; preserve evidence and record time, systems, data categories and affected recipients.
    14. Contain: stop the send/export, revoke exposed links or credentials, isolate affected accounts and request unintended recipients not to retain or forward the data.
    15. Assess: identify data subjects, sensitivity, volume, access, likely harm, and whether data were downloaded or further shared; involve privacy, clinical, IT and leadership roles.
    16. Notify: follow the applicable Ugandan legal requirements and internal escalation timetable. Do not assume a GDPR 72-hour deadline automatically applies; confirm the applicable legal trigger and deadline with the privacy/legal lead.
    17. Recover: restore secure access, rotate credentials, patch the process and validate that systems are safe.
    18. Communicate and learn: document decisions and notifications, support affected individuals where appropriate, complete root-cause analysis and assign preventive actions.
7.5 Technical controls and tests
Control	Test in Workbench / evidence
Masked view	SELECT from v_patient_directory as reception role; show only approved masked values.
Least privilege	SHOW GRANTS; attempt prohibited SELECT from m_patient as reception and confirm denial.
Immutable billing	Attempt UPDATE to an existing billing row in test database; confirm trigger rejects it; insert adjustment row instead.
Master audit	Update a permitted test master field and confirm master_audit records actor, timestamp and changed fields.
National ID hash	Inspect master schema and query for plaintext field absence; verify hash is 64 hex characters; restrict raw staging.
Backup and recovery	Record backup procedure and perform a restore test in isolated non-production environment.
Events	SHOW EVENTS and inspect dq_scorecard_log; demonstrate retention logic on synthetic test records.

8. Analytics and the Ministry of Health reporting pipeline
The warehouse is intended to support decision-making, consistent with the course notes’ definition of a data warehouse as an integrated, cleansed and standardized repository organized for analysis. The project brief specifically requires a monthly MoH report containing OPD attendance, top-10 diagnoses and revenue by service, delivered by the fifth day of each month.
8.1 Monthly pipeline
    19. Freeze reporting period and definitions; record report month, cut-off date and data owner.
    20. Run staging and master quality checks; resolve critical errors or document approved exclusions.
    21. Run ETL from operational visits/billing and conformed dimensions into fact_visits; capture load ID, row counts and failures.
    22. Reconcile source visits and billing totals to warehouse counts and amounts; investigate differences before release.
    23. Generate attendance by clinic/district, top-10 diagnoses and revenue by service; include unknown/missing diagnosis counts rather than silently dropping them.
    24. Clinical owner validates attendance and diagnosis results; Finance Manager validates revenue; authorized owner approves the report.
    25. Publish approved report/dashboard to authorized recipients by day 5; archive report version, SQL version, refresh time and sign-off.
8.2 KPI definitions
Report / KPI	Definition	Caution
OPD attendance	Count visits where visit_type='OPD', grouped by reporting month and clinic/district.	Use visit-level grain; define treatment of cancelled/void visits and late-arriving records.
Top-10 diagnoses	Count diagnosis-coded visits by diagnosis_code for the reporting period; rank descending.	Document missing/unknown codes and ties; the project handout sample query uses top-five as a teaching example, but final MoH requirement is top-10.
Revenue by service	Sum billing amount by service and reporting month using approved billing/adjustment logic.	The sample fact_visits example pivots only consultation/lab/medication columns; extend the warehouse to include admission/procedure and adjustments or clearly document exclusions.
Clinic comparison	Attendance and service revenue by clinic and district.	Compare like-for-like reporting periods and account for clinic-specific data gaps.
3-month attendance trend	Three-month moving average over monthly visit counts.	Descriptive trend only; it is not a validated forecast.
30-day re-attendance	Share of eligible patient visit sequences followed by another visit within 30 days, according to an approved definition.	Not automatically equivalent to clinical readmission; define cohort and clinical meaning before use.

8.3 BI and knowledge discovery
The course notes introduce KDD and CRISP-DM: business/domain understanding, data understanding, preparation, modeling/mining, evaluation and deployment. For MediLink, begin with descriptive BI and validated trends. Predictive work should follow a defined clinical/management question, appropriate data preparation, validation, evaluation and monitored deployment. The project’s suggested three-month moving average is a lightweight trend indicator, not a machine-learning model.
8.4 Dashboard and release evidence
    • Create one chart for each required query in Power BI/Tableau or an equivalent reporting interface, as specified by the brief.
    • Show month selector, clinic/district filter, KPI cards, top-10 diagnosis chart and service-revenue chart.
    • Record report refresh timestamp, data period, definitions, excluded records, validation owner and approval.
    • The written one-page management finding must be based on actual query outputs. Do not invent a claim such as 'revenue declined' without data.
Suggested management finding template: “For [month], the warehouse recorded [N] OPD visits across [N] clinics. The most frequent diagnosis codes were [codes]. Service revenue totaled [amount], of which [service] represented [share]. [Data-quality caveat] affected interpretation. The recommended action is [evidence-based action], owned by [role] and reviewed by [date].”
9. Roadmap: deployment, data mesh and AI candidates
9.1 Delivery roadmap
Stage	Priority work	Exit criteria
0–3 months: stabilize	Finish schema and constraints; inventory sources; approve governance and retention; baseline quality; establish backups, roles and audit.	All active sources catalogued; source counts reconciled; no plaintext National ID in master; role tests pass.
3–6 months: operationalize	Automate repeatable staging/ETL, scorecards and MoH report; steward queue SLAs; train users; monitor report delivery.	Two consecutive monthly reports reconciled and approved by day 5; weekly quality logs retained.
6–12 months: resilience and scale	Capacity tests; restore drills; managed hosting pilot if approved; monitoring/alerting; formal access recertification.	Documented recovery test, load test and approved cost/security comparison.
12+ months: controlled innovation	Pilot data-domain ownership, advanced analytics and diagnosis coding assistance only after data and clinical governance maturity.	Approved DPIA/clinical safety assessment, human review, measured performance and rollback plan.

9.2 Managed MySQL versus on-premises
Consideration	Managed MySQL service	On-premises MySQL
Operations	Provider manages some backups, patching, failover and infrastructure; exact scope depends on service.	MediLink manages hardware, patching, backups, failover, monitoring and capacity.
Control	Less control over low-level infrastructure; review region, service terms and configuration options.	Greater direct infrastructure control; greater responsibility for physical security and operations.
Availability / recovery	May offer managed replicas, point-in-time recovery and multi-zone options at extra cost.	Requires designed and tested replication, backup storage, standby infrastructure and recovery procedures.
Connectivity	Needs secure network design from clinics; account for outages and latency.	Can be close to clinics but remote branches still need secure connectivity.
Cost	Usage-based charges, storage, backup, egress and support; model actual monthly costs.	Capital and operational costs for servers, power, cooling, connectivity, staff and replacement.
Recommendation	Preferred candidate for a pilot if connectivity, lawful processing, data location, contracts and cost are approved.	Reasonable where reliable local operations, existing skills and infrastructure justify it; must still meet recovery and security standards.

Decision gate: run a documented proof of concept with realistic volume, recovery, security and connectivity tests. Verify provider data location, contract, access logging, encryption, backup retention and incident responsibilities before moving identifiable health data.
9.3 Data mesh: each clinic as a domain
A data-mesh approach could later assign each clinic responsibility for its source data as a domain product: clinic data owner, steward, definitions, quality service levels and metadata. Shared central capabilities would continue to provide identity resolution, common patient/clinic definitions, privacy controls, integration standards and the enterprise warehouse. A mesh should not create four incompatible patient masters; the enterprise MDM and cross-clinic reporting contract remain shared.
Domain	Local accountability	Shared platform contract
Kampala / Mukono / Mbarara / Gulu clinic domains	Capture quality, source lineage, timely extracts, local correction workflow and local data owner.	Standard patient/source identifiers, phone format, visit taxonomy, metadata registration, security and quality measures.
Enterprise MDM	Resolve cross-clinic identity and steward conflicts.	Golden record, source crosswalk, survivorship policy, audit.
Enterprise analytics	Publish agreed report definitions and dashboards.	Conformed dimensions, governed metrics, report cut-off and validation.

9.4 AI candidate: diagnosis auto-coding
Potential use: suggest standardized diagnosis codes from clinician-entered text or structured encounter information. This is a candidate for a later controlled pilot, not an automatic production decision. The course notes’ KDD/CRISP-DM process supports defining the business objective, understanding and preparing data, modeling, evaluating and deploying only after validation.
    • Start with clinician-approved code suggestions; the clinician remains responsible for the final code.
    • Use approved, representative historical data with access controls and documented provenance; exclude data that is not authorized for model development.
    • Evaluate precision/recall by diagnosis group, subgroup performance, uncertainty, unsupported suggestions and clinical harm risk; compare to a baseline.
    • Log model version, input, suggestion, clinician acceptance/override and outcome, with strict access and retention controls.
    • Require clinical governance, privacy assessment, security review, monitoring for drift and a rollback mechanism before deployment.
Other possible analytical candidates include attendance forecasting and operational anomaly detection. These should follow an explicit use case, validated data, evaluation criteria and human interpretation rather than being added simply because AI is available.
10. Individual reflection and contribution log
This section must be completed by each student in their own words. The template below is deliberately editable because the reference PDFs do not identify your personal work, team membership or actual implementation outcomes. Do not claim a task or result you did not perform.
10.1 Individual reflection template
During this project, my main responsibility was [specific role/tasks]. I contributed by [specific SQL scripts, design artefacts, data-quality analysis, metadata work, security tests or report/dashboard tasks]. The most important technical lesson I learned was [lesson] because [specific example from the implementation]. One challenge was [actual challenge]; I addressed it by [actual action] and verified the result using [query, test or evidence].
The EDM concepts I applied most directly were [normalization / ER modeling / MDM / ETL / data warehousing / BI / KDD-CRISP-DM / privacy and security]. This changed my understanding of enterprise data management because [specific reflection]. If I repeated the project, I would improve [specific process] by [realistic action]. My contribution can be verified from [commits, SQL files, Workbench screenshots, meeting notes, dashboard version or document section].
10.2 Contribution log
Date / week	Team role	Task completed	Artifact / evidence	Verification / reviewer
[Enter date]	[Steward / Custodian / Analyst / Documenter]	[Actual task, specific]	[SQL filename, commit, screenshot, report]	[Test result / reviewer]
[Enter date]	[Role]	[Actual task]	[Artifact]	[Verification]
[Enter date]	[Role]	[Actual task]	[Artifact]	[Verification]
[Enter date]	[Role]	[Actual task]	[Artifact]	[Verification]
[Enter date]	[Role]	[Actual task]	[Artifact]	[Verification]

Team working model from the brief: teams of 3–5 students rotate the Data Steward, Custodian, Analyst and Documenter roles. Record actual role rotations and named contributions; the generic model above is not evidence of any particular person’s work.

Appendix A. MySQL Workbench evidence checklist
Before submission, execute the relevant scripts in MySQL 8.0+ and replace placeholders with real outputs. The project PDF contains SQL examples for the phases; those examples should be tested as a coherent build, not copied without checking schema dependencies and syntax.
Phase	Required evidence to capture	Status
0 — Setup & inventory	MySQL version; CREATE DATABASE medilink; source inventory (system, owner, format, volume, quality reputation).	Done
1 — Lifecycle	data_lifecycle_policy table and one-page create/store/use/archive/delete map per data class.	Done
2 — Governance	data_ownership, raci, policies, compliance_register; approved charter and policies.	Done
3 — Architecture	ERD, schema.sql, architecture diagram; PK/FK/constraints; visit and billing relationship checks.	Done
4 — Data quality	Raw baseline profile, cleansing queries, after-scorecard, weekly logging, root-cause analysis.	Done
5 — MDM	Sarah’s three source rows mapped to one master; patient_source_links; survivorship table; review queue.	Done
6 — ETL / warehouse	Dimension and fact tables populated; ETL counts and revenue reconciliation; workflow diagram.	Done
7 — Metadata	INFORMATION_SCHEMA dictionary, glossary, data_lineage, impact analysis for diagnosis_code or m_patient.	Done
8 — Security	RBAC SHOW GRANTS; masked reception view; prohibited access denied; immutable billing trigger; audit row; DPIA.	[ ]
9 — BI	MoH attendance, top-10 diagnoses and revenue-by-service outputs; charts; one-page evidence-based finding.	[ ]
10 — Automation	SHOW EVENTS; dq_scorecard_log rows; lifecycle event tested safely on synthetic records; demo rehearsal.	[ ]

Implementation cautions before running the sample SQL
    • Review SQL syntax carefully: PDF text extraction can obscure symbols such as COUNT(*), multiplication signs, aliases and line breaks. Validate every script in MySQL Workbench.
    • Do not run shortened retention examples against real clinical records. The project brief says the 10-day window is only a demonstration; production clinical retention is 10 years, then archive and purge under approved rules.
    • Make ETL idempotent or record batch IDs so rerunning a load does not duplicate dimensions, master rows or fact rows.
    • Do not treat phone match confidence as a legal/clinical identity guarantee. Queue conflicts and preserve source lineage.
    • Confirm the final MoH report uses top 10 diagnoses, not the top-five example in the phase teaching SQL.
    • Revenue-by-service must include all required service types and use a documented rule for adjustments, voids and cancelled billing; the teaching sample may need extension.
    • Do not store passwords in shared SQL files; use non-production test accounts and rotate any demo credentials.
    • Use current, legally reviewed Ugandan privacy requirements. The course notes include general privacy concepts and non-Ugandan legal references; do not copy those references as if they were Ugandan law.
Appendix B. References
Niyibizi, K. (n.d.). *Fundamentals of enterprise data management: A business analytics course* [Course notes]. Kampala International University, School of Mathematics and Computing.
MediLink Health Network. (n.d.). *MediLink Health Network Enterprise Data Platform: Capstone project* [Course project handout].
Note. The uploaded course notes and capstone handout are the primary sources for this strategy. Confirm the lecturer’s preferred bibliographic details and citation format before submission. Any legal references should be checked against the current official Ugandan legal text and institutional guidance.
Final submission check
    • All 10 required sections are present and use the MediLink scenario and business rules.
    • Architecture diagram, ERD and metadata/lineage extracts are included or attached from actual project artefacts.
    • Before/after metrics come from executed SQL, with denominator and timestamp, not illustrative numbers.
    • Compliance register is updated only where evidence exists; unresolved items remain OPEN or PARTIAL.
    • SQL, screenshots, dashboard charts and contribution log are attached and consistent with the written strategy.
    • Every student has completed the reflection honestly and the team has rehearsed the 15-minute demo.

APPENDIX B — PHASE-BY-PHASE MYSQL 8.0 SQL IMPLEMENTATION SCRIPTS
Purpose. This appendix supplies executable starter SQL aligned to the ten project phases. Run the phases sequentially in a development database, inspect the outputs, and retain screenshots/logs as evidence. The scripts use the project’s stated MySQL 8.0+ platform and are included here because the phase SQL is a required part of the build.
Important execution and evidence note. These scripts have not been executed against the student's MySQL instance. Therefore, this document does not assert that tables, controls, events, metrics, or dashboards have been successfully deployed. Capture actual Workbench results and replace illustrative/empty evidence fields in the main report. Test destructive or privilege-sensitive operations only in a controlled development database.
Execution order: Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 → Phase 7 → Phase 8 → Phase 9 → Phase 10.
Compatibility note. The SQL below is written for MySQL 8.0+. Some administrative statements (roles, triggers, events and global Event Scheduler configuration) require DBA privileges. The project’s original examples contain a few malformed aggregate expressions and omitted identifiers; the scripts below use explicit MySQL syntax while preserving the stated business rules. Review local law and organisational policy before operational use, especially retention, lawful basis, breach notification, and handling of National ID values.
PHASE 0 — Environment setup and source inventory
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
PHASE 1 — Data lifecycle policy
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
PHASE 2 — Governance framework registers
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
PHASE 3 — Core master schema and operational model
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
PHASE 4 — Data quality profiling, cleansing and scorecard
Profiles source quality, standardises phone/sex/date fields and queues records that cannot be safely repaired.
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
SET name_clean = CONCAT(UPPER(LEFT(TRIM(pname),1)), LOWER(SUBSTRING(TRIM(pname),2))),
    phone_norm = CASE
      WHEN LENGTH(REGEXP_REPLACE(phone_no,'[^0-9]',''))=12
       AND REGEXP_REPLACE(phone_no,'[^0-9]','') REGEXP '^256[0-9]{9}$'
        THEN REGEXP_REPLACE(phone_no,'[^0-9]','')
      WHEN LENGTH(REGEXP_REPLACE(phone_no,'[^0-9]',''))=10
       AND REGEXP_REPLACE(phone_no,'[^0-9]','') REGEXP '^0[0-9]{9}$'
        THEN CONCAT('256',SUBSTRING(REGEXP_REPLACE(phone_no,'[^0-9]',''),2))
      ELSE NULL END,
    sex_clean = CASE UPPER(TRIM(gender))
      WHEN 'M' THEN 'M' WHEN 'MALE' THEN 'M'
      WHEN 'F' THEN 'F' WHEN 'FEMALE' THEN 'F' ELSE NULL END,
    dob_clean = CASE
      WHEN TRIM(dob_raw) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        THEN STR_TO_DATE(dob_raw,'%Y-%m-%d')
      WHEN TRIM(dob_raw) REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
        THEN STR_TO_DATE(dob_raw,'%d/%m/%Y')
      WHEN TRIM(dob_raw) REGEXP '^[0-9]{4}/[0-9]{2}/[0-9]{2}$'
        THEN STR_TO_DATE(dob_raw,'%Y/%m/%d')
      ELSE NULL END;
 
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
       SUM(phone IS NOT NULL AND phone NOT REGEXP '^256[0-9]{9}$') AS invalid_phones
FROM m_patient;
 
SELECT * FROM v_dq_scorecard;
SELECT * FROM dq_review_queue ORDER BY created_at DESC;
PHASE 5 — Master Data Management, survivorship and review queue
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
PHASE 6 — ETL into dimensional warehouse
Builds dimensions and visit fact table and performs an upsert-style ETL load.
USE medilink;
 
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
PHASE 7 — Metadata, glossary and lineage
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
PHASE 8 — Security, privacy, RBAC, audit and immutable billing
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
PHASE 9 — Ministry of Health reporting and analytics
Supplies monthly OPD, top diagnosis, revenue by service, moving-average and return-visit queries.
USE medilink;
 
-- A. Monthly OPD attendance by district and clinic; detail plus roll-up rows.
SELECT dc.district,dc.clinic_name,DATE_FORMAT(f.visit_date,'%Y-%m') AS year_month,
       COUNT(*) AS visit_count
FROM fact_visits f
JOIN dim_clinic dc ON dc.clinic_sk=f.clinic_sk
WHERE f.visit_type='OPD'
GROUP BY dc.district,dc.clinic_name,year_month WITH ROLLUP;
 
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
SELECT DATE_FORMAT(v.visit_date,'%Y-%m') AS year_month,b.service,
       SUM(b.amount) AS revenue
FROM visits v
JOIN billing b ON b.visit_id=v.visit_id
WHERE v.visit_date >= @report_start AND v.visit_date < @report_end
GROUP BY year_month,b.service
ORDER BY year_month,b.service;
 
-- D. Three-month moving average of monthly visit counts.
SELECT year_month,visits,
       ROUND(AVG(visits) OVER (ORDER BY year_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),1)
         AS moving_average_3_month
FROM (
  SELECT DATE_FORMAT(visit_date,'%Y-%m') AS year_month,COUNT(*) AS visits
  FROM fact_visits GROUP BY DATE_FORMAT(visit_date,'%Y-%m')
) monthly
ORDER BY year_month;
 
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
PHASE 10 — DataOps automation and lifecycle enforcement
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
