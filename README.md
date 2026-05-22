# FPL Data Pipeline

An end-to-end data pipeline built on GCP that ingests data from the [Fantasy Premier League API](https://fantasy.premierleague.com/api/bootstrap-static/) and produces analytics-ready tables in BigQuery using a Medallion architecture.

---

## Architecture

```
Cloud Scheduler (3AM daily UTC)
        ↓
Cloud Workflows — fpl-pipeline
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
│   ├── player-summary-backfill.py
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
│   │   │   ├── fct_captain_picks.sql
│   │   │   ├── fct_differentials.sql
│   │   │   ├── fct_fixture_schedule.sql
│   │   │   ├── fct_player_form.sql
│   │   │   ├── fct_player_gameweek.sql
│   │   │   ├── fct_player_season_stats.sql
│   │   │   ├── fct_top_players.sql
│   │   │   └── fct_transfer_trends.sql
│   │   └── staging/
│   │       ├── stg_element_summary.sql
│   │       ├── stg_fixtures.sql
│   │       ├── stg_players.sql
│   │       └── stg_teams.sql
│   ├── Dockerfile
│   ├── dbt_project.yml
│   └── profiles.yml
│
├── workflow_example.yaml   # Cloud Workflows definition (placeholder values)
├── Makefile                # Deployment and trigger commands
└── .env.example            # Environment variable template
```

---

## GCP Resources

| Resource | Name | Purpose |
|---|---|---|
| Cloud Function | `fpl_ingestion` | Fetches FPL API, dumps raw JSON to GCS |
| Cloud Function | `fpl_loading` | Validates schemas, loads to BigQuery |
| Cloud Run Job | `dbt-fpl` | Runs dbt Gold layer transformations |
| Cloud Workflows | `fpl-pipeline` | Orchestrates ingestion → loading → dbt |
| Cloud Scheduler | `fpl-pipeline-nightly` | Triggers workflow at 3AM UTC daily |
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
| `fct_captain_picks` | Captain pick analysis |
| `fct_differentials` | Low-ownership, high-scoring differential players |
| `fct_fixture_schedule` | Upcoming fixture difficulty by team |
| `fct_player_form` | Recent form over rolling gameweeks |
| `fct_player_gameweek` | Per-gameweek player performance |
| `fct_player_season_stats` | Aggregated season-level player stats |
| `fct_top_players` | Top players ranked by composite value score |
| `fct_transfer_trends` | Transfer in/out trends across gameweeks |

---

## Deployment

Copy `.env.example` to `.env` and fill in your project values, then use `make`:

```bash
make deploy-ingestion    # deploy Bronze Cloud Function
make deploy-loading      # deploy Silver Cloud Function
make deploy-workflow     # deploy Cloud Workflows definition
make create-scheduler    # create Cloud Scheduler job (one-time setup)
```

---

## Running Manually

```bash
make run-workflow        # execute the full pipeline and stream results
make trigger-ingestion   # trigger ingestion only
make trigger-loading     # trigger loading only (prompts for run_timestamp)
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
