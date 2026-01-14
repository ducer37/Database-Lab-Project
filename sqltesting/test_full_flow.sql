-- ============================================================
-- FULL FLOW TEST SCRIPT: REGISTER -> ORDER -> CANCEL
-- Execute this script in SQL Server Management Studio (SSMS)
-- ============================================================

USE ECommerceDB1;
GO

PRINT '==================================================';
PRINT '>>> STEP 1: REGISTER NEW USER & LOGIN';
PRINT '==================================================';
-- 1. Register
-- (Using generated email to avoid conflict if run multiple times)
DECLARE @Email NVARCHAR(50) = 'flow_test_' + CAST(NEWID() AS NVARCHAR(50)) + '@gmail.com';
EXEC register_user @Email, '123456', 'Test User', '0988888888';

-- 2. Retrieve User ID (Simulating Login)
DECLARE @UserID INT;
SELECT TOP 1 @UserID = id FROM users WHERE email = @Email;

-- VERIFY
PRINT 'Expected Check: You should see the new user details below.';
SELECT id, email, name, role FROM users WHERE id = @UserID;
GO


PRINT '==================================================';
PRINT '>>> STEP 2: ADD SHIPPING ADDRESS';
PRINT '==================================================';
DECLARE @UserID INT; SELECT TOP 1 @UserID = id FROM users WHERE email LIKE 'flow_test_%' ORDER BY id DESC;


-- Add Address
EXEC add_address @UserID, 'Test Receiver', '0912345678', 'Hanoi', 'Cau Giay', 'Dich Vong';

-- VERIFY
PRINT 'Expected Check: An address row should appear with is_default = 1.';
SELECT id, user_id, recipient_name, city, is_default FROM addresses WHERE user_id = @UserID;
GO


PRINT '==================================================';
PRINT '>>> STEP 3: BROWSE PRODUCTS & VIEW DETAIL';
PRINT '==================================================';
-- View first 3 products
PRINT 'Browsing products...';
EXEC browse_products @p_limit = 3;

-- Get Detail of Product ID 1 (Assuming it exists from insert_data)
PRINT 'Viewing details of Product #1...';
EXEC get_product_details 1;

-- VERIFY
PRINT 'Expected Check: Ensure Product 1 exists and has Stock > 0 in the variants JSON.';
GO


PRINT '==================================================';
PRINT '>>> STEP 4: ADD TO CART';
PRINT '==================================================';
DECLARE @UserID INT; SELECT TOP 1 @UserID = id FROM users WHERE email LIKE 'flow_test_%' ORDER BY id DESC;
-- Add 2 items of Variant ID 1 (White T-Shirt M)
EXEC cart_add_item @UserID, 1, 2;

-- VERIFY
PRINT 'Expected Check: Cart should show Variant ID 1 with Quantity 2.';
SELECT c.user_id, ci.variant_id, ci.quantity 
FROM cart_items ci JOIN carts c ON ci.cart_id = c.id 
WHERE c.user_id = @UserID;
GO


PRINT '==================================================';
PRINT '>>> STEP 5: CHECKOUT (PLACE ORDER)';
PRINT '==================================================';
DECLARE @UserID INT; SELECT TOP 1 @UserID = id FROM users WHERE email LIKE 'flow_test_%' ORDER BY id DESC;
DECLARE @AddrID INT; SELECT TOP 1 @AddrID = id FROM addresses WHERE user_id = @UserID;
DECLARE @PayID INT = 2; -- COD

-- Checkout
EXEC checkout @UserID, @AddrID, @PayID, NULL; -- No voucher

-- VERIFY
PRINT 'Expected Check: A new Order should be created with Status = PENDING.';
SELECT TOP 1 id, status, total_amount, payment_status, created_at FROM orders WHERE user_id = @UserID ORDER BY id DESC;
GO


PRINT '==================================================';
PRINT '>>> STEP 6: ORDER TRACKING';
PRINT '==================================================';
DECLARE @UserID INT; SELECT TOP 1 @UserID = id FROM users WHERE email LIKE 'flow_test_%' ORDER BY id DESC;

-- View my orders
EXEC view_my_orders @UserID;

-- VERIFY
PRINT 'Expected Check: The list should contain the order created in Step 5.';
GO


PRINT '==================================================';
PRINT '>>> STEP 7: CANCEL ORDER';
PRINT '==================================================';
DECLARE @UserID INT; SELECT TOP 1 @UserID = id FROM users WHERE email LIKE 'flow_test_%' ORDER BY id DESC;
DECLARE @OrderID INT; SELECT TOP 1 @OrderID = id FROM orders WHERE user_id = @UserID ORDER BY id DESC;

-- Create a snapshot of stock before cancel
DECLARE @StockBefore INT; SELECT @StockBefore = stock FROM product_variants WHERE id = 1;
PRINT CONCAT('Stock Before Cancel: ', @StockBefore);

-- Perform Cancel
EXEC cancel_order @UserID, @OrderID;

-- VERIFY
PRINT 'Expected Check 1: Order Status changed to CANCELLED.';
SELECT id, status, updated_at FROM orders WHERE id = @OrderID;

DECLARE @StockAfter INT; SELECT @StockAfter = stock FROM product_variants WHERE id = 1;
PRINT CONCAT('Stock After Cancel: ', @StockAfter);
PRINT 'Expected Check 2: Stock After should be (Stock Before + 2).';
GO

PRINT '==================================================';
PRINT '✅ FULL FLOW TEST COMPLETED SUCCESSFULLY';
PRINT '==================================================';
