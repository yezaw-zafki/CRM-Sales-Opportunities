-- CRM Sales target schema with surrogate (auto-increment) primary keys
-- Dimension tables use their own generated IDs; fact_sale connects only by ID.

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

CREATE TABLE IF NOT EXISTS dim_products (
    product_id SERIAL PRIMARY KEY,
    product TEXT UNIQUE NOT NULL,
    series TEXT,
    sales_price NUMERIC
);

CREATE TABLE IF NOT EXISTS dim_sales_teams (
    sales_agent_id SERIAL PRIMARY KEY,
    sales_agent TEXT UNIQUE NOT NULL,
    manager TEXT,
    regional_office TEXT
);

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

-- Indexes to support Tableau dashboard queries
CREATE INDEX IF NOT EXISTS idx_fact_sale_agent ON fact_sale(sales_agent_id);
CREATE INDEX IF NOT EXISTS idx_fact_sale_product ON fact_sale(product_id);
CREATE INDEX IF NOT EXISTS idx_fact_sale_account ON fact_sale(account_id);
CREATE INDEX IF NOT EXISTS idx_fact_sale_stage ON fact_sale(deal_stage);
CREATE INDEX IF NOT EXISTS idx_fact_sale_engage_date ON fact_sale(engage_date);
CREATE INDEX IF NOT EXISTS idx_fact_sale_close_date ON fact_sale(close_date);
