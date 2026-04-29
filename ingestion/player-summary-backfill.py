'''
Backfill script for FPL player history.
Fetches per-gameweek history for every player via the FPL element-summary
endpoint and loads the results directly into BigQuery, reusing the same
client/schema pattern as main.py.

Run when a full backfill is needed:
    python player-summary-pull.py

# Table write disposition is WRITE_TRUNCATE — re-runnable without duplicating data
'''

import requests
import logging
import time
from datetime import datetime, timezone
from google.cloud import bigquery
from schemas import SCHEMAS

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

client = bigquery.Client()
DATASET_ID = "fpl_data"
TABLE_NAME = "player_history"
BASE_URL = "https://fantasy.premierleague.com/api"

# API Call delay as to not bombard API
REQUEST_DELAY = 0.1

# Log progress every N players
LOG_INTERVAL = 50


def get_all_player_ids() -> list[int]:
    logger.info("Fetching player list from bootstrap-static...")
    resp = requests.get(f"{BASE_URL}/bootstrap-static/", timeout=10)
    resp.raise_for_status()
    elements = resp.json()["elements"]
    logger.info(f"Found {len(elements)} players")
    return [p["id"] for p in elements]


def get_player_history(player_id: int) -> list[dict]:
    resp = requests.get(f"{BASE_URL}/element-summary/{player_id}/", timeout=10)
    resp.raise_for_status()
    history = resp.json().get("history", [])
    for row in history:
        row["player_id"] = player_id
    return history


def fetch_all_history(player_ids: list[int]) -> list[dict]:
    all_rows = []
    failed = []

    for i, pid in enumerate(player_ids):
        try:
            rows = get_player_history(pid)
            all_rows.extend(rows)
        except Exception as e:
            logger.warning(f"Failed for player {pid}: {e}")
            failed.append(pid)

        if i % LOG_INTERVAL == 0:
            logger.info(f"Progress: {i}/{len(player_ids)} players fetched ({len(all_rows)} rows so far)")

        time.sleep(REQUEST_DELAY)

    if failed:
        logger.warning(f"Failed to fetch {len(failed)} players: {failed}")

    logger.info(f"Finished fetching — {len(all_rows)} total rows from {len(player_ids) - len(failed)} players")
    return all_rows


def push_to_bigquery(rows: list[dict]) -> None:
    if not rows:
        logger.warning("No rows to load — skipping BigQuery push")
        return

    table_id = f"{client.project}.{DATASET_ID}.{TABLE_NAME}"
    ingestion_timestamp = datetime.now(timezone.utc).isoformat()

    for row in rows:
        row["ingestion_timestamp"] = ingestion_timestamp

    schema = SCHEMAS['player_history']

    job_config = bigquery.LoadJobConfig(
        schema=schema,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    )

    logger.info(f"Loading {len(rows)} rows into {table_id}...")
    job = client.load_table_from_json(rows, table_id, job_config=job_config)
    job.result()
    logger.info(f"Successfully loaded {len(rows)} rows into {table_id}")


def main():
    logger.info("Player history backfill started")
    player_ids = get_all_player_ids()
    rows = fetch_all_history(player_ids)
    push_to_bigquery(rows)
    logger.info("Player history backfill completed")


if __name__ == "__main__":
    main()