import time
import logging
import requests

logger = logging.getLogger(__name__)

BASE_URL = "https://fantasy.premierleague.com/api"
REQUEST_DELAY = 0.1
LOG_INTERVAL = 200


def _get(url):
    response = requests.get(url, timeout=10)
    response.raise_for_status()
    return response.json()


def fetch_bootstrap_static():
    logger.info("Fetching bootstrap-static")
    return _get(f"{BASE_URL}/bootstrap-static/")


def fetch_fixtures():
    logger.info("Fetching fixtures")
    return _get(f"{BASE_URL}/fixtures/")


def fetch_element_summaries(element_ids):
    logger.info(f"Fetching element summaries for {len(element_ids)} players")
    failed = []

    for i, element_id in enumerate(element_ids):
        try:
            data = _get(f"{BASE_URL}/element-summary/{element_id}/")
            data["element_id"] = element_id
            yield element_id, data
        except Exception as e:
            logger.warning(f"Failed to fetch element summary for player {element_id}: {e}")
            failed.append(element_id)

        if i % LOG_INTERVAL == 0:
            logger.info(f"Progress: {i}/{len(element_ids)} players fetched")

        time.sleep(REQUEST_DELAY)

    if failed:
        logger.warning(f"Failed to fetch {len(failed)} players: {failed}")
