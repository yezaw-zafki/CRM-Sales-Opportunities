"""Extract stage: read CRM source files into pandas DataFrames."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from .config import DATA_DIR, SOURCE_FILES

LOG = logging.getLogger("crm_etl.extract")


def normalize_columns(df: pd.DataFrame) -> pd.DataFrame:
    """Lowercase, strip, and snake_case column names."""
    df = df.copy()
    df.columns = (
        df.columns
        .astype(str)
        .str.strip()
        .str.lower()
        .str.replace(r"[^a-z0-9]+", "_", regex=True)
        .str.strip("_")
    )
    return df


def extract_file(path: Path) -> pd.DataFrame:
    """Read a single CSV or Excel file into a DataFrame."""
    suffix = path.suffix.lower()
    if suffix == ".csv":
        df = pd.read_csv(path)
    elif suffix in {".xlsx", ".xls"}:
        df = pd.read_excel(path)
    elif suffix == ".numbers":
        raise ValueError(
            f".numbers files are not supported by pandas: {path}. "
            "Export to CSV or Excel first."
        )
    else:
        raise ValueError(f"Unsupported file type: {path}")
    return normalize_columns(df)


def extract_all(data_dir: Path = DATA_DIR) -> dict[str, pd.DataFrame]:
    """Extract every configured source file into a dict of DataFrames."""
    frames: dict[str, pd.DataFrame] = {}
    for filename, table in SOURCE_FILES.items():
        path = data_dir / filename
        if not path.exists():
            LOG.warning("Source file not found, skipping: %s", path)
            continue
        df = extract_file(path)
        LOG.info(
            "Extracted %s -> %s (%d rows, %d cols)",
            filename,
            table,
            *df.shape,
        )
        frames[table] = df
    return frames
