-- ============================================================
-- PERFORMANCE TEST SCRIPT: MEASURE INDEX IMPACT
-- Prerequisite: Run bulk_insert_products.sql first (need ~50k rows)
-- ============================================================

USE ECommerceDBIndexTest2;
GO

SET STATISTICS TIME ON;
SET STATISTICS IO ON; -- Shows pages read (Logical Reads) - critical for performance tuning
SET STATISTICS PROFILE ON; -- Equivalent to EXPLAIN ANALYZE (Detailed Execution Plan)
SET NOCOUNT ON;

PRINT '==================================================';
PRINT '>>> TEST 1: PRODUCT SEARCH BY NAME';
PRINT '==================================================';

-- 1. DROP INDEX IF EXISTS (Baseline)
IF EXISTS(SELECT * FROM sys.indexes WHERE name = 'idx_products_name')
    DROP INDEX idx_products_name ON products;
    
DBCC DROPCLEANBUFFERS; -- Clear Cache

SELECT id, name, price FROM products WHERE name LIKE 'Bulk Product 44%';

CREATE NONCLUSTERED INDEX idx_products_name 
ON products(name);

SELECT id, name, price 
FROM products 
WHERE name LIKE 'Bulk Product 44%';


PRINT '==================================================';
PRINT '>>> TEST 2: PRODUCT FILTER BY PRICE';
PRINT '==================================================';
-- 1. DROP INDEX IF EXISTS
IF EXISTS(SELECT * FROM sys.indexes WHERE name = 'idx_products_price')
    DROP INDEX idx_products_price ON products;

DBCC DROPCLEANBUFFERS;

SELECT id, name, price, thumbnail 
FROM products 
WHERE price BETWEEN 200000 AND 500000;

CREATE NONCLUSTERED INDEX idx_products_price 
ON products(price) 
INCLUDE (name, thumbnail);

SELECT id, name, price, thumbnail 
FROM products 
WHERE price BETWEEN 200000 AND 500000;



PRINT '==================================================';
PRINT '>>> TEST 3: JOIN PRODUCTS & CATEGORIES';
PRINT '==================================================';
-- 1. DROP INDEX IF EXISTS
IF EXISTS(SELECT * FROM sys.indexes WHERE name = 'idx_product_categories_category_id')
    DROP INDEX idx_product_categories_category_id ON product_categories;

DBCC DROPCLEANBUFFERS;

SELECT p.id, p.name 
FROM products p 
JOIN product_categories pc ON p.id = pc.product_id 
WHERE pc.category_id = 3;

CREATE NONCLUSTERED INDEX idx_product_categories_category_id 
ON product_categories(category_id) 
INCLUDE (product_id);

SELECT p.id, p.name 
FROM products p 
JOIN product_categories pc ON p.id = pc.product_id 
WHERE pc.category_id = 3;



PRINT '==================================================';
PRINT '>>> TEST 4: SORT BY CREATED_AT (Newest First)';
PRINT '==================================================';
-- 1. DROP INDEX IF EXISTS
IF EXISTS(SELECT * FROM sys.indexes WHERE name = 'idx_products_active_newest')
    DROP INDEX idx_products_active_newest ON products;

DBCC DROPCLEANBUFFERS;

PRINT '[BASELINE] View 20 Newest Products WITHOUT Index...';
SELECT TOP 20 name, price, rating 
FROM products 
WHERE is_active = 1 
ORDER BY created_at DESC;

CREATE NONCLUSTERED INDEX idx_products_active_newest 
ON products(is_active, created_at DESC) 
INCLUDE (name, price, thumbnail, rating, review_count);

DBCC DROPCLEANBUFFERS;

SELECT TOP 20 name, price, rating 
FROM products 
WHERE is_active = 1 
ORDER BY created_at DESC;
GO


PRINT '==================================================';
PRINT '>>> TEST 5: GET PRODUCT DETAIL (Variants + Stock)';
PRINT '==================================================';
-- DROP
IF EXISTS(SELECT * FROM sys.indexes WHERE name = 'idx_product_variants_product')
    DROP INDEX idx_product_variants_product ON product_variants;
DBCC DROPCLEANBUFFERS;

PRINT '[BASELINE] Get Variants for Product #100...';
SELECT color, size, stock FROM product_variants WHERE product_id = 100;

CREATE NONCLUSTERED INDEX idx_product_variants_product 
ON product_variants(product_id) 
INCLUDE (color, size, stock, image);

SELECT color, size, stock 
FROM product_variants 
WHERE product_id = 100;
GO


PRINT '==================================================';
PRINT '>>> TEST 6: GET REVIEWS FOR PRODUCT';
PRINT '==================================================';
-- DROP
IF EXISTS(SELECT * FROM sys.indexes WHERE name = 'idx_reviews_product_created')
    DROP INDEX idx_reviews_product_created ON reviews;
DBCC DROPCLEANBUFFERS;

PRINT '[BASELINE] Get Reviews for Product #1...';
SELECT rating, comment FROM reviews WHERE product_id = 1 ORDER BY created_at DESC;



-- CREATE
CREATE NONCLUSTERED INDEX idx_reviews_product_created 
ON reviews(product_id, created_at DESC) 
INCLUDE (rating, comment, user_id);

SELECT rating, comment 
FROM reviews
WHERE product_id = 1 
ORDER BY created_at DESC;


PRINT '==================================================';
PRINT '>>> TEST 7: ADMIN - ORDER STATUS REPORT';
PRINT '==================================================';
-- DROP
IF EXISTS(SELECT * FROM sys.indexes WHERE name = 'idx_orders_status')
    DROP INDEX idx_orders_status ON orders;
DBCC DROPCLEANBUFFERS;

PRINT '[BASELINE] Count PENDING orders...';
SELECT COUNT(*), SUM(total_amount) FROM orders WHERE status = 'PENDING';

-- CREATE
CREATE NONCLUSTERED INDEX idx_orders_status 
ON orders(status) 
INCLUDE (user_id, total_amount, created_at);

SELECT COUNT(*), SUM(total_amount) 
FROM orders WHERE status = 'PENDING';


PRINT '==================================================';
PRINT '>>> TEST 8: ADMIN - REVENUE REPORT BY DATE';
PRINT '==================================================';
-- DROP
IF EXISTS(SELECT * FROM sys.indexes WHERE name = 'idx_orders_created_at')
    DROP INDEX idx_orders_created_at ON orders;
DBCC DROPCLEANBUFFERS;

PRINT '[BASELINE] Revenue for last 30 days...';
SELECT SUM(final_amount) FROM orders WHERE created_at > DATEADD(day, -30, GETDATE());

-- CREATE
CREATE NONCLUSTERED INDEX idx_orders_created_at 
ON orders(created_at) 
INCLUDE (status, final_amount);

SELECT SUM(final_amount) 
FROM orders 
WHERE created_at > DATEADD(day, -30, GETDATE());

SET STATISTICS PROFILE OFF;
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
PRINT '==================================================';
PRINT 'PERFORMANCE TEST COMPLETED. CHECK "MESSAGES" FOR TIME & "RESULTS" FOR EXECUTION PLAN.';
PRINT '==================================================';
