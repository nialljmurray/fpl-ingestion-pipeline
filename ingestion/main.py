import logging
import json
from datetime import datetime, timezone
import google.cloud.logging

import fpl_client
import gcs

google.cloud.logging.Client().setup_logging()
logger = logging.getLogger(__name__)


def main(request=None):
    logger.info("FPL ingestion started")
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    bootstrap = fpl_client.fetch_bootstrap_static()
    gcs.dump_raw(bootstrap, f"bootstrap-static/{timestamp}.json")
    logger.info(f"Dumped bootstrap-static to gs://fpl-raw/bootstrap-static/{timestamp}.json")

    fixtures = fpl_client.fetch_fixtures()
    gcs.dump_raw(fixtures, f"fixtures/{timestamp}.json")
    logger.info(f"Dumped fixtures to gs://fpl-raw/fixtures/{timestamp}.json")

    element_ids = [e["id"] for e in bootstrap["elements"]]
    count = 0
    for element_id, summary in fpl_client.fetch_element_summaries(element_ids):
        gcs.dump_raw(summary, f"element-summaries/{timestamp}/{element_id:04d}.json")
        count += 1
    logger.info(f"Wrote {count} element summaries to GCS")

    logger.info("FPL ingestion completed")
    return json.dumps({"run_timestamp": timestamp}), 200, {"Content-Type": "application/json"}
