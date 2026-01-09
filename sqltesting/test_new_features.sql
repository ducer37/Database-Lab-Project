-- TEST SCRIPT FOR NEW FEATURES
-- Run this after running create_tables, customer_mssql, admin_mssql, and insert_data.

USE ECommerceDB1;
GO

PRINT '=== TEST 1: UPDATE PROFILE ===';
-- 1. Register a user
EXEC register_user 'test_profile@example.com', '123456', 'Old Name', '0901111111';

-- 2. Get ID (Safe method)
DECLARE @u_id INT;
SELECT TOP 1 @u_id = id FROM users WHERE email = 'test_profile@example.com';

-- 3. Update Profile (Name & Phone only)
EXEC update_profile @u_id, @p_name = 'New Name', @p_phone = '0902222222';

-- 4. Verify
SELECT id, name, phone, email FROM users WHERE id = @u_id;
PRINT 'Look at the result above. Should be "New Name" and "0902222222".';
GO


PRINT '=== TEST 2: ADDRESS MANAGEMENT ===';
DECLARE @u_id INT; SELECT TOP 1 @u_id = id FROM users WHERE email = 'test_profile@example.com';

-- 1. Add Address
EXEC add_address @u_id, 'Receiver A', '0909998887', 'Hanoi', 'Ba Dinh', 'Kim Ma', '123 Kim Ma';
DECLARE @addr_id INT; 
SELECT TOP 1 @addr_id = id FROM addresses WHERE user_id = @u_id ORDER BY id DESC;

-- 2. Update Address (Change City & Set Default)
EXEC update_address @addr_id, @u_id, @p_city = 'Da Nang', @p_is_default = 1;

-- Verify Update
SELECT * FROM addresses WHERE id = @addr_id;

-- 3. Delete Address
EXEC delete_address @addr_id, @u_id;

-- Verify Delete
IF NOT EXISTS (SELECT 1 FROM addresses WHERE id = @addr_id) 
    PRINT 'SUCCESS: Address deleted.';
ELSE 
    PRINT 'ERROR: Address still exists.';
GO


PRINT '=== TEST 3: CART STOCK CHECK (Logic Fix) ===';
-- Prerequisite: FORCE Product Variant 1 Stock to 10 for testing
UPDATE product_variants SET stock = 10 WHERE id = 1;

-- 1. Add 5 items to cart
DECLARE @u_id INT; SELECT TOP 1 @u_id = id FROM users WHERE email = 'test_profile@example.com';
EXEC cart_add_item @u_id, 1, 5;
PRINT 'Added 5 items (Current Cart: 5. Stock: 10)';
DECLARE @u_id INT; SELECT TOP 1 @u_id = id FROM users WHERE email = 'test_profile@example.com';

-- 2. Try to add 6 more items (Total 11 > 10) -> Should Fail
BEGIN TRY
    EXEC cart_add_item @u_id, 1, 6;
    PRINT 'ERROR: Should have failed due to out of stock but did not!';
END TRY
BEGIN CATCH
    PRINT 'SUCCESS: Blocked correctly. Error: ' + ERROR_MESSAGE();
END CATCH
GO


PRINT '=== TEST 4: CANCEL ORDER & RESTORE VOUCHER ===';
-- 1. Setup Wrapper
DECLARE @u_id INT; SELECT TOP 1 @u_id = id FROM users WHERE email = 'test_profile@example.com';
DECLARE @v_id INT; SELECT TOP 1 @v_id = id FROM vouchers WHERE code = 'WELCOME50';
DECLARE @addr_id INT; 
-- Need an address to checkout
EXEC add_address @u_id, 'Test', '111', 'HN', 'BD', 'KM', '111 KM';
SELECT TOP 1 @addr_id = id FROM addresses WHERE user_id = @u_id;
DECLARE @pay_id INT = 1; -- COD

-- 2. Collect Voucher
EXEC collect_voucher @u_id, 'WELCOME50';
PRINT 'Collected voucher WELCOME50';

-- 3. Checkout with Voucher
-- Ensure cart has items (Test 3 added 5 items of product 1)
EXEC checkout @u_id, @addr_id, @pay_id, @v_id;
DECLARE @o_id INT; SELECT TOP 1 @o_id = id FROM orders WHERE user_id = @u_id ORDER BY id DESC;
PRINT CONCAT('Order Created: ', @o_id);

-- Check Voucher Used Status (Should be 1)
SELECT 'Before Cancel' as state, is_used FROM user_vouchers WHERE user_id = @u_id AND voucher_id = @v_id;

-- 4. Cancel Order
EXEC cancel_order @u_id, @o_id;

-- 5. Check Voucher Used Status (Should be 0)
SELECT 'After Cancel' as state, is_used FROM user_vouchers WHERE user_id = @u_id AND voucher_id = @v_id;
GO


PRINT '=== TEST 5: UPDATE PRODUCT (Admin) ===';
DECLARE @p_id INT = 1;
-- 1. Update Product Name and Price
EXEC update_product @p_id, @p_name = 'Updated Laptop Name', @p_price = 15000000;

-- 2. Verify
SELECT id, name, price FROM products WHERE id = @p_id;
PRINT 'Should show "Updated Laptop Name" and 15000000.';
GO
