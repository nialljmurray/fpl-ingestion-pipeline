import json
import logging
from google.cloud import bigquery, storage

logger = logging.getLogger(__name__)

gcs_client = storage.Client()
SCHEMA_BUCKET = "fpl-schema-registry"


def load_schema(table_name):
    blob = gcs_client.bucket(SCHEMA_BUCKET).blob(f"{table_name}.json")
    schema_json = json.loads(blob.download_as_text())
    return [bigquery.SchemaField.from_api_repr(f) for f in schema_json]


def validate(record, schema):
    """
    Compares a record against the expected schema.

    - New fields (in record, not in schema): stripped, flagged as drift
    - Missing fields (in schema, not in record): nulled, not flagged

    Returns (clean_record, drift) where drift is None if no issues found.
    """
    schema_field_names = {f.name for f in schema} - {"ingestion_timestamp"}
    record_field_names = set(record.keys())

    new_fields = record_field_names - schema_field_names
    missing_fields = schema_field_names - record_field_names

    clean_record = {k: v for k, v in record.items() if k in schema_field_names}

    for field in missing_fields:
        clean_record[field] = None

    drift = {"new_fields": sorted(new_fields), "missing_fields": sorted(missing_fields)} if new_fields else None

    return clean_record, drift
