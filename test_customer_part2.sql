-- TEST CUSTOMER FEATURES - PART 2: CART & CHECKOUT
-- Run this in SSMS/Azure Data Studio
USE ECommerceDB1;
GO

PRINT '=============================================';
PRINT '       TESTING CART MANAGEMENT';
PRINT '=============================================';

DECLARE @TestUserID INT = 7; -- John Doe

-- Test 3.1: Add Item to Cart
-- Add 2 units of Variant 1 (White T-Shirt M, Stock 100)
PRINT '>> Test 3.1: Add 2 units of Variant 1 to Cart...';
EXEC cart_add_item @p_user_id = @TestUserID, @p_variant_id = 1, @p_quantity = 2;

-- Test 3.2: Add another item
-- Add 1 unit of Variant 5 (Red Dress S, Stock 20)
PRINT '>> Test 3.2: Add 1 unit of Variant 5 to Cart...';
EXEC cart_add_item @p_user_id = @TestUserID, @p_variant_id = 5, @p_quantity = 1;

-- Test 3.3: View Cart Details
PRINT '>> Test 3.3: View Cart Details';
EXEC cart_view_details @p_user_id = 7;

-- Test 3.4: Update Quantity
-- Change Variant 1 quantity to 5
PRINT '>> Test 3.4: Update Variant 1 quantity to 5...';
EXEC cart_update_item_quantity @p_user_id = @TestUserID, @p_variant_id = 1, @p_new_quantity = 5;

-- Test 3.5: Remove Item
-- Remove Variant 5 from Cart
PRINT '>> Test 3.5: Remove Variant 5 from Cart...';
EXEC cart_remove_item @p_user_id = @TestUserID, @p_variant_id = 5;

-- View Cart again to confirm
PRINT '>> Verify Cart after updates (Should have only 5x Variant 1)';
EXEC cart_view_details @p_user_id = @TestUserID;
GO

PRINT '';
PRINT '=============================================';
PRINT '       TESTING CHECKOUT & PAYMENT';
PRINT '=============================================';

DECLARE @TestUserID INT = 7; -- John Doe


-- Test 4.1: Collect Voucher
PRINT '>> Test 4.1: Collect Voucher "WELCOME50" (50k off)...';
EXEC collect_voucher @p_user_id = @TestUserID, @p_voucher_code = 'WELCOME50';

-- Confirm Voucher Collection
PRINT '>> Check My Vouchers:';
EXEC view_my_vouchers @p_user_id = @TestUserID;

-- UPDATE user_vouchers SET is_used = 0 WHERE user_id = 7 AND voucher_id = (SELECT id FROM vouchers WHERE code = 'WELCOME50')
-- Test 4.2: Perform Checkout
-- User: 2 (John Doe)
-- Address: 1 (Default: 123 Le Loi St)
-- Payment: 2 (COD)
-- Voucher: 1 (WELCOME50 id, assuming id=1 from seed)
PRINT '>> Test 4.2: Checkout with Voucher...';

-- Determine Voucher ID (Dynamic fetch for correctness in test)
DECLARE @VoucherID INT;
SELECT @VoucherID = id FROM vouchers WHERE code = 'WELCOME50';

-- Run Checkout
BEGIN TRY
    EXEC checkout 
        @p_user_id = @TestUserID,
        @p_address_id = 4,
        @p_payment_method_id = 2,
        @p_voucher_id = @VoucherID;
END TRY
BEGIN CATCH
    PRINT 'Checkout Error: ' + ERROR_MESSAGE();
END CATCH;


-- Test 4.3: Verify Order Creation
PRINT '>> Test 4.3: Verify New Order Created...';
SELECT TOP 1 * FROM orders WHERE user_id = @TestUserID ORDER BY created_at DESC;
SELECT TOP 5 * FROM order_items WHERE order_id = (SELECT TOP 1 id FROM orders WHERE user_id = @TestUserID ORDER BY created_at DESC);

-- Test 4.4: Verify Inventory Deduction
-- Stock of Variant 1 (TS-WHT-M) started at 100.
-- We bought 5 units. Expect Stock = 95.
PRINT '>> Test 4.4: Verify Inventory (Expected 95 for Variant 1)';
SELECT id, sku, stock FROM product_variants WHERE id = 1;
GO
