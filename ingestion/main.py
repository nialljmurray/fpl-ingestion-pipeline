'''
File used in order to grab data from the FPL API and persist it to BQ
'''

import requests
import logging
from datetime import datetime, timezone
from google.cloud import bigquery
from ingestion.schemas import SCHEMAS
import json

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

client = bigquery.Client()
DATASET_ID = "fpl_data"
FPL_MAIN_URL = 'https://fantasy.premierleague.com/api/bootstrap-static/'
FPL_FIXTURES_URL = 'https://fantasy.premierleague.com/api/fixtures/'

def api_call(url):
    logger.info(f"Making API request to: {url}")
    try:
        returned_data = requests.get(url, timeout=10)
        returned_data.raise_for_status()
        logger.info(f"API request successful — status code: {returned_data.status_code}")
        return returned_data.json()

    except requests.exceptions.Timeout:
        logger.error(f"Request timed out for URL: {url}")
        raise

    except requests.exceptions.HTTPError as e:
        logger.error(f"HTTP error occurred: {e} — status code: {returned_data.status_code}")
        raise

    except requests.exceptions.RequestException as e:
        logger.error(f"API request failed: {e}")
        raise

    except ValueError as e:
        logger.error(f"Failed to parse JSON response: {e}")
        raise

def push_to_bigquery(data, table_name):
    table_id = f"{client.project}.{DATASET_ID}.{table_name}"

    ingestion_timestamp = datetime.now(timezone.utc).isoformat()
    for row in data:
        row['ingestion_timestamp'] = ingestion_timestamp
        if table_name == "matches" and row.get('overrides'):
            ov = row['overrides']
            row['overrides'] = {
                'pick_multiplier': ov.get('pick_multiplier'),
                'rules':           json.dumps(ov.get('rules')),
                'scoring':         json.dumps(ov.get('scoring')),
                'element_types':   json.dumps(ov.get('element_types')),
            }

    schema = SCHEMAS[table_name]

    job_config = bigquery.LoadJobConfig(
        schema=schema,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    )

    job = client.load_table_from_json(data, table_id, job_config=job_config)
    job.result()
    logger.info(f"Loaded {len(data)} rows into {table_id}")

def main(request=None):
    logger.info("FPL Cloud Function started")

    data = api_call(FPL_MAIN_URL)
    fixtures = api_call(FPL_FIXTURES_URL)

    tables = {
        "players":      data['elements'],
        "teams":        data['teams'],
        "matches":      data['events'],
        "player_types": data['element_types'],
        "fixtures":     fixtures,
    }

    for table_name, table_data in tables.items():
        push_to_bigquery(table_data, table_name)

    logger.info("FPL Cloud Function completed successfully")
    return "OK", 200