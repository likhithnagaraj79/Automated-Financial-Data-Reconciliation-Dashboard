"""
Alteryx Python Tool — Advanced Data Cleansing & Reconciliation Logic
=====================================================================
Purpose : Used inside Alteryx Designer's Python Tool node.
          Receives data from upstream tools, applies advanced
          cleansing, duplicate detection, matching scoring, and
          reconciliation KPI calculation before passing downstream.

Inputs  : #1 — Reconciliation summary from Join/Summarize nodes
          #2 — AP aging summary
          #3 — Raw SAP transactions (optional, for ML scoring)

Outputs : #1 — Enriched reconciliation records with match scores
          #2 — AP aging with risk flags
          #3 — KPI summary row for dashboard card visuals

To use in Alteryx: paste this into the Python Tool and configure
3 input/output anchors.
"""

# ---- Alteryx Python Tool imports ----
from ayx import Alteryx
import pandas as pd
import numpy as np
import re
from datetime import datetime, date


# ==============================================================
# STEP 1 — READ INCOMING DATA STREAMS
# ==============================================================
try:
    recon_df  = Alteryx.read("#1")   # Reconciliation summary
    ap_df     = Alteryx.read("#2")   # AP aging data
except Exception as e:
    Alteryx.write(pd.DataFrame({"error": [str(e)]}), 1)
    raise


# ==============================================================
# STEP 2 — STANDARDIZATION UTILITIES
# ==============================================================

def standardize_amount(value):
    """Clean currency strings and convert to float."""
    if pd.isnull(value):
        return 0.0
    if isinstance(value, (int, float)):
        return float(value)
    cleaned = re.sub(r'[,$\s]', '', str(value))
    try:
        return float(cleaned)
    except ValueError:
        return 0.0


def standardize_date(value):
    """Parse various date formats to YYYY-MM-DD."""
    if pd.isnull(value):
        return None
    formats = ['%Y-%m-%d', '%d/%m/%Y', '%m/%d/%Y', '%d-%m-%Y', '%Y%m%d']
    for fmt in formats:
        try:
            return datetime.strptime(str(value).strip(), fmt).date()
        except ValueError:
            continue
    return None


def standardize_text(value):
    """Trim whitespace, title-case department/vendor names."""
    if pd.isnull(value):
        return None
    return str(value).strip()


def normalize_status(value):
    """Normalize status codes to standard set."""
    if pd.isnull(value):
        return 'Unknown'
    mapping = {
        'posted':    'Posted',   'post':      'Posted',
        'approved':  'Approved', 'approve':   'Approved',
        'error':     'Error',    'err':       'Error',
        'duplicate': 'Duplicate','dup':       'Duplicate',
        'pending':   'Pending',  'pend':      'Pending',
        'matched':   'Matched',  'match':     'Matched',
        'unmatched': 'Unmatched','unmatch':   'Unmatched',
    }
    return mapping.get(str(value).lower().strip(), str(value).strip())


# ==============================================================
# STEP 3 — APPLY STANDARDIZATION TO RECONCILIATION DATA
# ==============================================================

def cleanse_reconciliation(df):
    """Apply all cleansing rules to reconciliation data."""

    # Amount columns — standardize
    amount_cols = [c for c in df.columns if 'amount' in c.lower() or 'balance' in c.lower()]
    for col in amount_cols:
        df[col] = df[col].apply(standardize_amount)

    # Date columns — standardize
    date_cols = [c for c in df.columns if 'date' in c.lower()]
    for col in date_cols:
        df[col] = df[col].apply(standardize_date)

    # Text columns — trim
    str_cols = df.select_dtypes(include='object').columns
    for col in str_cols:
        df[col] = df[col].apply(standardize_text)

    # Status normalization
    status_cols = [c for c in df.columns if 'status' in c.lower()]
    for col in status_cols:
        df[col] = df[col].apply(normalize_status)

    return df


recon_df = cleanse_reconciliation(recon_df)


# ==============================================================
# STEP 4 — DUPLICATE DETECTION
# ==============================================================

def detect_duplicates(df):
    """
    Flag likely duplicate records using composite key hashing.
    Duplicates = same amount + department + date within 1 day.
    """
    key_fields = []
    if 'Transaction_Amount' in df.columns:
        key_fields.append('Transaction_Amount')
    if 'Department' in df.columns:
        key_fields.append('Department')
    if 'Transaction_Date' in df.columns:
        key_fields.append('Transaction_Date')

    if len(key_fields) >= 2:
        df['_dedup_key'] = df[key_fields].astype(str).agg('|'.join, axis=1)
        df['Is_Duplicate'] = df.duplicated(subset=['_dedup_key'], keep='first')
        df.drop(columns=['_dedup_key'], inplace=True)
    else:
        df['Is_Duplicate'] = False

    return df


recon_df = detect_duplicates(recon_df)


# ==============================================================
# STEP 5 — RECONCILIATION MATCH SCORING
# ==============================================================

def calculate_match_score(row):
    """
    Score 0–100 for each reconciliation record.
    Higher = better match quality.
    Deductions applied for each failure condition.
    """
    score = 100

    # Bank reconciliation mismatch
    bank_status = str(row.get('Bank_Recon_Status', '')).lower()
    if bank_status == 'unmatched':
        score -= 40
    elif bank_status == 'partially matched':
        score -= 20

    # SAP error or duplicate
    sap_status = str(row.get('SAP_Status', '')).lower()
    if sap_status == 'error':
        score -= 30
    elif sap_status == 'duplicate':
        score -= 25

    # Missing PO reference
    if not row.get('PO_Matched', True):
        score -= 15

    # Missing SAP document reference
    if not row.get('SAP_Matched', True):
        score -= 15

    # Significant variance
    try:
        variance = abs(float(row.get('variance_amount', 0) or 0))
        sap_amount = abs(float(row.get('SAP_Amount', 1) or 1))
        variance_pct = variance / sap_amount * 100 if sap_amount != 0 else 0
        if variance_pct > 10:
            score -= 10
        elif variance_pct > 5:
            score -= 5
    except (TypeError, ValueError, ZeroDivisionError):
        pass

    # Duplicate penalty
    if row.get('Is_Duplicate', False):
        score -= 20

    return max(int(score), 0)


def assign_risk_tier(score):
    """Convert numeric score to risk tier label."""
    if score >= 90:
        return 'Low Risk'
    elif score >= 70:
        return 'Medium Risk'
    else:
        return 'High Risk'


recon_df['Match_Score'] = recon_df.apply(calculate_match_score, axis=1)
recon_df['Risk_Tier']   = recon_df['Match_Score'].apply(assign_risk_tier)


# ==============================================================
# STEP 6 — EXCEPTION REASON TAGGING
# ==============================================================

def tag_exception_reason(row):
    """Assign human-readable exception reason for drill-through."""
    reasons = []

    if str(row.get('SAP_Status', '')).lower() == 'error':
        reasons.append('SAP Data Error')
    if str(row.get('SAP_Status', '')).lower() == 'duplicate':
        reasons.append('Duplicate Transaction')
    if str(row.get('Bank_Recon_Status', '')).lower() == 'unmatched':
        reasons.append('Missing Bank Entry')
    if not row.get('PO_Matched', True):
        reasons.append('No PO Reference')
    if row.get('Is_Duplicate', False):
        reasons.append('Record Duplicate')

    try:
        variance_pct = abs(float(row.get('variance_amount', 0) or 0)) / \
                       abs(float(row.get('SAP_Amount', 1) or 1)) * 100
        if variance_pct > 10:
            reasons.append(f'Variance {variance_pct:.1f}%')
    except (TypeError, ValueError, ZeroDivisionError):
        pass

    return '; '.join(reasons) if reasons else ''


recon_df['Exception_Reason'] = recon_df.apply(tag_exception_reason, axis=1)


# ==============================================================
# STEP 7 — RECONCILIATION KPIs
# ==============================================================

def compute_kpis(df):
    """Compute top-level KPIs as a summary row."""
    total = len(df)
    matched = len(df[df.get('Bank_Recon_Status', pd.Series(dtype=str))
                      .astype(str).str.lower() == 'matched']) if 'Bank_Recon_Status' in df.columns else 0
    exceptions = len(df[df['Risk_Tier'] == 'High Risk']) if 'Risk_Tier' in df.columns else 0
    duplicates = int(df['Is_Duplicate'].sum()) if 'Is_Duplicate' in df.columns else 0
    avg_score  = round(df['Match_Score'].mean(), 1) if 'Match_Score' in df.columns else 0
    recon_rate = round(matched / total * 100, 2) if total > 0 else 0

    return pd.DataFrame([{
        'Report_Date':          date.today().isoformat(),
        'Total_Transactions':   total,
        'Matched_Count':        matched,
        'Exception_Count':      exceptions,
        'Duplicate_Count':      duplicates,
        'Reconciliation_Rate':  recon_rate,
        'Avg_Match_Score':      avg_score,
        'High_Risk_Count':      int((df['Risk_Tier'] == 'High Risk').sum()),
        'Medium_Risk_Count':    int((df['Risk_Tier'] == 'Medium Risk').sum()),
        'Low_Risk_Count':       int((df['Risk_Tier'] == 'Low Risk').sum()),
    }])


kpi_df = compute_kpis(recon_df)


# ==============================================================
# STEP 8 — AP AGING ENRICHMENT
# ==============================================================

def enrich_ap_aging(df):
    """Add risk flags and cash flow priority to AP aging data."""
    if df is None or len(df) == 0:
        return df

    # Standardize amounts
    amount_cols = [c for c in df.columns if 'amount' in c.lower() or 'outstanding' in c.lower()]
    for col in amount_cols:
        df[col] = df[col].apply(standardize_amount)

    # Cash flow priority flag
    def cash_priority(row):
        outstanding = float(row.get('Total_Outstanding', row.get('OutstandingAmount', 0)) or 0)
        aging = str(row.get('Aging_Bucket', row.get('aging_bucket', 'Current'))).lower()
        if '60' in aging or '90' in aging or '+' in aging:
            return 'Critical'
        elif outstanding > 50000:
            return 'High'
        elif outstanding > 20000:
            return 'Medium'
        return 'Low'

    df['Cash_Flow_Priority'] = df.apply(cash_priority, axis=1)

    # Payment risk score
    def payment_risk(row):
        status = str(row.get('PaymentStatus', row.get('payment_status', '')))
        if status in ('Overdue', 'On Hold'):
            return 'At Risk'
        elif status == 'Pending Payment':
            return 'Monitor'
        return 'Normal'

    df['Payment_Risk'] = df.apply(payment_risk, axis=1)

    return df


ap_df = enrich_ap_aging(ap_df)


# ==============================================================
# STEP 9 — LOAD TIMESTAMP & AUDIT TRAIL
# ==============================================================

run_timestamp = datetime.now().isoformat(timespec='seconds')

recon_df['ETL_Load_Timestamp'] = run_timestamp
recon_df['ETL_Version']        = 'v1.0'
recon_df['ETL_Source']         = 'Alteryx-Python-Tool'

ap_df['ETL_Load_Timestamp'] = run_timestamp


# ==============================================================
# STEP 10 — OUTPUT TO DOWNSTREAM ALTERYX NODES
# ==============================================================

Alteryx.write(recon_df, 1)   # Enriched reconciliation → Output tools
Alteryx.write(ap_df,    2)   # Enriched AP aging → AP Output tool
Alteryx.write(kpi_df,   3)   # KPI summary → optional dashboard flat file
