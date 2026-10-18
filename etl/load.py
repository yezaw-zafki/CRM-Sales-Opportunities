"""Load stage: create PostgreSQL tables with surrogate keys and bulk-insert.

Dimension tables receive auto-increment primary keys (account_id, product_id,
sales_agent_id). The fact table (fact_sale) connects only by those IDs, so the
loader builds a natural-key -> id mapping per dimension before inserting facts.
"""

from __future__ import annotations

import logging

import pandas as pd
from psycopg2 import connect
from psycopg2.extras import execute_values

from .config import PG_DBNAME, PG_HOST, PG_PASSWORD, PG_PORT, PG_USER

LOG = logging.getLogger("crm_etl.load")

DDL = {
    "dim_accounts": """
        CREATE TABLE IF NOT EXISTS dim_accounts (
            account_id SERIAL PRIMARY KEY,
            account TEXT UNIQUE NOT NULL,
            sector TEXT,
            year_established INTEGER,
            revenue NUMERIC,
            employees INTEGER,
            office_location TEXT,
            subsidiary_of TEXT
        );
    """,
    "dim_products": """
        CREATE TABLE IF NOT EXISTS dim_products (
            product_id SERIAL PRIMARY KEY,
            product TEXT UNIQUE NOT NULL,
            series TEXT,
            sales_price NUMERIC
        );
    """,
    "dim_sales_teams": """
        CREATE TABLE IF NOT EXISTS dim_sales_teams (
            sales_agent_id SERIAL PRIMARY KEY,
            sales_agent TEXT UNIQUE NOT NULL,
            manager TEXT,
            regional_office TEXT
        );
    """,
    "fact_sale": """
        CREATE TABLE IF NOT EXISTS fact_sale (
            opportunity_id TEXT PRIMARY KEY,
            sales_agent_id INTEGER NOT NULL REFERENCES dim_sales_teams(sales_agent_id),
            product_id INTEGER NOT NULL REFERENCES dim_products(product_id),
            account_id INTEGER REFERENCES dim_accounts(account_id),
            deal_stage TEXT,
            engage_date DATE,
            close_date DATE,
            close_value NUMERIC,
            is_won BOOLEAN,
            is_lost BOOLEAN,
            is_open BOOLEAN
        );
    """,
}

# Dimension load order: each must exist before fact_sale references it.
DIMENSIONS = ["dim_accounts", "dim_products", "dim_sales_teams"]


def get_connection():
    """Return a psycopg2 connection using environment settings."""
    return connect(
        host=PG_HOST,
        port=PG_PORT,
        dbname=PG_DBNAME,
        user=PG_USER,
        password=PG_PASSWORD,
    )


def load_dimension(conn, table: str, id_col: str, natural_col: str, df: pd.DataFrame) -> dict:
    """Insert dimension rows and return {natural_key: generated_id} mapping."""
    with conn.cursor() as cur:
        cur.execute(DDL[table])
        cur.execute(f'TRUNCATE TABLE "{table}" RESTART IDENTITY CASCADE;')

        cols = list(df.columns)
        col_list = ", ".join(f'"{c}"' for c in cols)
        values = [
            tuple(None if pd.isna(v) else v for v in row)
            for row in df.itertuples(index=False)
        ]
        insert_sql = f'INSERT INTO "{table}" ({col_list}) VALUES %s'
        execute_values(cur, insert_sql, values, page_size=1000)

        # Capture generated surrogate keys mapped to their natural keys
        cur.execute(f'SELECT "{id_col}", "{natural_col}" FROM "{table}"')
        mapping = {row[1]: row[0] for row in cur.fetchall()}

    conn.commit()
    LOG.info("Loaded %d rows into %s", len(df), table)
    return mapping


def load_fact(
    conn,
    table: str,
    df: pd.DataFrame,
    mappings: dict,
) -> int:
    """Replace natural keys in the fact frame with surrogate IDs, then insert."""
    df = df.copy()

    # Map natural keys -> surrogate ids
    df["sales_agent_id"] = df["sales_agent"].map(mappings["dim_sales_teams"])
    df["product_id"] = df["product"].map(mappings["dim_products"])
    df["account_id"] = df["account"].map(mappings["dim_accounts"])

    # Surface any unmapped rows (natural key missing from its dimension)
    for col, dim in [
        ("sales_agent_id", "dim_sales_teams"),
        ("product_id", "dim_products"),
        ("account_id", "dim_accounts"),
    ]:
        n_missing = int(df[col].isnull().sum())
        if n_missing:
            LOG.warning("%s: %d rows unmapped to %s", table, n_missing, dim)

    fact_cols = [
        "opportunity_id",
        "sales_agent_id",
        "product_id",
        "account_id",
        "deal_stage",
        "engage_date",
        "close_date",
        "close_value",
        "is_won",
        "is_lost",
        "is_open",
    ]
    df = df[fact_cols]

    with conn.cursor() as cur:
        cur.execute(DDL[table])
        cur.execute(f'TRUNCATE TABLE "{table}" RESTART IDENTITY CASCADE;')

        col_list = ", ".join(f'"{c}"' for c in fact_cols)
        values = [
            tuple(None if pd.isna(v) else v for v in row)
            for row in df.itertuples(index=False)
        ]
        insert_sql = f'INSERT INTO "{table}" ({col_list}) VALUES %s'
        execute_values(cur, insert_sql, values, page_size=1000)

    conn.commit()
    LOG.info("Loaded %d rows into %s", len(df), table)
    return len(df)


def load_all(conn, frames: dict) -> dict:
    """Load dimensions first (capturing ID mappings), then fact_sale."""
    counts = {}
    mappings = {}

    # 1) Dimensions -> capture surrogate id mappings
    dim_frames = {
        "dim_accounts": ("account_id", "account"),
        "dim_products": ("product_id", "product"),
        "dim_sales_teams": ("sales_agent_id", "sales_agent"),
    }
    for table, (id_col, natural_col) in dim_frames.items():
        if table not in frames:
            LOG.warning("No data for table %s, skipping load", table)
            continue
        mappings[table] = load_dimension(conn, table, id_col, natural_col, frames[table])
        counts[table] = len(mappings[table])

    # 2) Fact -> replace natural keys with surrogate ids
    if "fact_opportunities" in frames:
        counts["fact_sale"] = load_fact(conn, "fact_sale", frames["fact_opportunities"], mappings)
    else:
        LOG.warning("No data for fact_opportunities, skipping load")

    return counts, mappings
