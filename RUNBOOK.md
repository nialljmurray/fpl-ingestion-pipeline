# Runbook

Operational guide for the FPL data pipeline. Covers day-to-day operations, failure handling, deployments, and credential rotation.

---

## Daily Pipeline

The pipeline runs automatically at 3AM Europe/Dublin time via Cloud Scheduler:

1. Cloud Scheduler triggers Cloud Workflows (`fpl-pipeline`)
2. Workflow triggers the Cloud Run ingestion service (`fpl-ingestion`)
3. On success, workflow triggers the dbt Cloud Run Job (`dbt-fpl`)
4. dbt transforms raw tables into mart tables in BigQuery

---

## Manually Triggering the Pipeline

### Trigger the full pipeline (ingestion + dbt)

```bash
gcloud workflows run fpl-pipeline \
  --location=europe-west1 \
  --project=YOUR_PROJECT_ID
```

### Trigger ingestion only

```bash
curl -X POST YOUR_INGESTION_CLOUD_RUN_URL \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)"
```

### Trigger dbt only

```bash
gcloud run jobs execute dbt-fpl \
  --region europe-west1 \
  --wait
```

---

## Checking Pipeline Status

### View recent workflow executions

```bash
gcloud workflows executions list fpl-pipeline \
  --location=europe-west1 \
  --limit=5
```

### View ingestion logs

```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="fpl-ingestion"' \
  --project=YOUR_PROJECT_ID \
  --limit=50 \
  --format="value(textPayload)"
```

### View dbt logs

```bash
gcloud logging read \
  'resource.type="cloud_run_job" AND resource.labels.job_name="dbt-fpl"' \
  --project=YOUR_PROJECT_ID \
  --limit=50 \
  --format="value(textPayload)"
```

Or via the GCP Console:

- Ingestion: **Cloud Run → fpl-ingestion → Logs**
- dbt: **Cloud Run → Jobs → dbt-fpl → Executions → [execution] → Logs**
- Workflow: **Workflows → fpl-pipeline → Executions**

---

## Failure Scenarios

### Ingestion job failed

1. Check the ingestion logs for the error
2. Common causes:
   - FPL API down — re-run once the API recovers, it is occasionally unavailable during maintenance
   - Schema mismatch — FPL occasionally adds new fields; update `schemas.py`, redeploy, and re-run
   - BigQuery permissions — verify the ingestion service account has `roles/bigquery.dataEditor`
3. Re-run the full pipeline once resolved:
```bash
gcloud workflows run fpl-pipeline --location=europe-west1
```

### dbt job failed (exit code 2)

Exit code 2 is a dbt compilation or runtime error.

1. Check the dbt logs for the error
2. Common causes:
   - SQL error in a model — fix, rebuild the image, redeploy, re-run
   - Source table missing — confirm ingestion ran successfully and tables exist in BigQuery
   - Secret misconfiguration — verify the `DBT_SA_*` secrets in Secret Manager contain the correct values (see Verifying Secrets below)
3. Re-run dbt once fixed:
```bash
gcloud run jobs execute dbt-fpl --region europe-west1 --wait
```

### Workflow failed before triggering dbt

If ingestion succeeded but the workflow failed before running dbt, trigger dbt manually:

```bash
gcloud run jobs execute dbt-fpl --region europe-west1 --wait
```

---

## Deploying Changes

### Ingestion changes (main.py / schemas.py)

```bash
gcloud run deploy fpl-ingestion \
  --source ./ingestion \
  --region europe-west1
```

### dbt model changes

Rebuild the image and update the Cloud Run Job:

```bash
cd transform

docker build \
  --platform linux/amd64 \
  --build-arg DBT_PROFILES="$(cat profiles.yml)" \
  -t europe-west1-docker.pkg.dev/YOUR_PROJECT_ID/fpl-repo/dbt-fpl:latest .

docker push europe-west1-docker.pkg.dev/YOUR_PROJECT_ID/fpl-repo/dbt-fpl:latest

gcloud run jobs update dbt-fpl \
  --image europe-west1-docker.pkg.dev/YOUR_PROJECT_ID/fpl-repo/dbt-fpl:latest \
  --region europe-west1
```

Test before considering it done:

```bash
gcloud run jobs execute dbt-fpl --region europe-west1 --wait
```

### Workflow changes

```bash
gcloud workflows deploy fpl-pipeline \
  --location=europe-west1 \
  --source=fpl_workflow.yml
```

---

## Player History Backfill

Re-run whenever a full refresh of `player_history` is needed (e.g. after schema changes):

```bash
cd ingestion
python player-summary-backfill.py
```

Uses `WRITE_TRUNCATE` — safe to re-run, replaces the table without duplicating data. Takes approximately 3-4 minutes.

---

## Rotating Service Account Credentials

1. Generate a new key in GCP Console: **IAM & Admin → Service Accounts → fpl-dbt-sa → Keys → Add Key**
2. Download the new JSON file
3. Update each secret in Secret Manager with the new values:

```bash
# Read values from the new key file and update each secret
echo -n "$(cat new-key.json | jq -r '.private_key')" | \
  gcloud secrets versions add DBT_SA_PRIVATE_KEY --data-file=-

echo -n "$(cat new-key.json | jq -r '.private_key_id')" | \
  gcloud secrets versions add DBT_SA_PRIVATE_KEY_ID --data-file=-

echo -n "$(cat new-key.json | jq -r '.client_email')" | \
  gcloud secrets versions add DBT_SA_CLIENT_EMAIL --data-file=-

echo -n "$(cat new-key.json | jq -r '.client_id')" | \
  gcloud secrets versions add DBT_SA_CLIENT_ID --data-file=-

# Repeat for any other values that changed
```

4. Test the dbt job runs successfully:

```bash
gcloud run jobs execute dbt-fpl --region europe-west1 --wait
```

5. Delete the old key from GCP Console once confirmed working.

---

## Verifying Secrets

To check the value stored in a secret:

```bash
gcloud secrets versions access latest --secret=DBT_SA_CLIENT_EMAIL
```

To list all secrets:

```bash
gcloud secrets list
```

You should see 10 secrets prefixed with `DBT_SA_`.

---

## Adding a New dbt Model

1. Create a feature branch:

```bash
git checkout main && git pull origin main
git checkout -b feature/your-model-name
```

2. Add your SQL file to `transform/models/mart/` or `transform/models/staging/`

3. Test locally:

```bash
cd transform
dbt run --select your_model_name --profiles-dir .
```

4. Rebuild and push the image:

```bash
docker build \
  --platform linux/amd64 \
  --build-arg DBT_PROFILES="$(cat profiles.yml)" \
  -t europe-west1-docker.pkg.dev/YOUR_PROJECT_ID/fpl-repo/dbt-fpl:latest .

docker push europe-west1-docker.pkg.dev/YOUR_PROJECT_ID/fpl-repo/dbt-fpl:latest
```

5. Update and test the Cloud Run Job:

```bash
gcloud run jobs update dbt-fpl \
  --image europe-west1-docker.pkg.dev/YOUR_PROJECT_ID/fpl-repo/dbt-fpl:latest \
  --region europe-west1

gcloud run jobs execute dbt-fpl --region europe-west1 --wait
```

6. Merge via PR into `main`.

---

## Useful GCP Console Links

| Resource | Console Path |
|---|---|
| Cloud Run Services | Cloud Run → Services |
| Cloud Run Jobs | Cloud Run → Jobs |
| Cloud Workflows | Workflows |
| Cloud Scheduler | Cloud Scheduler |
| BigQuery | BigQuery |
| Artifact Registry | Artifact Registry → Repositories → fpl-repo |
| Secret Manager | Security → Secret Manager |
| Logs Explorer | Logging → Logs Explorer |
