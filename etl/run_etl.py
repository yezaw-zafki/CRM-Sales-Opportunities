"""CRM Sales ETL pipeline entry point.

Extracts raw CRM sales data from CSV/Excel files, transforms it with pandas,
and loads it into PostgreSQL in a single one-time migration.

Usage:
    python -m etl.run_etl
"""

from __future__ import annotations

import logging
import sys

from .config import PROJECT_ROOT
from .extract import extract_all
from .load import get_connection, load_all
from .transform import transform_dimensions, transform_facts, validate

LOG = logging.getLogger("crm_etl")
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
)


def run() -> int:
    LOG.info("Starting CRM sales ETL")
    frames = extract_all()
    if not frames:
        LOG.error("No source files extracted. Aborting.")
        return 1

    transformed: dict = {}
    transformed.update(transform_dimensions(frames))
    transformed.update(transform_facts(frames))

    validate(transformed)

    conn = None
    try:
        conn = get_connection()
        counts, _mappings = load_all(conn, transformed)
        total = sum(counts.values())
        LOG.info("ETL complete. Loaded tables: %s", counts)
        LOG.info("Total rows loaded: %d", total)
        return 0
    except Exception as exc:  # noqa: BLE001
        LOG.exception("ETL failed: %s", exc)
        if conn:
            conn.rollback()
        return 1
    finally:
        if conn:
            conn.close()


if __name__ == "__main__":
    sys.exit(run())
