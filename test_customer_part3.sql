-- TEST CUSTOMER FEATURES - PART 3: TRACKING, WISHLIST, REVIEWS, SUPPORT
-- Run this in SSMS/Azure Data Studio
USE ECommerceDB1;
GO

PRINT '=============================================';
PRINT '       TESTING ORDER TRACKING & CANCELLATION';
PRINT '=============================================';

DECLARE @TestUserID INT = 7; -- John Doe

-- Test 5.1: View Order History
PRINT '>> Test 5.1: View Order History...';
EXEC view_order_history @p_user_id = @TestUserID;

SELECT id, sku, stock FROM product_variants WHERE id = 1;

-- Test 5.2: Cancel Order
-- First, lets create a quick dummy order to cancel (so we don't mess up previous data)
-- We manually insert to save time, mimicking a "Just placed" order
INSERT INTO orders (user_id, shipping_address, payment_method, status, total_amount, final_amount, payment_status)
VALUES (@TestUserID, 'Dummy Addr', 'COD', 'PENDING', 150000, 150000, 'UNPAID');
DECLARE @DummyOrderID INT = SCOPE_IDENTITY();

INSERT INTO order_items (order_id, variant_id, quantity, price)
VALUES (@DummyOrderID, 1, 1, 150000); -- 1x Variant 1

-- Reduce Stock manually to simulate "Sold" state, so we can verify restoration
UPDATE product_variants SET stock = stock - 1 WHERE id = 1;
PRINT '>> Pre-Cancel: Created Dummy Order ID ' + CAST(@DummyOrderID AS NVARCHAR(10)) + '. Stock deducted.';

-- Execute Cancel
PRINT '>> Test 5.2: Cancelling Order ID ' + CAST(@DummyOrderID AS NVARCHAR(10)) + '...';
EXEC cancel_order @p_user_id = @TestUserID, @p_order_id = @DummyOrderID;

-- Verify Status and Stock
PRINT '>> Verify Status (Should be CANCELLED):';
SELECT id, status FROM orders WHERE id = @DummyOrderID;

PRINT '>> Verify Stock Restoration (Should be back to original before dummy order):';
SELECT id, sku, stock FROM product_variants WHERE id = 1;
GO

PRINT '';
PRINT '=============================================';
PRINT '       TESTING WISHLIST';
PRINT '=============================================';
DECLARE @TestUserID INT = 2;

-- Test 6.1: Add to Wishlist (Variant 1)
PRINT '>> Test 6.1: Add Variant 1 to Wishlist...';
EXEC add_to_wishlist @p_user_id = @TestUserID, @p_variant_id = 1;

-- Test 6.2: View Wishlist
PRINT '>> Test 6.2: View Wishlist...';
EXEC view_wishlist @p_user_id = @TestUserID;

-- Test 6.3: Remove from Wishlist
PRINT '>> Test 6.3: Remove Variant 1 from Wishlist...';
EXEC remove_from_wishlist @p_user_id = @TestUserID, @p_variant_id = 1;

-- Verify (Should be empty or not contain Variant 1)
PRINT '>> Verify Wishlist (Variant 1 gone):';
EXEC view_wishlist @p_user_id = @TestUserID;
GO

PRINT '';
PRINT '=============================================';
PRINT '       TESTING REVIEWS & SUPPORT';
PRINT '=============================================';
DECLARE @TestUserID INT = 2;

-- Test 7.1: Submit Review
-- User 2 has bought Product 1 (Classic White T-Shirt) in the seed data (Order 1 - COMPLETED)
PRINT '>> Test 7.1: Submit Review for Product 1 (Valid purchase)...';
EXEC submit_product_review 
    @p_user_id = @TestUserID, 
    @p_product_id = 1, 
    @p_rating = 5, 
    @p_comment = 'Amazing quality!';

-- Verify Review
SELECT TOP 1 * FROM reviews WHERE user_id = @TestUserID ORDER BY created_at DESC;

-- Test 7.2: Fail Review (Product not bought)
-- Product 3 (Belt) was never bought by User 2
PRINT '>> Test 7.2: Submit Review for Product 3 (Not bought - Expect Error)...';
BEGIN TRY
    EXEC submit_product_review 
        @p_user_id = @TestUserID, 
        @p_product_id = 3, 
        @p_rating = 1, 
        @p_comment = 'Fake review';
END TRY
BEGIN CATCH
    PRINT 'Review Error: ' + ERROR_MESSAGE();
END CATCH;

-- Test 7.3: Send Support Message
PRINT '>> Test 7.3: Send Support Message...';
EXEC send_support_message @p_user_id = @TestUserID, @p_content = 'I need help with my returns.';

SELECT TOP 1 * FROM support_messages WHERE user_id = @TestUserID ORDER BY created_at DESC;
GO
