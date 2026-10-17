# CRM Sales Opportunities Analysis
B2B sales pipeline data from a fictitious company that sells computer hardware, including information on accounts, products, sales teams, and sales opportunities.

Source - Maven Analytics Training Dataset (CRM sales opportunities)

## Recommended Analysis

How is each sales team performing compared to the rest?

Are any sales agents lagging behind?

Can you identify any quarter-over-quarter trends?

Do any products have better win rates?

## ER Diagram
![ER Diagram](scr/ER%20diagram.png)

## Workflow
mode - ETL

raw_data -> python extract and transform -> Load to MySQL -> Tableau Dashboard