-- ============================================================
-- Database: financial_reconciliation
-- Purpose : Store processed, reconciled financial data for
--           reporting and Power BI direct query
-- Author  : Financial Analytics Team
-- Version : 1.0
-- ============================================================

-- ============================================================
-- SCHEMA CREATION
-- ============================================================
CREATE SCHEMA IF NOT EXISTS recon;

-- ============================================================
-- DIMENSION TABLES
-- ============================================================

-- Departments master
CREATE TABLE recon.dim_department (
    department_id       SERIAL PRIMARY KEY,
    department_code     VARCHAR(20)  NOT NULL UNIQUE,
    department_name     VARCHAR(100) NOT NULL,
    cost_center         VARCHAR(20),
    department_head     VARCHAR(100),
    business_unit       VARCHAR(50),
    is_active           BOOLEAN DEFAULT TRUE,
    created_date        TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Chart of Accounts
CREATE TABLE recon.dim_account (
    account_id          SERIAL PRIMARY KEY,
    account_code        VARCHAR(20)  NOT NULL UNIQUE,
    account_name        VARCHAR(150) NOT NULL,
    account_type        VARCHAR(50)  NOT NULL,   -- Asset, Liability, Equity, Revenue, Expense
    account_category    VARCHAR(100),
    normal_balance      VARCHAR(10)  NOT NULL,    -- Debit / Credit
    is_reconcilable     BOOLEAN DEFAULT TRUE,
    is_active           BOOLEAN DEFAULT TRUE,
    created_date        TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Vendors master
CREATE TABLE recon.dim_vendor (
    vendor_id           SERIAL PRIMARY KEY,
    vendor_code         VARCHAR(20)  NOT NULL UNIQUE,
    vendor_name         VARCHAR(200) NOT NULL,
    vendor_category     VARCHAR(100),
    payment_terms       VARCHAR(20),
    bank_account_no     VARCHAR(50),
    tax_id              VARCHAR(50),
    country             VARCHAR(50)  DEFAULT 'US',
    is_active           BOOLEAN DEFAULT TRUE,
    created_date        TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Customers master
CREATE TABLE recon.dim_customer (
    customer_id         SERIAL PRIMARY KEY,
    customer_code       VARCHAR(20)  NOT NULL UNIQUE,
    customer_name       VARCHAR(200) NOT NULL,
    customer_segment    VARCHAR(50),
    region              VARCHAR(50),
    credit_limit        DECIMAL(18,2),
    payment_terms       VARCHAR(20),
    account_manager     VARCHAR(100),
    is_active           BOOLEAN DEFAULT TRUE,
    created_date        TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Calendar dimension
CREATE TABLE recon.dim_calendar (
    date_key            INTEGER      PRIMARY KEY,   -- YYYYMMDD
    full_date           DATE         NOT NULL,
    year_number         SMALLINT     NOT NULL,
    quarter_number      SMALLINT     NOT NULL,
    quarter_name        VARCHAR(2)   NOT NULL,      -- Q1, Q2, Q3, Q4
    month_number        SMALLINT     NOT NULL,
    month_name          VARCHAR(20)  NOT NULL,
    week_number         SMALLINT     NOT NULL,
    day_of_week         SMALLINT     NOT NULL,
    day_name            VARCHAR(20)  NOT NULL,
    is_weekend          BOOLEAN      NOT NULL,
    is_holiday          BOOLEAN      DEFAULT FALSE,
    fiscal_year         SMALLINT     NOT NULL,
    fiscal_period       SMALLINT     NOT NULL,
    fiscal_quarter      VARCHAR(5)   NOT NULL
);

-- ============================================================
-- FACT TABLES
-- ============================================================

-- SAP Transactions
CREATE TABLE recon.fact_sap_transactions (
    sap_txn_id          SERIAL PRIMARY KEY,
    transaction_id      VARCHAR(30)  NOT NULL UNIQUE,
    transaction_date    DATE         NOT NULL,
    date_key            INTEGER      REFERENCES recon.dim_calendar(date_key),
    department_code     VARCHAR(20)  REFERENCES recon.dim_department(department_code),
    account_code        VARCHAR(20)  REFERENCES recon.dim_account(account_code),
    description         VARCHAR(500),
    amount              DECIMAL(18,2) NOT NULL,
    abs_amount          DECIMAL(18,2) GENERATED ALWAYS AS (ABS(amount)) STORED,
    currency            VARCHAR(3)   DEFAULT 'USD',
    cost_center         VARCHAR(20),
    document_type       VARCHAR(10),
    posting_key         VARCHAR(10),
    sap_status          VARCHAR(20)  NOT NULL,
    created_by          VARCHAR(100),
    source_system       VARCHAR(10)  DEFAULT 'SAP',
    load_timestamp      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- Bank Statements
CREATE TABLE recon.fact_bank_statements (
    bank_stmt_id        SERIAL PRIMARY KEY,
    bank_ref            VARCHAR(50)  NOT NULL UNIQUE,
    value_date          DATE         NOT NULL,
    transaction_date    DATE,
    date_key            INTEGER      REFERENCES recon.dim_calendar(date_key),
    description         VARCHAR(500),
    debit_amount        DECIMAL(18,2) DEFAULT 0.00,
    credit_amount       DECIMAL(18,2) DEFAULT 0.00,
    net_amount          DECIMAL(18,2) GENERATED ALWAYS AS (credit_amount - debit_amount) STORED,
    running_balance     DECIMAL(18,2),
    bank_code           VARCHAR(20),
    account_number      VARCHAR(50),
    transaction_type    VARCHAR(20),
    sap_reference       VARCHAR(50),
    counterparty        VARCHAR(200),
    reconciliation_status VARCHAR(20) DEFAULT 'Unmatched',
    load_timestamp      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- Manual Journal Entries
CREATE TABLE recon.fact_journal_entries (
    journal_id_pk       SERIAL PRIMARY KEY,
    journal_id          VARCHAR(30)  NOT NULL UNIQUE,
    entry_date          DATE         NOT NULL,
    date_key            INTEGER      REFERENCES recon.dim_calendar(date_key),
    period              SMALLINT,
    fiscal_year         SMALLINT,
    department_code     VARCHAR(20)  REFERENCES recon.dim_department(department_code),
    account_code        VARCHAR(20)  REFERENCES recon.dim_account(account_code),
    description         VARCHAR(500),
    debit_amount        DECIMAL(18,2) DEFAULT 0.00,
    credit_amount       DECIMAL(18,2) DEFAULT 0.00,
    currency            VARCHAR(3)   DEFAULT 'USD',
    reference           VARCHAR(100),
    prepared_by         VARCHAR(100),
    approved_by         VARCHAR(100),
    status              VARCHAR(20)  NOT NULL,
    posting_date        DATE,
    load_timestamp      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- Accounts Payable Invoices
CREATE TABLE recon.fact_ap_invoices (
    ap_id               SERIAL PRIMARY KEY,
    invoice_id          VARCHAR(30)  NOT NULL UNIQUE,
    vendor_code         VARCHAR(20)  REFERENCES recon.dim_vendor(vendor_code),
    invoice_date        DATE         NOT NULL,
    invoice_received_date DATE,
    due_date            DATE,
    date_key            INTEGER      REFERENCES recon.dim_calendar(date_key),
    invoice_amount      DECIMAL(18,2) NOT NULL,
    tax_amount          DECIMAL(18,2) DEFAULT 0.00,
    total_amount        DECIMAL(18,2) NOT NULL,
    paid_amount         DECIMAL(18,2) DEFAULT 0.00,
    outstanding_amount  DECIMAL(18,2),
    currency            VARCHAR(3)   DEFAULT 'USD',
    payment_terms       VARCHAR(20),
    purchase_order_ref  VARCHAR(50),
    department_code     VARCHAR(20)  REFERENCES recon.dim_department(department_code),
    cost_center         VARCHAR(20),
    approval_status     VARCHAR(30)  NOT NULL,
    payment_status      VARCHAR(30)  NOT NULL,
    grn_status          VARCHAR(20),
    sap_document_ref    VARCHAR(30),
    days_overdue        INTEGER      DEFAULT 0,
    aging_bucket        VARCHAR(20),
    po_matched          BOOLEAN      DEFAULT FALSE,
    sap_matched         BOOLEAN      DEFAULT FALSE,
    notes               VARCHAR(500),
    load_timestamp      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- Accounts Receivable Invoices
CREATE TABLE recon.fact_ar_invoices (
    ar_id               SERIAL PRIMARY KEY,
    invoice_id          VARCHAR(30)  NOT NULL UNIQUE,
    customer_code       VARCHAR(20)  REFERENCES recon.dim_customer(customer_code),
    invoice_date        DATE         NOT NULL,
    due_date            DATE,
    date_key            INTEGER      REFERENCES recon.dim_calendar(date_key),
    invoice_amount      DECIMAL(18,2) NOT NULL,
    total_amount        DECIMAL(18,2) NOT NULL,
    payment_received    DECIMAL(18,2) DEFAULT 0.00,
    outstanding_balance DECIMAL(18,2),
    currency            VARCHAR(3)   DEFAULT 'USD',
    payment_terms       VARCHAR(20),
    sales_rep           VARCHAR(100),
    department_code     VARCHAR(20)  REFERENCES recon.dim_department(department_code),
    region              VARCHAR(50),
    reconciliation_status VARCHAR(30) NOT NULL,
    sap_document_ref    VARCHAR(30),
    collection_notes    VARCHAR(500),
    days_outstanding    INTEGER,
    aging_bucket        VARCHAR(20),
    load_timestamp      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- Budget Allocations
CREATE TABLE recon.fact_budget (
    budget_id_pk        SERIAL PRIMARY KEY,
    budget_id           VARCHAR(50)  NOT NULL UNIQUE,
    fiscal_year         SMALLINT     NOT NULL,
    quarter             VARCHAR(5)   NOT NULL,
    period              SMALLINT,
    department_code     VARCHAR(20)  REFERENCES recon.dim_department(department_code),
    cost_center         VARCHAR(20),
    category            VARCHAR(100) NOT NULL,
    budget_amount       DECIMAL(18,2) NOT NULL,
    revised_budget      DECIMAL(18,2),
    actual_spend        DECIMAL(18,2) DEFAULT 0.00,
    variance            DECIMAL(18,2),
    variance_pct        DECIMAL(8,2),
    variance_label      VARCHAR(20),
    variance_severity   VARCHAR(10),
    utilization_rate    DECIMAL(8,2),
    currency            VARCHAR(3)   DEFAULT 'USD',
    approved_by         VARCHAR(100),
    status              VARCHAR(20),
    notes               VARCHAR(500),
    load_timestamp      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- RECONCILIATION RESULT TABLE
-- ============================================================

CREATE TABLE recon.fact_reconciliation_results (
    recon_id            SERIAL PRIMARY KEY,
    recon_date          DATE         NOT NULL DEFAULT CURRENT_DATE,
    sap_transaction_id  VARCHAR(30),
    bank_reference      VARCHAR(50),
    journal_id          VARCHAR(30),
    ap_invoice_id       VARCHAR(30),
    transaction_date    DATE,
    department_code     VARCHAR(20)  REFERENCES recon.dim_department(department_code),
    account_code        VARCHAR(20),
    sap_amount          DECIMAL(18,2),
    bank_amount         DECIMAL(18,2),
    variance_amount     DECIMAL(18,2) GENERATED ALWAYS AS (COALESCE(sap_amount, 0) - COALESCE(bank_amount, 0)) STORED,
    match_status        VARCHAR(30)  NOT NULL,   -- Fully Matched, Partially Matched, Unmatched, Exception
    match_score         SMALLINT,                -- 0–100
    risk_tier           VARCHAR(20),             -- Low Risk, Medium Risk, High Risk
    exception_reason    VARCHAR(200),
    is_duplicate        BOOLEAN      DEFAULT FALSE,
    reviewed_by         VARCHAR(100),
    review_date         DATE,
    resolution_status   VARCHAR(30)  DEFAULT 'Open',  -- Open, In Review, Resolved, Escalated
    resolution_notes    VARCHAR(500),
    load_timestamp      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- EXCEPTION LOG TABLE
-- ============================================================

CREATE TABLE recon.log_exceptions (
    exception_id        SERIAL PRIMARY KEY,
    exception_date      DATE         NOT NULL DEFAULT CURRENT_DATE,
    exception_type      VARCHAR(50)  NOT NULL,   -- Missing Dept, Duplicate, Unmatched, Overdue, Budget Exceeded
    source_system       VARCHAR(20)  NOT NULL,
    source_record_id    VARCHAR(50),
    department_code     VARCHAR(20),
    amount              DECIMAL(18,2),
    description         VARCHAR(500),
    severity            VARCHAR(10)  NOT NULL,   -- High, Medium, Low
    assigned_to         VARCHAR(100),
    status              VARCHAR(20)  DEFAULT 'Open',
    resolved_date       DATE,
    resolution_notes    VARCHAR(500),
    workflow_run_id     VARCHAR(50),
    load_timestamp      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX idx_sap_txn_date         ON recon.fact_sap_transactions(transaction_date);
CREATE INDEX idx_sap_txn_dept         ON recon.fact_sap_transactions(department_code);
CREATE INDEX idx_sap_txn_status       ON recon.fact_sap_transactions(sap_status);
CREATE INDEX idx_bank_value_date      ON recon.fact_bank_statements(value_date);
CREATE INDEX idx_bank_recon_status    ON recon.fact_bank_statements(reconciliation_status);
CREATE INDEX idx_ap_due_date          ON recon.fact_ap_invoices(due_date);
CREATE INDEX idx_ap_payment_status    ON recon.fact_ap_invoices(payment_status);
CREATE INDEX idx_ar_due_date          ON recon.fact_ar_invoices(due_date);
CREATE INDEX idx_ar_recon_status      ON recon.fact_ar_invoices(reconciliation_status);
CREATE INDEX idx_recon_match_status   ON recon.fact_reconciliation_results(match_status);
CREATE INDEX idx_recon_risk_tier      ON recon.fact_reconciliation_results(risk_tier);
CREATE INDEX idx_exception_type       ON recon.log_exceptions(exception_type);
CREATE INDEX idx_exception_severity   ON recon.log_exceptions(severity);

-- ============================================================
-- VIEWS FOR POWER BI
-- ============================================================

-- v_reconciliation_dashboard: Main Power BI data source
CREATE OR REPLACE VIEW recon.v_reconciliation_dashboard AS
SELECT
    r.recon_id,
    r.recon_date,
    r.sap_transaction_id,
    r.bank_reference,
    r.transaction_date,
    c.year_number                       AS txn_year,
    c.quarter_name                      AS txn_quarter,
    c.month_name                        AS txn_month,
    d.department_name,
    d.business_unit,
    acc.account_name,
    acc.account_type,
    r.sap_amount,
    r.bank_amount,
    r.variance_amount,
    ABS(r.variance_amount)              AS abs_variance,
    r.match_status,
    r.match_score,
    r.risk_tier,
    r.exception_reason,
    r.is_duplicate,
    r.resolution_status
FROM recon.fact_reconciliation_results r
LEFT JOIN recon.dim_calendar    c   ON r.transaction_date = c.full_date
LEFT JOIN recon.dim_department  d   ON r.department_code   = d.department_code
LEFT JOIN recon.dim_account     acc ON r.account_code      = acc.account_code;

-- v_kpi_summary: KPI cards for Power BI
CREATE OR REPLACE VIEW recon.v_kpi_summary AS
SELECT
    COUNT(*)                                                    AS total_transactions,
    COUNT(CASE WHEN match_status = 'Fully Matched' THEN 1 END) AS matched_count,
    COUNT(CASE WHEN match_status = 'Unmatched'     THEN 1 END) AS unmatched_count,
    COUNT(CASE WHEN match_status = 'Exception'     THEN 1 END) AS exception_count,
    ROUND(
        COUNT(CASE WHEN match_status = 'Fully Matched' THEN 1 END) * 100.0
        / NULLIF(COUNT(*), 0), 2
    )                                                           AS reconciliation_rate_pct,
    SUM(ABS(variance_amount))                                   AS total_variance_amount,
    ROUND(AVG(match_score), 1)                                  AS avg_match_score
FROM recon.fact_reconciliation_results
WHERE recon_date = CURRENT_DATE;

-- v_ap_aging_summary: AP aging for Power BI
CREATE OR REPLACE VIEW recon.v_ap_aging_summary AS
SELECT
    d.department_name,
    ap.aging_bucket,
    ap.payment_status,
    COUNT(ap.invoice_id)                AS invoice_count,
    SUM(ap.total_amount)                AS total_invoiced,
    SUM(ap.outstanding_amount)          AS total_outstanding,
    SUM(ap.paid_amount)                 AS total_paid,
    ROUND(AVG(ap.days_overdue), 1)      AS avg_days_overdue
FROM recon.fact_ap_invoices ap
LEFT JOIN recon.dim_department d ON ap.department_code = d.department_code
GROUP BY d.department_name, ap.aging_bucket, ap.payment_status;

-- v_budget_vs_actual: Budget variance for Power BI
CREATE OR REPLACE VIEW recon.v_budget_vs_actual AS
SELECT
    d.department_name,
    b.quarter,
    b.fiscal_year,
    b.category,
    b.budget_amount,
    b.revised_budget,
    b.actual_spend,
    b.variance,
    b.variance_pct,
    b.variance_label,
    b.variance_severity,
    b.utilization_rate
FROM recon.fact_budget b
LEFT JOIN recon.dim_department d ON b.department_code = d.department_code;

-- v_exception_summary: Exception dashboard for Power BI
CREATE OR REPLACE VIEW recon.v_exception_summary AS
SELECT
    exception_type,
    source_system,
    severity,
    status,
    COUNT(*)                            AS exception_count,
    SUM(amount)                         AS total_amount,
    MIN(exception_date)                 AS earliest_date,
    MAX(exception_date)                 AS latest_date
FROM recon.log_exceptions
GROUP BY exception_type, source_system, severity, status;
