# FPL Data Pipeline

An end-to-end data pipeline built on GCP that ingests data from the [Fantasy Premier League API](https://fantasy.premierleague.com/api/bootstrap-static/) and produces analytics-ready tables in BigQuery using a Medallion architecture.

---

## Architecture

```
Cloud Scheduler (3AM daily, Europe/Dublin)
        ↓
Cloud Function — Ingestion (Bronze)
        Fetches FPL API → raw JSON dumped to GCS
        ↓
Cloud Function — Loading (Silver)
        Schema validation → BigQuery tables (drift routed to DLQ)
        ↓
Cloud Run Job — dbt (Gold)
        SQL transformations → BigQuery mart tables
```

---

## Medallion Layers

| Layer | Location | Description |
|---|---|---|
| Bronze | `gs://fpl-raw/` | Raw API responses, untouched, timestamped by run |
| Silver | BigQuery `fpl_data` | Schema-validated, structured tables |
| Gold | BigQuery `fpl_data` | dbt mart tables ready for analytics |

---

## Repository Structure

```
fpl-api/
├── ingestion/              # Bronze — Cloud Function
│   ├── main.py
│   ├── fpl_client.py
│   ├── gcs.py
│   └── requirements.txt
│
├── loading/                # Silver — Cloud Function
│   ├── main.py
│   ├── gcs.py
│   ├── bq.py
│   ├── schema.py
│   ├── transforms.py
│   └── requirements.txt
│
├── transform/              # Gold — dbt project
│   ├── models/
│   │   ├── mart/
│   │   │   └── fct_top_players.sql
│   │   └── staging/
│   │       └── sources.yml
│   ├── Dockerfile
│   ├── dbt_project.yml
│   └── profiles.yml
│
├── Makefile                # Deployment commands
├── fpl_workflow.yml        # Cloud Workflows definition
├── SETUP.md
└── RUNBOOK.md
```

---

## GCP Resources

| Resource | Name | Purpose |
|---|---|---|
| Cloud Function | `fpl-ingestion` | Fetches FPL API, dumps raw JSON to GCS |
| Cloud Function | `fpl-loading` | Validates schemas, loads to BigQuery |
| Cloud Run Job | `dbt-fpl` | Runs dbt Gold layer transformations |
| Cloud Scheduler | `fpl-daily` | Triggers ingestion at 3AM daily |
| GCS Bucket | `fpl-raw` | Bronze raw landing zone |
| GCS Bucket | `fpl-schema-registry` | Versioned BigQuery schema definitions |
| GCS Bucket | `fpl-dlq` | Dead letter queue for schema drift |
| BigQuery Dataset | `fpl_data` | Silver and Gold tables |
| Artifact Registry | `fpl-repo` | dbt Docker image |
| Secret Manager | `DBT_SA_*` | dbt service account credentials |

---

## BigQuery Tables

### Silver

| Table | Source | Description |
|---|---|---|
| `players` | bootstrap-static | All FPL players and season stats |
| `teams` | bootstrap-static | All Premier League teams |
| `matches` | bootstrap-static | Gameweek metadata |
| `player_types` | bootstrap-static | Position definitions |
| `fixtures` | fixtures endpoint | All fixtures with difficulty ratings |
| `element_summary` | element-summary endpoint | Per-gameweek player stats |

### Gold (dbt)

| Table | Description |
|---|---|
| `fct_top_players` | Top players ranked by a composite value score with upcoming fixture difficulty |

---

## Deployment

Copy `.env.example` to `.env` and fill in your project values, then use `make`:

```bash
make deploy-ingestion   # deploy Bronze function
make deploy-loading     # deploy Silver function
make trigger-ingestion  # manually trigger an ingestion run
make trigger-loading    # manually trigger a loading run
```

---

## Schema Registry

Schemas are stored as versioned JSON files in `gs://fpl-schema-registry/`. GCS object versioning is enabled so every update retains the previous version.

To update a schema after an FPL API change:
1. Download the existing schema: `gsutil cp gs://fpl-schema-registry/players.json players.json`
2. Add the new field to the JSON file
3. Upload: `gsutil cp players.json gs://fpl-schema-registry/players.json`

The loading function picks up the updated schema on the next run — no redeployment needed.

---

## Dead Letter Queue

Records that fail schema validation (unexpected new fields) are routed to `gs://fpl-dlq/` rather than dropped. Each DLQ file contains the raw record, the drift details, and the run timestamp for investigation.

---

## Local Development

```bash
# Authenticate
gcloud auth application-default login

# Run ingestion locally
cd ingestion && pip install -r requirements.txt && python -c "import main; main.main()"

# Run dbt locally
cd transform && pip install dbt-bigquery && dbt run --profiles-dir .
```
