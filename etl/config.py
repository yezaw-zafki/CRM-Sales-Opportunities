"""ETL package configuration.

Loads environment variables and defines project paths and source/target
mapping for the CRM sales ETL pipeline.
"""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = PROJECT_ROOT / "data" / "raw"

# Load .env from project root (silently if missing)
load_dotenv(PROJECT_ROOT / ".env")

# ---------------------------------------------------------------------------
# PostgreSQL connection settings
# ---------------------------------------------------------------------------
PG_HOST = os.getenv("PG_HOST", "localhost")
PG_PORT = os.getenv("PG_PORT", "5432")
PG_DBNAME = os.getenv("PG_DBNAME", "crm_sales")
PG_USER = os.getenv("PG_USER", "postgres")
PG_PASSWORD = os.getenv("PG_PASSWORD", "")

# ---------------------------------------------------------------------------
# Source file -> target table mapping
# ---------------------------------------------------------------------------
SOURCE_FILES = {
    "accounts.csv": "dim_accounts",
    "products.csv": "dim_products",
    "sales_teams.csv": "dim_sales_teams",
    "sales_pipeline.csv": "fact_opportunities",
}

# Load order respects foreign-key dependencies (dimensions before facts)
LOAD_ORDER = ["dim_accounts", "dim_products", "dim_sales_teams", "fact_opportunities"]

# Product name normalizations observed in source data
PRODUCT_NAME_MAP = {
    "GTXPro": "GTX Pro",
    "GTXPro Basic": "GTX Plus Basic",
    "GTXPro Plus": "GTX Plus Pro",
}
