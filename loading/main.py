import logging
import google.cloud.logging
from google.cloud import bigquery

import gcs
import schema
import bq
import transforms

ELEMENT_SUMMARY_BATCH_SIZE = 1000

google.cloud.logging.Client().setup_logging()
logger = logging.getLogger(__name__)

# Tables extracted directly from bootstrap-static
BOOTSTRAP_TABLES = {
    "players":      "elements",
    "teams":        "teams",
    "matches":      "events",
    "player_types": "element_types",
}


def process_table(records, table_name, run_timestamp):
    loaded_schema = schema.load_schema(table_name)
    clean_rows = []

    for record in records:
        record = transforms.apply(record, table_name)
        clean_record, drift = schema.validate(record, loaded_schema)
        if drift:
            gcs.write_dlq(record, table_name, drift, run_timestamp)
        clean_rows.append(clean_record)

    bq.load(clean_rows, table_name, loaded_schema)


def main(request):
    body = request.get_json(silent=True) or {}
    run_timestamp = body.get("run_timestamp")

    if not run_timestamp:
        return "Missing run_timestamp in request body", 400

    logger.info(f"Silver loading started for run: {run_timestamp}")
    bq.ensure_dataset_exists()

    # Bootstrap-static tables
    bootstrap = gcs.read_raw(f"bootstrap-static/{run_timestamp}.json")
    for table_name, key in BOOTSTRAP_TABLES.items():
        logger.info(f"Processing {table_name}")
        process_table(bootstrap[key], table_name, run_timestamp)

    # Fixtures
    logger.info("Processing fixtures")
    fixtures = gcs.read_raw(f"fixtures/{run_timestamp}.json")
    process_table(fixtures, "fixtures", run_timestamp)

    # Element summaries — batched to keep memory flat
    logger.info("Processing element summaries")
    element_summary_schema = schema.load_schema("element_summary")
    batch = []
    first_batch = True

    for blob_path in gcs.list_blobs(f"element-summaries/{run_timestamp}/"):
        player_data = gcs.read_raw(blob_path)
        for record in player_data.get("history", []):
            clean_record, drift = schema.validate(record, element_summary_schema)
            if drift:
                gcs.write_dlq(record, "element_summary", drift, run_timestamp)
            batch.append(clean_record)

            if len(batch) >= ELEMENT_SUMMARY_BATCH_SIZE:
                write_disposition = bigquery.WriteDisposition.WRITE_TRUNCATE if first_batch else bigquery.WriteDisposition.WRITE_APPEND
                bq.load(batch, "element_summary", element_summary_schema, write_disposition=write_disposition)
                first_batch = False
                batch = []

    if batch:
        write_disposition = bigquery.WriteDisposition.WRITE_TRUNCATE if first_batch else bigquery.WriteDisposition.WRITE_APPEND
        bq.load(batch, "element_summary", element_summary_schema, write_disposition=write_disposition)

    logger.info(f"Silver loading completed for run: {run_timestamp}")
    return "OK", 200
