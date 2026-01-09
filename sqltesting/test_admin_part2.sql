-- TEST ADMIN FEATURES - PART 2: ORDERS & REPORTS
-- Run this in SSMS/Azure Data Studio
USE ECommerceDB1;
GO

PRINT '=============================================';
PRINT '       TESTING ORDER MANAGEMENT';
PRINT '=============================================';

-- Test 3.1: View Orders (Filter by Status)
PRINT '>> Test 3.1: View Pending Orders...';
EXEC view_orders @p_status = 'PENDING';

-- SELECT * FROM orders
-- Find Order ID to test update (The one created in test_customer_part2.sql)
-- User 2, Status PENDING
DECLARE @OrderID INT;
SELECT TOP 1 @OrderID = id FROM orders WHERE user_id = 2 AND status = 'PENDING';
PRINT '   Testing with Order ID: ' + CAST(@OrderID AS NVARCHAR(20));

DECLARE @OrderID INT = 2;
-- Test 3.2: Update Status -> CONFIRMED
PRINT '>> Test 3.2: Update Status to CONFIRMED...';
EXEC update_order_status @p_order_id = @OrderID, @p_new_status = 'CONFIRMED';
SELECT id, status, payment_status, updated_at FROM orders WHERE id = @OrderID;

-- Test 3.3: Update Status -> COMPLETED
-- (Should auto-update Payment Status to PAID)
DECLARE @OrderID INT = 2;

PRINT '>> Test 3.3: Update Status to COMPLETED...';
EXEC update_order_status @p_order_id = @OrderID, @p_new_status = 'COMPLETED';
SELECT id, status, payment_status FROM orders WHERE id = @OrderID;

-- Test 3.4: Update Status -> RETURNED
-- (Should Restock items & Refund payment)
DECLARE @OrderID INT = 2;

PRINT '>> Test 3.4: Update Status to RETURNED...';
-- Check initial stock
SELECT id, sku, stock FROM product_variants WHERE id IN (SELECT variant_id FROM order_items WHERE order_id = @OrderID);

EXEC update_order_status @p_order_id = @OrderID, @p_new_status = 'RETURNED';

-- Verify Result
DECLARE @OrderID INT = 2;

PRINT '   Verify Status (RETURNED/REFUNDED):';
SELECT id, status, payment_status FROM orders WHERE id = @OrderID;

PRINT '   Verify Stock (Should increase back):';
SELECT id, sku, stock FROM product_variants WHERE id IN (SELECT variant_id FROM order_items WHERE order_id = @OrderID);
GO

PRINT '';
PRINT '=============================================';
PRINT '       TESTING REPORTS (SALES)';
PRINT '=============================================';

-- NOTE: Reports only count "COMPLETED" orders.
-- Our previous test just RETURNED the order, so it won't show up in revenue.
-- Let's revive Order 1 from insert_data (seeded as COMPLETED) for testing.
-- Order 1: 150k, 1 item.

-- Test 4.1: Revenue by Date
PRINT '>> Test 4.1: Report Revenue (Last 30 days)...';
DECLARE @StartDate DATE = DATEADD(day, -30, GETDATE());
DECLARE @EndDate DATE = GETDATE();
EXEC report_revenue_by_date @p_start_date = @StartDate, @p_end_date = @EndDate;

-- Test 4.2: Best Sellers
PRINT '>> Test 4.2: Best Sellers Report...';
EXEC report_best_sellers @p_limit = 5;

-- Test 4.3: Revenue by Category
PRINT '>> Test 4.3: Revenue by Category...';
EXEC report_revenue_by_category;
GO
