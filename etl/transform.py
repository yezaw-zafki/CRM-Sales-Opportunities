"""Transform stage: clean dimensions and the fact table."""

from __future__ import annotations

import logging

import pandas as pd

from .config import PRODUCT_NAME_MAP

LOG = logging.getLogger("crm_etl.transform")


def transform_dimensions(frames: dict[str, pd.DataFrame]) -> dict[str, pd.DataFrame]:
    """Clean dimension tables (accounts, products, sales_teams)."""
    out: dict[str, pd.DataFrame] = {}

    if "dim_accounts" in frames:
        df = frames["dim_accounts"].copy()
        df["year_established"] = pd.to_numeric(df["year_established"], errors="coerce")
        df["revenue"] = pd.to_numeric(df["revenue"], errors="coerce")
        df["employees"] = pd.to_numeric(df["employees"], errors="coerce")
        out["dim_accounts"] = df

    if "dim_products" in frames:
        df = frames["dim_products"].copy()
        df["sales_price"] = pd.to_numeric(df["sales_price"], errors="coerce")
        out["dim_products"] = df

    if "dim_sales_teams" in frames:
        out["dim_sales_teams"] = frames["dim_sales_teams"].copy()

    return out


def transform_facts(frames: dict[str, pd.DataFrame]) -> dict[str, pd.DataFrame]:
    """Clean the fact_opportunities table and derive helper columns."""
    df = frames["fact_opportunities"].copy()

    # Normalize inconsistent product names
    df["product"] = df["product"].replace(PRODUCT_NAME_MAP)

    # Parse dates
    df["engage_date"] = pd.to_datetime(df["engage_date"], errors="coerce").dt.date
    df["close_date"] = pd.to_datetime(df["close_date"], errors="coerce").dt.date

    # Cast numeric
    df["close_value"] = pd.to_numeric(df["close_value"], errors="coerce")

    # Derive columns useful for Tableau dashboards
    stage = df["deal_stage"].str.lower()
    df["is_won"] = stage.eq("won")
    df["is_lost"] = stage.eq("lost")
    df["is_open"] = ~stage.isin({"won", "lost"})
    df["deal_stage"] = df["deal_stage"].str.title()

    return {"fact_opportunities": df}


def validate(frames: dict[str, pd.DataFrame]) -> None:
    """Log validation warnings for nulls in critical columns."""
    critical = {
        "fact_opportunities": ["opportunity_id", "deal_stage"],
        "dim_accounts": ["account"],
        "dim_products": ["product"],
        "dim_sales_teams": ["sales_agent"],
    }
    for table, cols in critical.items():
        if table not in frames:
            continue
        df = frames[table]
        for col in cols:
            if col in df.columns:
                n_nulls = int(df[col].isnull().sum())
                if n_nulls:
                    LOG.warning("%s.%s: %d null values", table, col, n_nulls)

    LOG.info(
        "Validation complete. Tables: %s",
        ", ".join(sorted(frames)),
    )
