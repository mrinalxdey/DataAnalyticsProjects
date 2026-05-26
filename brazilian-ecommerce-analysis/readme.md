# Brazilian Ecommerce Analysis

An end-to-end SQL analytics project built using the Olist Brazilian E-Commerce dataset from Kaggle.  
This project focuses on data cleaning, transformation, warehouse modeling, and analytical querying using PostgreSQL.

---

## Project Overview

The goal of this project was to simulate a real-world analytics workflow by:

- Importing raw ecommerce datasets into PostgreSQL
- Cleaning and validating transactional data
- Building structured staging and analytics layers
- Writing advanced SQL queries for business insights
- Performing customer, revenue, product, and seasonal analysis

The project follows a layered architecture:

```text
Raw Layer → Staging Layer → Analytics Layer
```

---

## Dataset

Dataset used: Olist Brazilian E-Commerce Dataset

The dataset contains information about:

- Customers
- Orders
- Order Items
- Payments
- Products
- Sellers
- Reviews
- Geolocation data
- Product categories

---

## Tech Stack

- MS Excel (Power Query and Data Model)
- PostgreSQL
- pgAdmin
- SQL
- Kaggle Dataset

---

## Database Architecture

### Raw Schema
Contains original imported CSV data without modifications.

### Staging Schema
Contains cleaned and standardized data:
- NULL handling
- Deduplication
- Data type corrections
- Foreign key validation
- Timestamp parsing
- Orphan record checks

### Analytics Schema
Contains transformed business-ready tables for reporting and analysis.

---

## Data Cleaning Performed

Some of the cleaning and validation steps included:

- Removing duplicate customer records
- Handling NULL and invalid timestamps
- Resolving orphan foreign keys
- Standardizing geolocation data
- Fixing missing product categories
- Detecting invalid payment/installment values
- Filtering invalid order states
- Deduplicating ZIP code records

---

## Analytical SQL Queries

The project includes advanced analytical SQL queries such as:

### Customer Analytics
- Customer Lifetime Value (CLV)
- Customer segmentation (Bronze / Silver / Gold)
- Customers with no purchases
- Conversion funnel leakage analysis

### Revenue Analytics
- Monthly revenue trends
- Month-over-Month (MoM) growth
- Daily/Weekly/Monthly sales rollups
- Seasonal sales analysis

### Product Analytics
- Top-selling products by category
- Category-wise revenue rankings
- Seasonal product demand patterns

### Data Quality & Fraud Detection
- Orphan record detection
- Payment vs order total mismatch analysis
- Duplicate customer detection

---

## SQL Concepts Demonstrated

This project demonstrates:

- CTEs
- Window Functions
- RANK() / DENSE_RANK()
- NTILE()
- ROLLUP / CUBE
- Transactions
- CASE Statements
- Aggregate Functions
- Percentile Calculations
- Multi-table JOINs
- Data Validation Queries

---

## Sample Business Questions Answered

- Which product categories perform best seasonally?
- Which customers generate the highest lifetime value?
- Are there mismatches between payments and order totals?
- How does revenue change month-over-month?
- Which customers registered but never purchased?

---

## Project Structure


## Repository Contents

| Section | Description |
|---|---|
| [Queries](./Queries) | Cleaning, transformation, and analytics queries |
| [ERD](./ERD) | Database schema diagrams |
| [Documentation](./Documentation) | Project presentation deck |

---

## Key Learnings

This project helped strengthen understanding of:

- Relational database design
- Data cleaning workflows
- Analytical SQL
- Business intelligence reporting
- Data warehouse concepts
- Query optimization and aggregation logic

---

## Future Improvements

Potential future enhancements:

- Power BI / Tableau dashboard integration
- Materialized views
- Automated ETL pipeline
- Time-series forecasting

---

## Author

Mrinal Dey
