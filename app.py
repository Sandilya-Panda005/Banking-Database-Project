"""
Pawnee Trust & Ledger — Live Dashboard
Connects directly to your MySQL BankSystem database.
Run with:  streamlit run app.py
"""

import streamlit as st
import pandas as pd
import mysql.connector
from mysql.connector import Error

# ============================================================
# DATABASE CONNECTION
# ============================================================
# Edit these to match your MySQL Workbench connection settings.
DB_CONFIG = {
    "host": "localhost",
    "port": 3306,
    "user": "root",
    "password": "monamoon",   # <-- change this
    "database": "BankSystem",
}


def get_connection():
    try:
        return mysql.connector.connect(**DB_CONFIG)
    except Error as e:
        st.error(f"Could not connect to MySQL: {e}")
        st.stop()


def run_query(query, params=None):
    conn = get_connection()
    try:
        df = pd.read_sql(query, conn, params=params)
    finally:
        conn.close()
    return df


def run_procedure(proc_name, args):
    """Calls a stored procedure and returns its result set (if any)."""
    conn = get_connection()
    try:
        cursor = conn.cursor()
        cursor.callproc(proc_name, args)
        result = None
        for res in cursor.stored_results():
            result = res.fetchall()
        conn.commit()
        cursor.close()
        return result
    finally:
        conn.close()


# ============================================================
# PAGE CONFIG
# ============================================================
st.set_page_config(
    page_title="ABC BANKING LTD",
    page_icon="🏦",
    layout="wide",
)

st.markdown(
    """
    <style>
    .stApp { background-color: #0B1622; }
    h1, h2, h3 { color: #EDE7D9 !important; }
    </style>
    """,
    unsafe_allow_html=True,
)

st.title("🏦 ABC BANKING LTD")
st.caption("Live operations dashboard — connected directly to MySQL")

# ============================================================
# KPI ROW
# ============================================================
kpi_col1, kpi_col2, kpi_col3, kpi_col4 = st.columns(4)

accounts_df = run_query("SELECT * FROM Accounts")
transactions_df = run_query("SELECT * FROM Transactions")
fraud_df = run_query("SELECT * FROM Fraud_Alerts")

with kpi_col1:
    st.metric("Active accounts", len(accounts_df))
with kpi_col2:
    st.metric("Total on deposit", f"${accounts_df['balance'].sum():,.2f}")
with kpi_col3:
    st.metric("Transactions logged", len(transactions_df))
with kpi_col4:
    st.metric("Fraud alerts open", len(fraud_df), delta_color="inverse")

st.divider()

# ============================================================
# FRAUD ALERTS
# ============================================================
st.subheader("🚩 Flagged for review")

fraud_detail_query = """
SELECT
    c.first_name, c.last_name, a.account_id, a.account_type,
    t.amount, f.reason, f.flagged_on
FROM Fraud_Alerts f
JOIN Transactions t ON f.transaction_id = t.transaction_id
JOIN Accounts a ON f.account_id = a.account_id
JOIN Customers c ON a.customer_id = c.customer_id
ORDER BY f.flagged_on DESC
"""
fraud_detail = run_query(fraud_detail_query)

if fraud_detail.empty:
    st.info("No fraud alerts currently on record.")
else:
    for _, row in fraud_detail.iterrows():
        st.error(
            f"**{row['first_name']} {row['last_name']}** — "
            f"{row['account_type']} #{row['account_id']} · "
            f"−${row['amount']:,.2f} · {row['reason']} "
            f"({row['flagged_on']})"
        )

st.divider()

# ============================================================
# ACCOUNTS TABLE
# ============================================================
st.subheader("Accounts")

accounts_view_query = """
SELECT c.first_name, c.last_name, a.account_id, a.account_type,
       a.balance, a.status
FROM Accounts a
JOIN Customers c ON a.customer_id = c.customer_id
ORDER BY a.balance DESC
"""
st.dataframe(run_query(accounts_view_query), use_container_width=True, hide_index=True)

st.divider()

# ============================================================
# RECENT TRANSACTIONS
# ============================================================
st.subheader("Recent transactions")

recent_txn_query = """
SELECT t.transaction_date, c.first_name, c.last_name,
       a.account_type, t.transaction_type, t.amount
FROM Transactions t
JOIN Accounts a ON t.account_id = a.account_id
JOIN Customers c ON a.customer_id = c.customer_id
ORDER BY t.transaction_date DESC
LIMIT 15
"""
st.dataframe(run_query(recent_txn_query), use_container_width=True, hide_index=True)

st.divider()

# ============================================================
# WEALTH RANKING (window function)
# ============================================================
st.subheader("Balance ranking")

rank_query = """
SELECT c.first_name, c.last_name, SUM(a.balance) AS total_balance,
       RANK() OVER (ORDER BY SUM(a.balance) DESC) AS wealth_rank
FROM Customers c
JOIN Accounts a ON c.customer_id = a.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY wealth_rank
LIMIT 10
"""
rank_df = run_query(rank_query)
st.bar_chart(rank_df.set_index(rank_df["first_name"] + " " + rank_df["last_name"])["total_balance"])

st.divider()

# ============================================================
# TRANSFER FUNDS — calls the REAL stored procedure
# ============================================================
st.subheader("Transfer funds")
st.caption("Calls the live TransferFunds() stored procedure — this actually writes to the database.")

acct_options_df = run_query(
    """
    SELECT a.account_id,
           CONCAT(c.first_name, ' ', c.last_name, ' — ', a.account_type,
                  ' ($', FORMAT(a.balance, 2), ')') AS label
    FROM Accounts a JOIN Customers c ON a.customer_id = c.customer_id
    """
)
acct_map = dict(zip(acct_options_df["label"], acct_options_df["account_id"]))

col1, col2, col3 = st.columns(3)
with col1:
    from_label = st.selectbox("From account", acct_map.keys())
with col2:
    to_label = st.selectbox("To account", acct_map.keys(), index=1)
with col3:
    amount = st.number_input("Amount (USD)", min_value=0.0, step=100.0)

if st.button("Execute transfer", type="primary"):
    from_id = acct_map[from_label]
    to_id = acct_map[to_label]

    if from_id == to_id:
        st.error("From and To accounts must be different.")
    elif amount <= 0:
        st.error("Enter an amount greater than zero.")
    else:
        result = run_procedure("TransferFunds", [from_id, to_id, amount])
        message = result[0][0] if result else "No response from procedure."
        if "successful" in message.lower():
            st.success(message)
            st.rerun()
        else:
            st.warning(message)
