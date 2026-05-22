import requests
import logging
import json
from datetime import datetime, timezone
from google.cloud import storage

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

gcs_client = storage.Client()
RAW_BUCKET = "fpl-raw"
FPL_MAIN_URL = "https://fantasy.premierleague.com/api/bootstrap-static/"
FPL_FIXTURES_URL = "https://fantasy.premierleague.com/api/fixtures/"


def api_call(url):
    logger.info(f"Making API request to: {url}")
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        logger.info(f"API request successful — status code: {response.status_code}")
        return response.json()
    except requests.exceptions.Timeout:
        logger.error(f"Request timed out for URL: {url}")
        raise
    except requests.exceptions.HTTPError as e:
        logger.error(f"HTTP error occurred: {e} — status code: {response.status_code}")
        raise
    except requests.exceptions.RequestException as e:
        logger.error(f"API request failed: {e}")
        raise


def dump_to_gcs(data, blob_path):
    bucket = gcs_client.bucket(RAW_BUCKET)
    blob = bucket.blob(blob_path)
    blob.upload_from_string(json.dumps(data), content_type="application/json")
    logger.info(f"Dumped raw data to gs://{RAW_BUCKET}/{blob_path}")


def main(request=None):
    logger.info("FPL ingestion started")

    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    data = api_call(FPL_MAIN_URL)
    dump_to_gcs(data, f"bootstrap-static/{timestamp}.json")

    fixtures = api_call(FPL_FIXTURES_URL)
    dump_to_gcs(fixtures, f"fixtures/{timestamp}.json")

    logger.info("FPL ingestion completed")
    return "OK", 200
