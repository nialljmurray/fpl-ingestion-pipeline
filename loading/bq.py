import logging
from datetime import datetime, timezone
from google.cloud import bigquery

logger = logging.getLogger(__name__)

bq_client = bigquery.Client()
DATASET_ID = "fpl_data"
LOCATION = "europe-west1"

TABLE_CONFIG = {
    "element_summary": {
        "range_partitioning": bigquery.RangePartitioning(
            field="round",
            range_=bigquery.PartitionRange(start=1, end=38, interval=1),
        ),
        "clustering_fields": ["element"],
    },
    "fixtures": {
        "clustering_fields": ["team_h", "team_a"],
    },
    "players": {
        "clustering_fields": ["team"],
    },
}


def ensure_dataset_exists():
    dataset_ref = bigquery.Dataset(f"{bq_client.project}.{DATASET_ID}")
    try:
        bq_client.get_dataset(dataset_ref)
    except Exception:
        dataset_ref.location = LOCATION
        bq_client.create_dataset(dataset_ref)
        logger.info(f"Created dataset {DATASET_ID}")


def load(rows, table_name, schema, write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE):
    if not rows:
        logger.warning(f"No rows to load for {table_name} — skipping")
        return

    table_id = f"{bq_client.project}.{DATASET_ID}.{table_name}"
    ingestion_timestamp = datetime.now(timezone.utc).isoformat()

    for row in rows:
        row["ingestion_timestamp"] = ingestion_timestamp

    config = TABLE_CONFIG.get(table_name, {})
    job_config = bigquery.LoadJobConfig(
        schema=schema,
        write_disposition=write_disposition,
        create_disposition=bigquery.CreateDisposition.CREATE_IF_NEEDED,
        range_partitioning=config.get("range_partitioning"),
        clustering_fields=config.get("clustering_fields"),
    )

    job = bq_client.load_table_from_json(rows, table_id, job_config=job_config)
    job.result()
    logger.info(f"Loaded {len(rows)} rows into {table_id}")
