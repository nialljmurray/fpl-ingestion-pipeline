import json
from google.cloud import storage

gcs_client = storage.Client()
RAW_BUCKET = "fpl-raw"


def dump_raw(data, blob_path):
    bucket = gcs_client.bucket(RAW_BUCKET)
    blob = bucket.blob(blob_path)
    blob.upload_from_string(json.dumps(data), content_type="application/json")
