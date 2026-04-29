# FPL Data Pipeline

An end-to-end data pipeline that ingests data from the [Fantasy Premier League API](https://fantasy.premierleague.com/api/bootstrap-static/), persists it to BigQuery, and runs dbt transformations to produce analytics-ready tables.

---

## Architecture

```
Cloud Scheduler (3AM daily, Europe/Dublin)
        ↓
Cloud Workflows (fpl-pipeline)
        ↓
  Step 1: Cloud Run Service — Ingestion
          Pulls data from FPL API → BigQuery raw tables
        ↓ (only triggers on success)
  Step 2: Cloud Run Job — dbt
          Runs dbt models → BigQuery mart tables
```

---

## Repository Structure

```
fpl-api/
├── ingestion/
│   ├── main.py                     # Cloud Run ingestion job
│   ├── schemas.py                  # BigQuery table schemas
│   ├── player-summary-backfill.py  # One-off player history backfill
│   └── requirements.txt
│
├── transform/                      # dbt project
│   ├── models/
│   │   ├── mart/
│   │   │   └── fct_top_players.sql
│   │   └── staging/
│   │       └── sources.yml
│   ├── macros/
│   ├── Dockerfile
│   ├── dbt_project.yml
│   └── profiles_example.yml        # Template — copy to profiles.yml locally
│
├── fpl_workflow.yml                # Cloud Workflows definition
├── SETUP.md                        # Full setup guide
├── RUNBOOK.md                      # Operational guide
├── .gitignore
└── README.md
```

---

## GCP Resources

| Resource | Name | Purpose |
|---|---|---|
| Cloud Run Service | `fpl-ingestion` | Daily FPL API ingestion |
| Cloud Run Job | `dbt-fpl` | dbt transformations |
| Cloud Workflows | `fpl-pipeline` | Orchestrates ingestion → dbt |
| Cloud Scheduler | `fpl-daily-pipeline` | Triggers workflow at 3AM daily |
| Artifact Registry | `fpl-repo` | Stores the dbt Docker image |
| BigQuery Dataset | `fpl_data` | Raw and mart tables |
| Secret Manager | `DBT_SA_*` | dbt service account credentials |

---

## BigQuery Tables

### Raw (populated by ingestion job)

| Table | Description |
|---|---|
| `players` | All FPL players and their season stats |
| `fixtures` | All fixtures with difficulty ratings |
| `teams` | All Premier League teams |
| `matches` | Gameweek metadata |
| `player_types` | Position definitions (GK, DEF, MID, FWD) |
| `player_history` | Per-gameweek player stats — populated by backfill script |

### Mart (produced by dbt)

| Table | Description |
|---|---|
| `fct_top_players` | Top performing players ranked by a composite value score, with upcoming fixture difficulty |

The composite ranking score is `points_per_million + points_per_90 + xgi_per_90`, which surfaces players who are cheap relative to their returns, consistent over 90 minutes, and involved in goals — filtered to players with over 1500 minutes played.

---

## Getting Started

See [SETUP.md](./SETUP.md) for the full step-by-step guide to stand this up in your own GCP project.

See [RUNBOOK.md](./RUNBOOK.md) for day-to-day operations, failure handling, and how to deploy changes.

---

## Local Development

### Run ingestion locally

```bash
cd ingestion
pip install -r requirements.txt
gcloud auth application-default login
python main.py
```

### Run dbt locally

```bash
cd transform
cp profiles_example.yml profiles.yml
# populate profiles.yml with your GCP project ID
# export DBT_SA_* environment variables from your service account JSON (see SETUP.md)
pip install dbt-bigquery
dbt run --profiles-dir .
```

### Run the player history backfill

```bash
cd ingestion
python player-summary-backfill.py
```
