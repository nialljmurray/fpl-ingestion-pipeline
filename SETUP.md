# Setup Guide

This guide walks through standing up the full FPL data pipeline from scratch in your own GCP project. Follow the steps in order.

---

## Prerequisites

Install the following before starting:

- [Python 3.11+](https://www.python.org/downloads/)
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [jq](https://jqlang.github.io/jq/) — `brew install jq` on Mac

---

## Before You Start — Placeholders

The following placeholders appear throughout this guide. Find your own values and substitute them as you go:

| Placeholder | Description | Example |
|---|---|---|
| `YOUR_PROJECT_ID` | Your GCP project ID | `my-project-123456` |
| `YOUR_INGESTION_CLOUD_RUN_URL` | URL of the deployed ingestion Cloud Run service — available after step 5.2 | `https://fpl-ingestion-abc123-ew.a.run.app` |
| `YOUR_COMPUTE_SA` | Your default Compute Engine service account — available after step 1.1 | `123456789-compute@developer.gserviceaccount.com` |
| `YOUR_USERNAME` | Your GitHub username | `niallmcd` |

---

## 1 — GCP Project Setup

### 1.1 — Authenticate and set your project

```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

Find your Compute Engine service account (you will need this in steps 8 and 9):

```bash
gcloud iam service-accounts list --project=YOUR_PROJECT_ID
```

Look for the entry ending in `@developer.gserviceaccount.com` — this is `YOUR_COMPUTE_SA`.

### 1.2 — Enable required APIs

```bash
gcloud services enable \
  run.googleapis.com \
  bigquery.googleapis.com \
  workflows.googleapis.com \
  cloudscheduler.googleapis.com \
  secretmanager.googleapis.com \
  artifactregistry.googleapis.com
```

### 1.3 — Create the BigQuery dataset

```bash
bq mk --dataset --location=EU YOUR_PROJECT_ID:fpl_data
```

---

## 2 — Service Accounts

You need two service accounts: one for the ingestion Cloud Run job and one for dbt.

### 2.1 — Create the ingestion service account

```bash
gcloud iam service-accounts create fpl-ingestion-sa \
  --display-name="FPL Ingestion Service Account"
```

Grant it BigQuery access:

```bash
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:fpl-ingestion-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataEditor"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:fpl-ingestion-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/bigquery.jobUser"
```

### 2.2 — Create the dbt service account

```bash
gcloud iam service-accounts create fpl-dbt-sa \
  --display-name="FPL dbt Service Account"
```

Grant it BigQuery access:

```bash
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:fpl-dbt-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataEditor"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:fpl-dbt-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/bigquery.jobUser"
```

### 2.3 — Download the dbt service account key

```bash
gcloud iam service-accounts keys create dbt-sa-key.json \
  --iam-account=fpl-dbt-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

> Keep this file safe. It will be used to populate Secret Manager in step 4. Do not commit it to the repository — it is already covered by `.gitignore`.

---

## 3 — Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/fpl-api.git
cd fpl-api
```

### 3.1 — Update sources.yml

Open `transform/models/staging/sources.yml` and replace `YOUR_PROJECT_ID` with your actual GCP project ID:

```yaml
sources:
  - name: fpl_data
    database: YOUR_PROJECT_ID   # ← replace this
    schema: fpl_data
```

### 3.2 — Update fpl_workflow.yml

Open `fpl_workflow.yml` in the repo root. You will fill in the two placeholders here after deploying the ingestion job in step 5 — leave them for now and come back.

---

## 4 — Secret Manager

Store each field from your dbt service account JSON file as an individual secret in Secret Manager:

```bash
echo -n "$(cat dbt-sa-key.json | jq -r '.type')" | \
  gcloud secrets create DBT_SA_TYPE --data-file=-

echo -n "$(cat dbt-sa-key.json | jq -r '.project_id')" | \
  gcloud secrets create DBT_SA_PROJECT_ID --data-file=-

echo -n "$(cat dbt-sa-key.json | jq -r '.private_key_id')" | \
  gcloud secrets create DBT_SA_PRIVATE_KEY_ID --data-file=-

echo -n "$(cat dbt-sa-key.json | jq -r '.private_key')" | \
  gcloud secrets create DBT_SA_PRIVATE_KEY --data-file=-

echo -n "$(cat dbt-sa-key.json | jq -r '.client_email')" | \
  gcloud secrets create DBT_SA_CLIENT_EMAIL --data-file=-

echo -n "$(cat dbt-sa-key.json | jq -r '.client_id')" | \
  gcloud secrets create DBT_SA_CLIENT_ID --data-file=-

echo -n "$(cat dbt-sa-key.json | jq -r '.auth_uri')" | \
  gcloud secrets create DBT_SA_AUTH_URI --data-file=-

echo -n "$(cat dbt-sa-key.json | jq -r '.token_uri')" | \
  gcloud secrets create DBT_SA_TOKEN_URI --data-file=-

echo -n "$(cat dbt-sa-key.json | jq -r '.auth_provider_x509_cert_url')" | \
  gcloud secrets create DBT_SA_AUTH_PROVIDER_CERT_URL --data-file=-

echo -n "$(cat dbt-sa-key.json | jq -r '.client_x509_cert_url')" | \
  gcloud secrets create DBT_SA_CLIENT_CERT_URL --data-file=-
```

Verify all 10 secrets were created:

```bash
gcloud secrets list
```

---

## 5 — Deploy the Ingestion Job

### 5.1 — Deploy to Cloud Run

From the repo root:

```bash
gcloud run deploy fpl-ingestion \
  --source ./ingestion \
  --region europe-west1 \
  --service-account=fpl-ingestion-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com \
  --no-allow-unauthenticated
```

### 5.2 — Note the service URL

```bash
gcloud run services describe fpl-ingestion \
  --region europe-west1 \
  --format="value(status.url)"
```

Save this URL — this is `YOUR_INGESTION_CLOUD_RUN_URL`, needed in step 8.

### 5.3 — Test the ingestion job

```bash
curl -X POST YOUR_INGESTION_CLOUD_RUN_URL \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)"
```

Check BigQuery to confirm the tables were populated:

```bash
bq ls fpl_data
```

You should see: `fixtures`, `matches`, `player_types`, `players`, `teams`.

---

## 6 — Set Up dbt Locally and Verify

Verify dbt can connect to BigQuery from your machine before building the Docker image — it is much faster to debug connection issues locally than via Cloud Run logs.

### 6.1 — Install dbt

```bash
pip install dbt-bigquery
```

### 6.2 — Set up profiles.yml

```bash
cd transform
cp profiles_example.yml profiles.yml
```

Open `profiles.yml` and replace `YOUR_PROJECT_ID` with your actual GCP project ID.

### 6.3 — Export service account values as environment variables

```bash
export DBT_SA_TYPE=$(cat /path/to/dbt-sa-key.json | jq -r '.type')
export DBT_SA_PROJECT_ID=$(cat /path/to/dbt-sa-key.json | jq -r '.project_id')
export DBT_SA_PRIVATE_KEY_ID=$(cat /path/to/dbt-sa-key.json | jq -r '.private_key_id')
export DBT_SA_PRIVATE_KEY=$(cat /path/to/dbt-sa-key.json | jq -r '.private_key')
export DBT_SA_CLIENT_EMAIL=$(cat /path/to/dbt-sa-key.json | jq -r '.client_email')
export DBT_SA_CLIENT_ID=$(cat /path/to/dbt-sa-key.json | jq -r '.client_id')
export DBT_SA_AUTH_URI=$(cat /path/to/dbt-sa-key.json | jq -r '.auth_uri')
export DBT_SA_TOKEN_URI=$(cat /path/to/dbt-sa-key.json | jq -r '.token_uri')
export DBT_SA_AUTH_PROVIDER_CERT_URL=$(cat /path/to/dbt-sa-key.json | jq -r '.auth_provider_x509_cert_url')
export DBT_SA_CLIENT_CERT_URL=$(cat /path/to/dbt-sa-key.json | jq -r '.client_x509_cert_url')
```

### 6.4 — Test the connection

```bash
dbt debug --profiles-dir .
```

All checks should pass. If you see a BigQuery connection error, verify `fpl-dbt-sa` has the correct IAM roles from step 2.2.

### 6.5 — Run dbt locally

```bash
dbt run --profiles-dir .
```

Check BigQuery for the `fct_top_players` table. If this succeeds you are ready to build the Docker image.

---

## 7 — Build and Deploy the dbt Cloud Run Job

### 7.1 — Authenticate Docker with GCP

```bash
gcloud auth configure-docker europe-west1-docker.pkg.dev
```

### 7.2 — Create the Artifact Registry repository

```bash
gcloud artifacts repositories create fpl-repo \
  --repository-format=docker \
  --location=europe-west1 \
  --project=YOUR_PROJECT_ID
```

### 7.3 — Build and push the Docker image

Make sure you are inside the `transform/` directory:

```bash
cd transform

docker build \
  --platform linux/amd64 \
  --build-arg DBT_PROFILES="$(cat profiles.yml)" \
  -t europe-west1-docker.pkg.dev/YOUR_PROJECT_ID/fpl-repo/dbt-fpl:latest .

docker push europe-west1-docker.pkg.dev/YOUR_PROJECT_ID/fpl-repo/dbt-fpl:latest
```

> The `--platform linux/amd64` flag is required on Apple Silicon Macs. Without it the image will build for ARM and fail on Cloud Run.

### 7.4 — Grant the dbt service account access to Secret Manager

```bash
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:fpl-dbt-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### 7.5 — Create the Cloud Run Job

```bash
gcloud run jobs create dbt-fpl \
  --image europe-west1-docker.pkg.dev/YOUR_PROJECT_ID/fpl-repo/dbt-fpl:latest \
  --region europe-west1 \
  --service-account=fpl-dbt-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com \
  --set-secrets="DBT_SA_TYPE=DBT_SA_TYPE:latest,\
DBT_SA_PROJECT_ID=DBT_SA_PROJECT_ID:latest,\
DBT_SA_PRIVATE_KEY_ID=DBT_SA_PRIVATE_KEY_ID:latest,\
DBT_SA_PRIVATE_KEY=DBT_SA_PRIVATE_KEY:latest,\
DBT_SA_CLIENT_EMAIL=DBT_SA_CLIENT_EMAIL:latest,\
DBT_SA_CLIENT_ID=DBT_SA_CLIENT_ID:latest,\
DBT_SA_AUTH_URI=DBT_SA_AUTH_URI:latest,\
DBT_SA_TOKEN_URI=DBT_SA_TOKEN_URI:latest,\
DBT_SA_AUTH_PROVIDER_CERT_URL=DBT_SA_AUTH_PROVIDER_CERT_URL:latest,\
DBT_SA_CLIENT_CERT_URL=DBT_SA_CLIENT_CERT_URL:latest"
```

### 7.6 — Test the dbt job in isolation

```bash
gcloud run jobs execute dbt-fpl --region europe-west1 --wait
```

Confirm `fct_top_players` exists in BigQuery:

```bash
bq ls fpl_data
```

---

## 8 — Configure Cloud Workflows

### 8.1 — Update fpl_workflow.yml

Open `fpl_workflow.yml` in the repo root and replace:

- `YOUR_INGESTION_CLOUD_RUN_URL` → the URL from step 5.2
- `YOUR_PROJECT_ID` → your GCP project ID

### 8.2 — Grant the Compute service account permissions

```bash
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:YOUR_COMPUTE_SA@developer.gserviceaccount.com" \
  --role="roles/run.invoker"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:YOUR_COMPUTE_SA@developer.gserviceaccount.com" \
  --role="roles/workflows.invoker"
```

### 8.3 — Deploy the workflow

```bash
gcloud workflows deploy fpl-pipeline \
  --location=europe-west1 \
  --source=fpl_workflow.yml \
  --project=YOUR_PROJECT_ID
```

### 8.4 — Test the full pipeline end-to-end

```bash
gcloud workflows run fpl-pipeline \
  --location=europe-west1 \
  --project=YOUR_PROJECT_ID
```

Watch the execution in the GCP Console under **Workflows → fpl-pipeline → Executions**. Both steps should show as succeeded.

---

## 9 — Configure Cloud Scheduler

Set up the daily 3AM trigger pointing at the workflow:

```bash
gcloud scheduler jobs create http fpl-daily-pipeline \
  --schedule="0 3 * * *" \
  --location=europe-west1 \
  --uri="https://workflowexecutions.googleapis.com/v1/projects/YOUR_PROJECT_ID/locations/europe-west1/workflows/fpl-pipeline/executions" \
  --message-body="{}" \
  --oauth-service-account-email=YOUR_COMPUTE_SA@developer.gserviceaccount.com \
  --time-zone="Europe/Dublin"
```

---

## 10 — Player History Backfill (one-off)

Run this once to populate the `player_history` table with historical per-gameweek data for all players:

```bash
cd ingestion
pip install -r requirements.txt
gcloud auth application-default login
python player-summary-backfill.py
```

This fetches ~700 players with a 0.1s delay between requests and takes approximately 3-4 minutes. The table uses `WRITE_TRUNCATE` so it is safe to re-run at any time.

---

## Verify Everything is Working

```bash
# Check Cloud Run services
gcloud run services list --region europe-west1

# Check Cloud Run jobs
gcloud run jobs list --region europe-west1

# Check workflows
gcloud workflows list --location europe-west1

# Check scheduler
gcloud scheduler jobs list --location europe-west1

# Check BigQuery tables
bq ls fpl_data
```

Expected BigQuery tables at this point: `fixtures`, `matches`, `player_types`, `players`, `teams`, `player_history`, `fct_top_players`.
