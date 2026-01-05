-- TEST CUSTOMER FEATURES - PART 1
-- Run this in SSMS/Azure Data Studio to valid logic
USE ECommerceDB1;
GO

PRINT '=============================================';
PRINT '       TESTING USER REGISTRATION';
PRINT '=============================================';

-- Test 1.1: Register a new user successfully
PRINT '>> Test 1.1: Register new user (new_user@test.com)...';
EXEC register_user 
    @p_email = 'new_userr@test.com',
    @p_password = 'password123',
    @p_name = 'New Tester',
    @p_phone = '0123456789';

-- Check if user exists
SELECT * FROM users WHERE email = 'new_userr@test.com';

-- Test 1.2: Register with duplicate email (Should fail)
PRINT '>> Test 1.2: Register duplicate email (Expect Error/Message)...';
EXEC register_user 
    @p_email = 'new_userr@test.com',
    @p_password = 'password123',
    @p_name = 'Duplicate User',
    @p_phone = '0123456789';
GO

PRINT '';
PRINT '=============================================';
PRINT '       TESTING PRODUCT BROWSING';
PRINT '=============================================';

-- Test 2.1: Browse all products (Newest first)
PRINT '>> Test 2.1: Browse Products (All)';
EXEC browse_products;

-- Test 2.2: Search by keyword 'Shirt'
PRINT '>> Test 2.2: Search for "Shirt"';
EXEC browse_products @p_keyword = 'Shirt';

-- Test 2.3: Filter by Price (0 - 200,000)
PRINT '>> Test 2.3: Filter Price <= 200k';
EXEC browse_products @p_max_price = 200000;

-- Test 2.4: Get Trending Products
PRINT '>> Test 2.4: Trending Products';
EXEC get_trending_products @p_limit = 5;

-- Test 2.5: Get Product Details (JSON Output)
PRINT '>> Test 2.5: Get Details for Product ID 1 (Returns JSON)';
EXEC get_product_details @p_product_id = 1;

-- Test 2.6: Get Details for Invalid Product (Should Error)
PRINT '>> Test 2.6: Get Invalid Product ID 999 (Expect Error)';
BEGIN TRY
    EXEC get_product_details @p_product_id = 999;
END TRY
BEGIN CATCH
    PRINT 'Error Caught: ' + ERROR_MESSAGE();
END CATCH;
GO
