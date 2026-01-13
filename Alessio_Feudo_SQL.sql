/*
In this project written by me, Alessio Feudo using DBeaver and MySQL, the aim is to analyze bank clients, 
producing new features and accomodating them together in a final table, useful for machine learning models training.
*/

# TABLES VISUALIZATION
SELECT * FROM cliente c;

SELECT * FROM conto co ORDER BY co.id_cliente;

SELECT * FROM transazioni t;

SELECT * FROM tipo_transazione tt;

SELECT * FROM tipo_conto tc;


# NOTE
# In the following queries, sometimes I chose to report also non required fields, since it turns useful to build the final table of the project.
# Every query is inserted in a temporary table which is automatically deleted at the end of session. Furthermore, at each script execution, each table is overwritten to have always updated data.


############# BASIC INDICATORS

# Client age
DROP TEMPORARY TABLE IF EXISTS EtaClienti;
CREATE TEMPORARY TABLE EtaClienti AS
SELECT *, 
  TIMESTAMPDIFF(YEAR, data_nascita, CURDATE())   # age computation, considering in what part of the year is the client's birthday, removing one year when needed
  - CASE 
      WHEN MONTH(CURDATE()) < MONTH(data_nascita) THEN 1
      WHEN MONTH(CURDATE()) = MONTH(data_nascita) AND DAY(CURDATE()) < DAY(data_nascita) THEN 1
      ELSE 0
    END AS età
FROM cliente;

SELECT * FROM EtaClienti; # visualizing the table




############## TRANSACTION INDICATORS

# Number of outgoing transactions from all accounts.
DROP TEMPORARY TABLE IF EXISTS OutTransactions_all;
CREATE TEMPORARY TABLE OutTransactions_all AS
SELECT              
  cl.id_cliente, 
  COUNT(t.id_conto) AS n_transazioni_out
FROM cliente cl
LEFT JOIN conto co ON co.id_cliente = cl.id_cliente     # using this left join all clients are considered
LEFT JOIN transazioni t ON t.id_conto = co.id_conto AND t.id_tipo_trans >= 3  # using this left join all accounts are considered, also those with no transactions. And condition limits joined trasactions to outgoing ones only.
GROUP BY cl.id_cliente;
 
SELECT * FROM OutTransactions_all    # visualizing the table
ORDER BY id_cliente;



# Number of ingoing transactions on all accounts.
DROP TEMPORARY TABLE IF EXISTS InTransactions_all;
CREATE TEMPORARY TABLE InTransactions_all AS
SELECT 
	cl.id_cliente, 
	COUNT(t.id_conto) AS n_transazioni_in 
FROM cliente cl
LEFT JOIN conto co ON co.id_cliente = cl.id_cliente       # using this left join all clients are considered
LEFT JOIN transazioni t ON t.id_conto = co.id_conto AND t.id_tipo_trans < 3  # using this left join all accounts are considered, also those with no transactions. And condition limits joined trasactions to ingoing ones only.
GROUP BY cl.id_cliente;

SELECT * FROM InTransactions_all    # visualizing the table
ORDER BY id_cliente; 


# Total amount transacted outgoing on all accounts.
DROP TEMPORARY TABLE IF EXISTS OutTransactionImport_all;
CREATE TEMPORARY TABLE OutTransactionImport_all AS
SELECT 
	cl.id_cliente, 
	COUNT(t.id_conto) AS n_transazioni_out, 
	ROUND(COALESCE(SUM(t.importo), 0),3) AS somma_importi_out   # summing the outgoing imports, inserting 0 when the total outgoing import is NULL (for no transactions) using coalesce, finally rounding the result
FROM cliente cl 
LEFT JOIN conto co ON co.id_cliente = cl.id_cliente
LEFT JOIN transazioni t ON t.id_conto = co.id_conto AND t.id_tipo_trans >= 3 # using this left join all accounts are considered, also those with no transactions. And condition limits joined trasactions to outgoing ones only.
GROUP BY cl.id_cliente;

SELECT * FROM OutTransactionImport_all   # visualizing the table
ORDER BY id_cliente; 


# Total amount transacted ingoing on all accounts.
DROP TEMPORARY TABLE IF EXISTS InTransactionImport_all;
CREATE TEMPORARY TABLE InTransactionImport_all AS
SELECT 
	cl.id_cliente, 
	COUNT(t.id_conto) AS n_transazioni_in, 
	ROUND(COALESCE(SUM(t.importo), 0),3) AS somma_importi_in    # summing the ingoing imports, inserting 0 when the total ingoing import is NULL (for no transactions) using coalesce, finally rounding the result
FROM cliente cl 
LEFT JOIN conto co ON co.id_cliente = cl.id_cliente
LEFT JOIN transazioni t ON t.id_conto = co.id_conto AND t.id_tipo_trans < 3  # using this left join all accounts are considered, also those with no transactions. And condition limits joined trasactions to ingoing ones only.
GROUP BY cl.id_cliente;

SELECT * FROM InTransactionImport_all   # visualizing the table
ORDER BY id_cliente; 





############## ACCOUNT INDICATORS

# Total number of accounts held.
DROP TEMPORARY TABLE IF EXISTS TotAccounts_all;
CREATE TEMPORARY TABLE TotAccounts_all AS
SELECT 
	cl.id_cliente, 
	COUNT(co.id_cliente) AS numero_conti    # total number of accounts for each client
FROM cliente cl
LEFT JOIN conto co ON co.id_cliente = cl.id_cliente    # left join to consider also clients with no accounts
GROUP BY cl.id_cliente; 

SELECT * FROM TotAccounts_all   # visualizing the table
ORDER BY id_cliente; 



# Number of accounts held by type (one field for each account type).
DROP TEMPORARY TABLE IF EXISTS TotAccounts_type;
CREATE TEMPORARY TABLE TotAccounts_type AS
SELECT 
	cl.id_cliente, 
	COUNT(co.id_cliente) AS numero_conti,   # total number of accounts for each client
	SUM(CASE WHEN co.id_tipo_conto = 0 THEN 1 ELSE 0 END) AS n_conto_base,   # number of accounts per type
	SUM(CASE WHEN co.id_tipo_conto = 1 THEN 1 ELSE 0 END) AS n_conto_business,
	SUM(CASE WHEN co.id_tipo_conto = 2 THEN 1 ELSE 0 END) AS n_conto_privati,
	SUM(CASE WHEN co.id_tipo_conto = 3 THEN 1 ELSE 0 END) AS n_conto_famiglie
FROM cliente cl
LEFT JOIN conto co ON co.id_cliente=cl.id_cliente     # left join to consider all clients, also those without account
GROUP BY cl.id_cliente; 

SELECT * FROM TotAccounts_type  # visualizing the table
ORDER BY id_cliente; 





############## TRANSACTION INDICATORS BY ACCOUNT TYPE

# Number of outgoing transactions by account type (one field per account type).
DROP TEMPORARY TABLE IF EXISTS OutTransactions_type;
CREATE TEMPORARY TABLE OutTransactions_type AS
SELECT 
	cl.id_cliente, 
	SUM(CASE WHEN co.id_tipo_conto = 0 AND t.id_conto IS NOT NULL THEN 1 ELSE 0 END) AS n_trans_out_conto_base,   # adding outgoing transactions for each account type 
	SUM(CASE WHEN co.id_tipo_conto = 1 AND t.id_conto IS NOT NULL THEN 1 ELSE 0 END) AS n_trans_out_conto_business,
	SUM(CASE WHEN co.id_tipo_conto = 2 AND t.id_conto IS NOT NULL THEN 1 ELSE 0 END) AS n_trans_out_conto_privati,
	SUM(CASE WHEN co.id_tipo_conto = 3 AND t.id_conto IS NOT NULL THEN 1 ELSE 0 END) AS n_trans_out_conto_famiglie
FROM cliente cl
LEFT JOIN conto co ON co.id_cliente = cl.id_cliente     # using this left join all clients are considered
LEFT JOIN transazioni t ON t.id_conto = co.id_conto AND t.id_tipo_trans >= 3  # using this left join all accounts are considered, also those with no transactions. And condition limits joined trasactions to outgoing ones only.
GROUP BY cl.id_cliente;

SELECT * FROM OutTransactions_type   # visualizing the table
ORDER BY id_cliente;


# Number of ingoing transactions by account type (one field per account type).
DROP TEMPORARY TABLE IF EXISTS InTransactions_type;
CREATE TEMPORARY TABLE InTransactions_type AS
SELECT 
	cl.id_cliente, 
	SUM(CASE WHEN co.id_tipo_conto = 0 AND t.id_conto IS NOT NULL THEN 1 ELSE 0 END) AS n_trans_in_conto_base,    # adding ingoing transactions for each account type 
	SUM(CASE WHEN co.id_tipo_conto = 1 AND t.id_conto IS NOT NULL THEN 1 ELSE 0 END) AS n_trans_in_conto_business,
	SUM(CASE WHEN co.id_tipo_conto = 2 AND t.id_conto IS NOT NULL THEN 1 ELSE 0 END) AS n_trans_in_conto_privati,
	SUM(CASE WHEN co.id_tipo_conto = 3 AND t.id_conto IS NOT NULL THEN 1 ELSE 0 END) AS n_trans_in_conto_famiglie
FROM cliente cl
LEFT JOIN conto co ON co.id_cliente = cl.id_cliente     # using this left join all clients are considered
LEFT JOIN transazioni t ON t.id_conto = co.id_conto AND t.id_tipo_trans < 3   # using this left join all accounts are considered, also those with no transactions. And condition limits joined trasactions to ingoing ones only.
GROUP BY cl.id_cliente; 

SELECT * FROM InTransactions_type  # visualizing the table
ORDER BY id_cliente; 


# Outgoing transaction amount by account type (one field per account type).
DROP TEMPORARY TABLE IF EXISTS OutTransactionImport_type;
CREATE TEMPORARY TABLE OutTransactionImport_type AS
SELECT 
	cl.id_cliente, 
	ROUND(SUM(CASE WHEN co.id_tipo_conto = 0 AND t.id_conto IS NOT NULL THEN t.importo ELSE 0 END),3) AS importo_out_conto_base,   # adding outgoing transaction imports for each account type 
	ROUND(SUM(CASE WHEN co.id_tipo_conto = 1 AND t.id_conto IS NOT NULL THEN t.importo ELSE 0 END),3) AS importo_out_conto_business,
	ROUND(SUM(CASE WHEN co.id_tipo_conto = 2 AND t.id_conto IS NOT NULL THEN t.importo ELSE 0 END),3) AS importo_out_conto_privati,
	ROUND(SUM(CASE WHEN co.id_tipo_conto = 3 AND t.id_conto IS NOT NULL THEN t.importo ELSE 0 END),3) AS importo_out_conto_famiglie
FROM cliente cl
LEFT JOIN conto co ON co.id_cliente = cl.id_cliente     # using this left join all clients are considered
LEFT JOIN transazioni t ON t.id_conto = co.id_conto AND t.id_tipo_trans >= 3   # using this left join all accounts are considered, also those with no transactions. And condition limits joined trasactions to outgoing ones only.
GROUP BY cl.id_cliente;

SELECT * FROM OutTransactionImport_type  # visualizing the table
ORDER BY id_cliente; 


# Ingoing transaction amount by account type (one field per account type).
DROP TEMPORARY TABLE IF EXISTS InTransactionImport_type;
CREATE TEMPORARY TABLE InTransactionImport_type AS
SELECT 
	cl.id_cliente, 
	ROUND(SUM(CASE WHEN co.id_tipo_conto = 0 AND t.id_conto IS NOT NULL THEN t.importo ELSE 0 END),3) AS importo_in_conto_base,  # adding ingoing transaction imports for each account type
	ROUND(SUM(CASE WHEN co.id_tipo_conto = 1 AND t.id_conto IS NOT NULL THEN t.importo ELSE 0 END),3) AS importo_in_conto_business,
	ROUND(SUM(CASE WHEN co.id_tipo_conto = 2 AND t.id_conto IS NOT NULL THEN t.importo ELSE 0 END),3) AS importo_in_conto_privati,
	ROUND(SUM(CASE WHEN co.id_tipo_conto = 3 AND t.id_conto IS NOT NULL THEN t.importo ELSE 0 END),3) AS importo_in_conto_famiglie
FROM cliente cl
LEFT JOIN conto co ON co.id_cliente = cl.id_cliente     # using this left join all clients are considered, also those with no accounts
LEFT JOIN transazioni t ON t.id_conto = co.id_conto AND t.id_tipo_trans < 3  # using this left join all accounts are considered, also those with no transactions. And condition limits joined trasactions to ingoing ones only.
GROUP BY cl.id_cliente;
	
SELECT * FROM InTransactionImport_type  # visualizing the table
ORDER BY id_cliente; 





############## DENORMALIZED TABLE
DROP TABLE IF EXISTS final_table;
CREATE TABLE final_table AS  # creating the final table from a query which joins all the extracted features from previous temp. tables
SELECT 
	ec.*, 
	otia.n_transazioni_out , otia.somma_importi_out, 
	itia.n_transazioni_in, itia.somma_importi_in, 
	tat.numero_conti, tat.n_conto_base, tat.n_conto_business, tat.n_conto_privati, tat.n_conto_famiglie, 
	ott.n_trans_out_conto_base, ott.n_trans_out_conto_business, ott.n_trans_out_conto_privati, ott.n_trans_out_conto_famiglie,
	itt.n_trans_in_conto_base, itt.n_trans_in_conto_business , itt.n_trans_in_conto_privati , itt.n_trans_in_conto_famiglie, 
	otit.importo_out_conto_base, otit.importo_out_conto_business , otit.importo_out_conto_privati , otit.importo_out_conto_famiglie,  
	itit.importo_in_conto_base, itit.importo_in_conto_business , itit.importo_in_conto_privati , itit.importo_in_conto_famiglie  
FROM EtaClienti ec 
JOIN OutTransactionImport_all otia ON ec.id_cliente = otia.id_cliente 
JOIN InTransactionImport_all itia ON ec.id_cliente = itia.id_cliente
JOIN TotAccounts_type tat ON ec.id_cliente = tat.id_cliente 
JOIN OutTransactions_type ott ON ec.id_cliente = ott.id_cliente 
JOIN InTransactions_type itt ON ec.id_cliente = itt.id_cliente 
JOIN OutTransactionImport_type otit ON ec.id_cliente = otit.id_cliente 
JOIN InTransactionImport_type itit ON ec.id_cliente = itit.id_cliente 
ORDER BY ec.id_cliente;

SELECT * FROM final_table; # visualizing the final table


