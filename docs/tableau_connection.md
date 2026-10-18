# Connecting Tableau Desktop to the migrated CRM sales data

## Prerequisites
1. PostgreSQL server running and reachable from your Tableau Desktop machine.
2. The ETL has been run at least once so tables exist in the `CRM_sale` database:
   - `dim_accounts` (PK: `account_id`)
   - `dim_products` (PK: `product_id`)
   - `dim_sales_teams` (PK: `sales_agent_id`)
   - `fact_sale` (PK: `opportunity_id`, FKs to each dimension by ID)

## Steps in Tableau Desktop

1. Open Tableau Desktop.
2. On the start page, under "Connect", select **To a Server** → **PostgreSQL**.
3. Enter the connection details matching your `.env`:
   - Server: `<PG_HOST>` (e.g., localhost)
   - Port: `<PG_PORT>` (default 5432)
   - Database: `<PG_DBNAME>` (e.g., CRM_sale)
   - Authentication: Username and Password
   - Username: `<PG_USER>`
   - Password: `<PG_PASSWORD>`
4. Click **Sign In**.
5. In the left pane, select the `public` schema, then drag tables to the canvas:
   - Start with `fact_sale`.
   - Add `dim_accounts`, `dim_products`, `dim_sales_teams`.
6. Tableau will auto-detect joins. Build relationships on the surrogate IDs:
   - `fact_sale.sales_agent_id = dim_sales_teams.sales_agent_id`
   - `fact_sale.product_id = dim_products.product_id`
   - `fact_sale.account_id = dim_accounts.account_id`
7. Go to a worksheet and build dashboards, e.g.:
   - Pipeline by deal stage (`deal_stage`)
   - Revenue by sales agent / manager / regional office (via `dim_sales_teams`)
   - Win rate by product (via `dim_products`)
   - Quarterly trends (`engage_date`, `close_date`)
8. Save the workbook (`.twb` or packaged `.twbx`).

## Notes
- Use a **live connection** to PostgreSQL so dashboards reflect the migrated data.
- If you re-run the ETL (truncate + reload), refresh the Tableau data source (Data → Refresh) to pick up changes.
- For extract-based performance on large volumes, use Tableau Extract instead of live, then schedule refreshes (Tableau Server/Cloud only).
