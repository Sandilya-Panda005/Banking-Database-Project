-- CREATING DATABASE AND TABLES
CREATE DATABASE BankSystem;
USE BankSystem;

CREATE TABLE Customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    dob DATE,
    email VARCHAR(100),
    join_date DATE DEFAULT (CURRENT_DATE)
);

CREATE TABLE Accounts (
    account_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT,
    account_type ENUM('Savings','Checking') NOT NULL,
    balance DECIMAL(12,2) DEFAULT 0,
    interest_rate DECIMAL(5,4) DEFAULT 0.03,
    status ENUM('Active','Closed','Frozen') DEFAULT 'Active',
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id)
);

CREATE TABLE Transactions (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    account_id INT,
    transaction_type ENUM('Deposit','Withdrawal','Transfer'),
    amount DECIMAL(12,2),
    transaction_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (account_id) REFERENCES Accounts(account_id)
);

CREATE TABLE Fraud_Alerts (
    alert_id INT AUTO_INCREMENT PRIMARY KEY,
    account_id INT,
    transaction_id INT,
    reason VARCHAR(200),
    flagged_on DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Account_Audit (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    account_id INT,
    old_balance DECIMAL(12,2),
    new_balance DECIMAL(12,2),
    changed_on DATETIME DEFAULT CURRENT_TIMESTAMP
);


-- CREATING THE TRIGGERS AND EVENTS FOR THE UPCOMING DATA TO BE INSERTED
-- TRIGGER 1 FOR AUTO UPDATION OF BALANCE ON TRANSACTION + AUDIT LOG
DELIMITER $$
CREATE TRIGGER trg_update_balance
AFTER INSERT ON Transactions
FOR EACH ROW
BEGIN
    DECLARE old_bal DECIMAL(12,2);
    SELECT balance INTO old_bal FROM Accounts WHERE account_id = NEW.account_id;

    IF NEW.transaction_type = 'Deposit' THEN
        UPDATE Accounts SET balance = balance + NEW.amount WHERE account_id = NEW.account_id;
    ELSEIF NEW.transaction_type = 'Withdrawal' THEN
        UPDATE Accounts SET balance = balance - NEW.amount WHERE account_id = NEW.account_id;
    END IF;

    INSERT INTO Account_Audit(account_id, old_balance, new_balance)
    SELECT NEW.account_id, old_bal, balance FROM Accounts WHERE account_id = NEW.account_id;
END$$
DELIMITER ;

-- TRIGGER 2 FRAUD DETECTION WITH LARGE WITHDRAWAL FLAG
DELIMITER $$
CREATE TRIGGER trg_fraud_check
AFTER INSERT ON Transactions
FOR EACH ROW
BEGIN
    IF NEW.transaction_type = 'Withdrawal' AND NEW.amount > 50000 THEN
        INSERT INTO Fraud_Alerts(account_id, transaction_id, reason)
        VALUES (NEW.account_id, NEW.transaction_id, 'Large withdrawal exceeding threshold');
    END IF;
END$$
DELIMITER ;


-- EVENT -MONTHLY INTEREST CREDIT 


DELIMITER $$
CREATE EVENT evt_monthly_interest
ON SCHEDULE EVERY 1 MONTH
DO
BEGIN
    UPDATE Accounts
    SET balance = balance + (balance * interest_rate / 12)
    WHERE account_type = 'Savings' AND status = 'Active';
END$$
DELIMITER ;


-- PROCEDURES TRANSFER MONEYBETWEEN ACCOUNTS(WITH VALIDATION)

DELIMITER $$
CREATE PROCEDURE TransferFunds(
    IN from_acc INT, 
    IN to_acc INT, 
    IN amt DECIMAL(12,2)
)
BEGIN
    DECLARE sender_balance DECIMAL(12,2);
    SELECT balance INTO sender_balance FROM Accounts WHERE account_id = from_acc;

    IF sender_balance >= amt THEN
        UPDATE Accounts SET balance = balance - amt WHERE account_id = from_acc;
        UPDATE Accounts SET balance = balance + amt WHERE account_id = to_acc;
        
        INSERT INTO Transactions(account_id, transaction_type, amount) VALUES (from_acc, 'Withdrawal', amt);
        INSERT INTO Transactions(account_id, transaction_type, amount) VALUES (to_acc, 'Deposit', amt);
        
        SELECT 'Transfer successful' AS message;
    ELSE
        SELECT 'Insufficient funds' AS message;
    END IF;
END$$
DELIMITER ;

-- DATA INSERTION
USE BankSystem;
 

-- CUSTOMERS (15)

INSERT INTO Customers (first_name, last_name, dob, email) VALUES
('Leslie',   'Knope',      '1975-01-18', 'leslie.knope@email.com'),
('Ron',      'Swanson',    '1965-03-02', 'ron.swanson@email.com'),
('Tom',      'Haverford',  '1990-06-25', 'tom.haverford@email.com'),
('April',    'Ludgate',    '1992-09-08', 'april.ludgate@email.com'),
('Ben',      'Wyatt',      '1980-04-14', 'ben.wyatt@email.com'),
('Ann',      'Perkins',    '1982-11-30', 'ann.perkins@email.com'),
('Donna',    'Meagle',     '1978-07-21', 'donna.meagle@email.com'),
('Andy',     'Dwyer',      '1988-02-05', 'andy.dwyer@email.com'),
('Jerry',    'Gergich',    '1955-12-19', 'jerry.gergich@email.com'),
('Chris',    'Traeger',    '1970-05-10', 'chris.traeger@email.com'),
('Mark',     'Brendanawicz','1979-08-12','mark.b@email.com'),
('Shauna',   'Malwae-Tweep','1983-03-27','shauna.mt@email.com'),
('Perd',     'Hapley',     '1976-10-02', 'perd.hapley@email.com'),
('Joan',     'Callamezzo', '1972-06-16', 'joan.callamezzo@email.com'),
('Dennis',   'Feinstein',  '1968-01-29', 'dennis.feinstein@email.com');
 
-- 
-- ACCOUNTS (18) — some customers hold 2 accounts
INSERT INTO Accounts (customer_id, account_type, balance, interest_rate) VALUES
(1,  'Savings',  15000.00, 0.035),  -- 1  Leslie
(1,  'Checking',  4200.00, 0.000),  -- 2  Leslie
(2,  'Savings',  92000.00, 0.030),  -- 3  Ron
(3,  'Checking',  1800.00, 0.000),  -- 4  Tom
(4,  'Savings',   6700.00, 0.032),  -- 5  April
(5,  'Checking', 23000.00, 0.000),  -- 6  Ben
(6,  'Savings',  41000.00, 0.030),  -- 7  Ann
(7,  'Savings',  78500.00, 0.028),  -- 8  Donna
(8,  'Checking',   950.00, 0.000),  -- 9  Andy
(9,  'Savings', 120000.00, 0.025),  -- 10 Jerry
(10, 'Checking', 15600.00, 0.000),  -- 11 Chris
(11, 'Savings',   8900.00, 0.031),  -- 12 Mark
(12, 'Checking',  5400.00, 0.000),  -- 13 Shauna
(13, 'Savings',  33000.00, 0.029),  -- 14 Perd
(14, 'Checking',  2100.00, 0.000),  -- 15 Joan
(15, 'Savings',  57000.00, 0.030),  -- 16 Dennis
(2,  'Checking', 11000.00, 0.000),  -- 17 Ron (2nd account)
(9,  'Checking',  9800.00, 0.000);  -- 18 Jerry (2nd account)
 
-- TRANSACTIONS (55) — spread across ~6 weeks, varied amounts
-- Two intentionally large withdrawals (>50000) to trigger
-- trg_fraud_check
INSERT INTO Transactions (account_id, transaction_type, amount, transaction_date) VALUES
(1,  'Deposit',    2000.00, '2026-07-01 09:15:00'),
(2,  'Withdrawal',  500.00, '2026-07-01 14:22:00'),
(3,  'Deposit',    1200.00, '2026-07-02 10:05:00'),
(4,  'Withdrawal',  300.00, '2026-07-02 16:40:00'),
(5,  'Deposit',    3000.00, '2026-07-03 11:12:00'),
(6,  'Withdrawal', 1500.00, '2026-07-03 13:50:00'),
(7,  'Deposit',    5000.00, '2026-07-04 08:45:00'),
(8,  'Withdrawal',  200.00, '2026-07-04 17:30:00'),
(9,  'Deposit',   10000.00, '2026-07-05 09:00:00'),
(10, 'Withdrawal', 2500.00, '2026-07-05 12:20:00'),
(11, 'Deposit',    1800.00, '2026-07-06 10:30:00'),
(12, 'Withdrawal',  700.00, '2026-07-06 15:10:00'),
(13, 'Deposit',    2200.00, '2026-07-07 11:45:00'),
(14, 'Withdrawal', 1300.00, '2026-07-07 14:00:00'),
(15, 'Deposit',    4000.00, '2026-07-08 09:20:00'),
(16, 'Withdrawal', 2100.00, '2026-07-08 16:15:00'),
(17, 'Deposit',    3500.00, '2026-07-09 10:00:00'),
(18, 'Withdrawal',  900.00, '2026-07-09 13:30:00'),
(1,  'Withdrawal', 1000.00, '2026-07-10 09:00:00'),
(3,  'Deposit',     800.00, '2026-07-10 11:00:00'),
(4,  'Deposit',    60000.00,'2026-07-11 09:00:00'),
(4,  'Withdrawal', 60000.00,'2026-07-11 10:00:00'),
(5,  'Withdrawal', 500.00, '2026-07-11 15:00:00'),
(6,  'Deposit',    2200.00, '2026-07-12 08:30:00'),
(7,  'Withdrawal', 3000.00, '2026-07-12 12:00:00'),
(8,  'Deposit',    1100.00, '2026-07-13 09:45:00'),
(9,  'Withdrawal', 4500.00, '2026-07-13 14:20:00'),
(10, 'Deposit',    2600.00, '2026-07-14 10:10:00'),
(11, 'Withdrawal', 1400.00, '2026-07-14 16:00:00'),
(12, 'Deposit',    3300.00, '2026-07-15 09:30:00'),
(13, 'Withdrawal', 1900.00, '2026-07-15 13:15:00'),
(14, 'Deposit',    2700.00, '2026-07-16 11:00:00'),
(15, 'Withdrawal', 3200.00, '2026-07-16 15:45:00'),
(16, 'Deposit',    4100.00, '2026-07-17 10:20:00'),
(17, 'Withdrawal', 2000.00, '2026-07-17 14:50:00'),
(18, 'Deposit',    1600.00, '2026-07-18 09:10:00'),
(1,  'Deposit',    2500.00, '2026-07-19 08:00:00'),
(2,  'Deposit',    1300.00, '2026-07-19 12:30:00'),
(3,  'Withdrawal',  900.00, '2026-07-20 10:45:00'),
(10, 'Deposit',   55000.00, '2026-07-21 09:00:00'),
(10, 'Withdrawal',55000.00, '2026-07-21 11:00:00'),
(6,  'Withdrawal', 1800.00, '2026-07-22 13:00:00'),
(7,  'Deposit',    2900.00, '2026-07-22 16:20:00'),
(8,  'Withdrawal',  600.00, '2026-07-23 09:40:00'),
(9,  'Deposit',    7200.00, '2026-07-23 12:10:00'),
(11, 'Deposit',    2000.00, '2026-07-24 10:00:00'),
(12, 'Withdrawal', 1100.00, '2026-07-24 15:30:00'),
(13, 'Deposit',    3400.00, '2026-07-25 08:50:00'),
(14, 'Withdrawal', 1700.00, '2026-07-25 14:10:00'),
(15, 'Deposit',    2800.00, '2026-07-26 09:25:00'),
(16, 'Withdrawal', 2400.00, '2026-07-26 13:40:00'),
(17, 'Deposit',    3100.00, '2026-07-27 10:15:00'),
(18, 'Withdrawal', 1500.00, '2026-07-27 16:05:00'),
(1,  'Deposit',    1900.00, '2026-07-28 09:00:00'),
(5,  'Deposit',    2600.00, '2026-07-28 12:45:00'),
(9,  'Withdrawal', 3300.00, '2026-07-29 15:00:00');
 

-- Running balance per account over time
SELECT account_id, transaction_date, amount,
       SUM(amount) OVER (PARTITION BY account_id ORDER BY transaction_date) AS running_total
FROM Transactions;

-- Rank customers by total account balance
SELECT c.customer_id, c.first_name, SUM(a.balance) AS total_balance,
       RANK() OVER (ORDER BY SUM(a.balance) DESC) AS wealth_rank
FROM Customers c
JOIN Accounts a ON c.customer_id = a.customer_id
GROUP BY c.customer_id;

-- MONTHLY TRANSACTION SUMMARY
WITH Monthly_Summary AS (
    SELECT account_id, 
           DATE_FORMAT(transaction_date, '%Y-%m') AS month,
           SUM(amount) AS total_amount
    FROM Transactions
    GROUP BY account_id, month
)
SELECT * FROM Monthly_Summary ORDER BY account_id, month;