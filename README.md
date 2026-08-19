# 🏦 Bank Account Management & Fraud Detection System

## Overview
A relational database system simulating core banking operations —
account management, transaction processing, automated interest 
calculation, and real-time fraud detection.

## Tech Stack
MySQL 8.0 | Triggers | Events | Stored Procedures | Window Functions | CTEs

## ER Diagram

<img width="318" height="602" alt="Screenshot 2026-08-19 at 9 16 32 AM" src="https://github.com/user-attachments/assets/a4cd37fa-bd0f-4112-8706-a423f772bab6" />


## Features
- 🔄 Auto-synced balances via triggers
- 🚨 Real-time fraud detection (large withdrawal alerts)
- 📅 Scheduled monthly interest via EVENT
- 💸 Secure fund transfers via stored procedure
- 📊 Analytics: customer wealth ranking, running balances (window functions)



## How to Run
1.Locate the app.py and requirements.txt in a specific folder
2.pip install -r requirements.txt in macOs terminal
3.By opening app.py edit the password :
DB_CONFIG = {
    "host": "localhost",
    "port": 3306,
    "user": "root",
    "password": "YOUR_MYSQL_PASSWORD",   # <-- put your real Workbench password here
    "database": "BankSystem",
}
4.streamlit run app.py
