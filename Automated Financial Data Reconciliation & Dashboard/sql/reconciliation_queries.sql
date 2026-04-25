-- ============================================================
-- Reconciliation Analytical Queries
-- Used by Alteryx workflows and Power BI for reporting
-- ============================================================

-- ============================================================
-- 1. RECONCILIATION STATUS SUMMARY
-- ============================================================

-- Overall reconciliation rate for the current period
SELECT
    TO_CHAR(recon_date, 'YYYY-MM')          AS period,
    COUNT(*)                                AS total_records,
    COUNT(CASE WHEN match_status = 'Fully Matched'     THEN 1 END) AS fully_matched,
    COUNT(CASE WHEN match_status = 'Partially Matched' THEN 1 END) AS partially_matched,
    COUNT(CASE WHEN match_status = 'Unmatched'         THEN 1 END) AS unmatched,
    COUNT(CASE WHEN match_status = 'Exception'         THEN 1 END) AS exceptions,
    ROUND(
        COUNT(CASE WHEN match_status = 'Fully Matched' THEN 1 END)
        * 100.0 / NULLIF(COUNT(*), 0), 2
    )                                       AS reconciliation_rate_pct,
    SUM(ABS(variance_amount))               AS total_variance_value
FROM recon.fact_reconciliation_results
GROUP BY TO_CHAR(recon_date, 'YYYY-MM')
ORDER BY period DESC;

-- ============================================================
-- 2. RECONCILIATION BY DEPARTMENT
-- ============================================================

SELECT
    d.department_name,
    d.business_unit,
    COUNT(r.recon_id)                       AS total_transactions,
    COUNT(CASE WHEN r.match_status = 'Fully Matched' THEN 1 END)   AS matched,
    COUNT(CASE WHEN r.match_status = 'Unmatched'     THEN 1 END)   AS unmatched,
    COUNT(CASE WHEN r.match_status = 'Exception'     THEN 1 END)   AS exceptions,
    ROUND(
        COUNT(CASE WHEN r.match_status = 'Fully Matched' THEN 1 END)
        * 100.0 / NULLIF(COUNT(r.recon_id), 0), 2
    )                                       AS dept_recon_rate_pct,
    SUM(ABS(r.variance_amount))             AS total_variance,
    ROUND(AVG(r.match_score), 1)            AS avg_match_score
FROM recon.fact_reconciliation_results r
JOIN recon.dim_department d ON r.department_code = d.department_code
WHERE r.recon_date >= DATE_TRUNC('month', CURRENT_DATE)
GROUP BY d.department_name, d.business_unit
ORDER BY dept_recon_rate_pct ASC;

-- ============================================================
-- 3. SAP vs BANK RECONCILIATION GAPS
-- ============================================================

-- Transactions in SAP with no corresponding bank entry
SELECT
    s.transaction_id    AS sap_txn_id,
    s.transaction_date,
    s.department_code,
    s.account_code,
    s.description,
    s.amount            AS sap_amount,
    'Missing in Bank'   AS gap_type
FROM recon.fact_sap_transactions s
LEFT JOIN recon.fact_bank_statements b
    ON s.transaction_id = b.sap_reference
WHERE b.bank_ref IS NULL
  AND s.sap_status = 'Posted'
  AND s.transaction_date >= CURRENT_DATE - INTERVAL '30 days'

UNION ALL

-- Transactions in Bank with no corresponding SAP entry
SELECT
    b.bank_ref          AS sap_txn_id,
    b.value_date        AS transaction_date,
    NULL                AS department_code,
    NULL                AS account_code,
    b.description,
    (b.credit_amount - b.debit_amount) AS sap_amount,
    'Missing in SAP'    AS gap_type
FROM recon.fact_bank_statements b
LEFT JOIN recon.fact_sap_transactions s
    ON b.sap_reference = s.transaction_id
WHERE s.sap_txn_id IS NULL
  AND b.reconciliation_status = 'Unmatched'
  AND b.value_date >= CURRENT_DATE - INTERVAL '30 days'

ORDER BY transaction_date DESC;

-- ============================================================
-- 4. THREE-WAY MATCH VALIDATION (PO → GRN → INVOICE)
-- ============================================================

SELECT
    ap.invoice_id,
    v.vendor_name,
    ap.invoice_date,
    ap.purchase_order_ref,
    ap.grn_status,
    ap.total_amount,
    ap.paid_amount,
    ap.outstanding_amount,
    ap.sap_document_ref,
    CASE
        WHEN ap.po_matched = TRUE AND ap.grn_status = 'GRN-Received' AND ap.sap_matched = TRUE
            THEN 'Full 3-Way Match'
        WHEN ap.po_matched = TRUE AND ap.sap_matched = TRUE
            THEN '2-Way Match (PO+SAP)'
        WHEN ap.sap_matched = TRUE
            THEN '1-Way Match (SAP Only)'
        ELSE 'No Match'
    END                         AS match_type,
    ap.approval_status,
    ap.payment_status,
    ap.aging_bucket
FROM recon.fact_ap_invoices ap
JOIN recon.dim_vendor v ON ap.vendor_code = v.vendor_code
ORDER BY ap.invoice_date DESC;

-- ============================================================
-- 5. AP AGING REPORT (Cash Flow Impact)
-- ============================================================

SELECT
    v.vendor_name,
    v.vendor_category,
    d.department_name,
    ap.aging_bucket,
    ap.payment_terms,
    COUNT(ap.invoice_id)            AS invoice_count,
    SUM(ap.total_amount)            AS total_invoiced,
    SUM(ap.paid_amount)             AS total_paid,
    SUM(ap.outstanding_amount)      AS total_outstanding,
    MAX(ap.days_overdue)            AS max_days_overdue,
    ROUND(AVG(ap.days_overdue), 1)  AS avg_days_overdue,
    ap.payment_status
FROM recon.fact_ap_invoices ap
JOIN recon.dim_vendor     v ON ap.vendor_code     = v.vendor_code
JOIN recon.dim_department d ON ap.department_code = d.department_code
WHERE ap.outstanding_amount > 0
GROUP BY
    v.vendor_name, v.vendor_category, d.department_name,
    ap.aging_bucket, ap.payment_terms, ap.payment_status
ORDER BY SUM(ap.outstanding_amount) DESC;

-- ============================================================
-- 6. AR COLLECTIONS DASHBOARD
-- ============================================================

SELECT
    c.customer_name,
    c.customer_segment,
    ar.region,
    ar.sales_rep,
    ar.aging_bucket,
    ar.reconciliation_status,
    COUNT(ar.invoice_id)            AS invoice_count,
    SUM(ar.total_amount)            AS total_billed,
    SUM(ar.payment_received)        AS total_collected,
    SUM(ar.outstanding_balance)     AS total_outstanding,
    ROUND(
        SUM(ar.payment_received) * 100.0
        / NULLIF(SUM(ar.total_amount), 0), 2
    )                               AS collection_rate_pct
FROM recon.fact_ar_invoices ar
JOIN recon.dim_customer c ON ar.customer_code = c.customer_code
GROUP BY
    c.customer_name, c.customer_segment, ar.region,
    ar.sales_rep, ar.aging_bucket, ar.reconciliation_status
ORDER BY SUM(ar.outstanding_balance) DESC;

-- ============================================================
-- 7. BUDGET VS ACTUAL VARIANCE REPORT
-- ============================================================

SELECT
    d.department_name,
    b.quarter,
    b.fiscal_year,
    b.category,
    b.budget_amount,
    b.revised_budget,
    b.actual_spend,
    b.variance                  AS budget_variance,
    b.variance_pct,
    b.variance_label,
    b.variance_severity,
    ROUND(b.utilization_rate, 2) AS utilization_pct,
    b.status,
    b.notes
FROM recon.fact_budget b
JOIN recon.dim_department d ON b.department_code = d.department_code
ORDER BY
    b.fiscal_year,
    b.quarter,
    d.department_name,
    b.category;

-- ============================================================
-- 8. EXCEPTION SUMMARY BY TYPE
-- ============================================================

SELECT
    e.exception_type,
    e.source_system,
    e.severity,
    e.status,
    COUNT(*)                    AS exception_count,
    SUM(e.amount)               AS total_amount,
    ROUND(AVG(e.amount), 2)     AS avg_amount
FROM recon.log_exceptions e
WHERE e.exception_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY e.exception_type, e.source_system, e.severity, e.status
ORDER BY
    CASE e.severity WHEN 'High' THEN 1 WHEN 'Medium' THEN 2 ELSE 3 END,
    exception_count DESC;

-- ============================================================
-- 9. MONTH-OVER-MONTH TREND ANALYSIS
-- ============================================================

SELECT
    c.year_number                   AS year,
    c.quarter_name                  AS quarter,
    c.month_number                  AS month_num,
    c.month_name                    AS month,
    COUNT(s.sap_txn_id)             AS total_transactions,
    SUM(ABS(s.amount))              AS total_volume,
    ROUND(AVG(ABS(s.amount)), 2)    AS avg_transaction_value,
    COUNT(CASE WHEN s.sap_status = 'Error'     THEN 1 END) AS error_count,
    COUNT(CASE WHEN s.sap_status = 'Duplicate' THEN 1 END) AS duplicate_count,
    ROUND(
        COUNT(CASE WHEN s.sap_status NOT IN ('Error', 'Duplicate') THEN 1 END)
        * 100.0 / NULLIF(COUNT(s.sap_txn_id), 0), 2
    )                               AS data_quality_pct
FROM recon.fact_sap_transactions s
JOIN recon.dim_calendar c ON s.transaction_date = c.full_date
GROUP BY c.year_number, c.quarter_name, c.month_number, c.month_name
ORDER BY c.year_number, c.month_number;

-- ============================================================
-- 10. DAILY RECONCILIATION STATUS (for Power BI Line Chart)
-- ============================================================

SELECT
    r.recon_date,
    COUNT(*)                            AS daily_total,
    COUNT(CASE WHEN match_status = 'Fully Matched'  THEN 1 END) AS daily_matched,
    COUNT(CASE WHEN match_status = 'Unmatched'      THEN 1 END) AS daily_unmatched,
    COUNT(CASE WHEN match_status = 'Exception'      THEN 1 END) AS daily_exceptions,
    ROUND(
        COUNT(CASE WHEN match_status = 'Fully Matched' THEN 1 END)
        * 100.0 / NULLIF(COUNT(*), 0), 2
    )                                   AS daily_recon_rate_pct,
    SUM(ABS(variance_amount))           AS daily_variance_value
FROM recon.fact_reconciliation_results r
WHERE r.recon_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY r.recon_date
ORDER BY r.recon_date;

-- ============================================================
-- 11. TOP EXCEPTION CONTRIBUTORS (for drill-through)
-- ============================================================

SELECT
    d.department_name,
    r.exception_reason,
    r.risk_tier,
    COUNT(r.recon_id)               AS occurrence_count,
    SUM(ABS(r.variance_amount))     AS total_variance,
    MIN(r.transaction_date)         AS first_occurrence,
    MAX(r.transaction_date)         AS last_occurrence,
    COUNT(CASE WHEN r.resolution_status = 'Open' THEN 1 END)     AS open_items,
    COUNT(CASE WHEN r.resolution_status = 'Resolved' THEN 1 END) AS resolved_items
FROM recon.fact_reconciliation_results r
JOIN recon.dim_department d ON r.department_code = d.department_code
WHERE r.match_status IN ('Unmatched', 'Exception')
  AND r.recon_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY d.department_name, r.exception_reason, r.risk_tier
ORDER BY total_variance DESC;

-- ============================================================
-- 12. DATA QUALITY SCORE CARD
-- ============================================================

WITH quality_metrics AS (
    SELECT
        'SAP Transactions'                      AS data_source,
        COUNT(*)                                AS total_records,
        COUNT(CASE WHEN sap_status = 'Posted'   THEN 1 END) AS valid_records,
        COUNT(CASE WHEN sap_status = 'Error'    THEN 1 END) AS error_records,
        COUNT(CASE WHEN sap_status = 'Duplicate' THEN 1 END) AS duplicate_records
    FROM recon.fact_sap_transactions

    UNION ALL

    SELECT
        'Bank Statements',
        COUNT(*),
        COUNT(CASE WHEN reconciliation_status = 'Matched' THEN 1 END),
        0,
        COUNT(CASE WHEN reconciliation_status = 'Unmatched' THEN 1 END)
    FROM recon.fact_bank_statements

    UNION ALL

    SELECT
        'AP Invoices',
        COUNT(*),
        COUNT(CASE WHEN approval_status = 'Approved' THEN 1 END),
        COUNT(CASE WHEN approval_status IN ('Disputed', 'Not Approved') THEN 1 END),
        0
    FROM recon.fact_ap_invoices
)
SELECT
    data_source,
    total_records,
    valid_records,
    error_records,
    duplicate_records,
    ROUND(valid_records * 100.0 / NULLIF(total_records, 0), 2) AS quality_score_pct
FROM quality_metrics
ORDER BY quality_score_pct ASC;
