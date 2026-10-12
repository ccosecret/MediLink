# MediLink Health Network — Enterprise Data Management

An integrated enterprise data management (EDM) strategy for **MediLink Health Network**, a
Ugandan network formed by merging four clinics (Kampala, Mukono, Mbarara, Gulu) with
separate patient-registration systems and one paper-based branch.

The proposed platform is a MySQL 8.0+ hub-and-spoke design: clinic and paper-derived
records enter controlled staging, profiling and cleansing standardize the data, Master
Data Management (MDM) assigns one golden record per patient while preserving source
crosswalks, ETL loads a dimensional warehouse, and BI queries support monthly Ministry
of Health reporting.

## Repository layout

| Path | Contents |
| --- | --- |
| `mediLink.sql` | Consolidated MySQL 8.0+ build script covering all phases (revision 4, safe-update-mode safe, includes synthetic demo data) |
| `docs/script.md` | Full written strategy document, including the phase-by-phase SQL appendix |
| `docs/MediLink.docx` | Strategy document in Word format |
| `phases/` | One folder per phase: executable SQL plus the supporting MySQL Workbench screenshot |

Each `phases/phaseN/` folder is self-contained:

```
phases/
├── README.md                 # execution order, evidence register, safe-use notes
├── phase0/                   # Environment setup and source inventory
│   ├── phase0.sql
│   └── phase0.png
├── phase1/                   # Data lifecycle policy
│   ├── phase1.sql
│   └── phase1.png
│   ...
└── phase10/                  # DataOps automation and lifecycle enforcement
    ├── phase10.sql
    └── phase10.png
```

## Phase overview

| Phase | Focus |
| --- | --- |
| 0 | Environment setup and source inventory |
| 1 | Data lifecycle policy |
| 2 | Governance framework registers |
| 3 | Core master schema and operational model |
| 4 | Data quality profiling, cleansing and scorecard |
| 5 | Master Data Management, survivorship and review queue |
| 6 | ETL into dimensional warehouse |
| 7 | Metadata, glossary and lineage |
| 8 | Security, privacy, RBAC, audit and immutable billing |
| 9 | Ministry of Health reporting and analytics |
| 10 | DataOps automation and lifecycle enforcement |

## Running the scripts

Execute the phases in order in a **development** database:

```sql
SOURCE mediLink.sql;            -- or run each phase individually
SOURCE phases/phase0/phase0.sql;
SOURCE phases/phase1/phase1.sql;
-- ... through phase10
```

Phase 8 (roles, triggers) and Phase 10 (events) require DBA-level privileges. Run the
scripts in a SQL client that supports `DELIMITER`, such as the MySQL CLI or Workbench.

## Status of the evidence

> **The SQL has not been executed against a live MySQL instance.** Tables, controls,
> events, metrics and dashboards are therefore *specified*, not demonstrated. Every
> phase names the evidence to capture; those fields are still `To be completed after
> execution`. Actual MySQL Workbench outputs must be captured before any metrics or
> tests are claimed.

Sample records are fictional project data — never load real patient data into a
classroom or demo environment.

## Key controls

- **Patient identity** — one golden record per patient, phone normalized as `256XXXXXXXXX`,
  ambiguous identity conflicts routed to a data steward rather than silently merged
- **Privacy** — National ID stored only as a SHA-256 hash in the master, least-privilege
  roles, masked reception directory, de-identified analyst access and audit logging
- **Billing integrity** — billing rows immutable, corrections applied via adjustment rows
- **Lifecycle** — ten-year clinical retention before archive and purge under approved rules;
  purging is deliberately not automated
