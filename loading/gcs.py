import json
import logging
from datetime import datetime, timezone
from google.cloud import storage

logger = logging.getLogger(__name__)

gcs_client = storage.Client()
RAW_BUCKET = "fpl-raw"
DLQ_BUCKET = "fpl-dlq"


def read_raw(blob_path):
    blob = gcs_client.bucket(RAW_BUCKET).blob(blob_path)
    return json.loads(blob.download_as_text())


def list_blobs(prefix):
    return [b.name for b in gcs_client.list_blobs(RAW_BUCKET, prefix=prefix)]


def write_dlq(raw_record, table_name, drift, run_timestamp):
    detected_at = datetime.now(timezone.utc).isoformat()
    payload = {
        "raw_record": raw_record,
        "drift": drift,
        "table": table_name,
        "run_timestamp": run_timestamp,
        "detected_at": detected_at,
    }
    blob_path = f"{table_name}/{run_timestamp}/{detected_at}.json"
    blob = gcs_client.bucket(DLQ_BUCKET).blob(blob_path)
    blob.upload_from_string(json.dumps(payload), content_type="application/json")
    logger.warning(f"Routed record to DLQ: gs://{DLQ_BUCKET}/{blob_path}\nCause: {drift}")
