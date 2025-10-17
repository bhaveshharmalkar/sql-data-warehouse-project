/*
============================
Create Database and Schemas
============================

Script purpose:
Create database as 'DataWarehose' and in that create three schema for layers as bronze, silver and gold.

*/

-- Create database 
CREATE DATABASE DataWarehouse;

USE DataWarehouse;
GO

-- Create schema
CREATE SCHEMA bronze;
GO
CREATE SCHEMA silver;
GO
CREATE SCHEMA gold;


