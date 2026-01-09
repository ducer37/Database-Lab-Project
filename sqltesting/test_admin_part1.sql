-- TEST ADMIN FEATURES - PART 1: PRODUCTS & PROMOTIONS
-- Run this in SSMS/Azure Data Studio
USE ECommerceDB;
GO

PRINT '=============================================';
PRINT '       TESTING PRODUCT MANAGEMENT';
PRINT '=============================================';

-- Test 1.1: Create New Product
-- Categories: [1, 4] (Men, T-Shirts) - Passed as JSON String because SQL Server logic
PRINT '>> Test 1.1: Create Product "New Admin Product"...';
EXEC create_product 
    @p_name = 'New Admin Product',
    @p_slug = 'new-admin-prod', 
    @p_description = 'Test Description',
    @p_original_price = 1000,
    @p_price = 800,
    @p_thumbnail = 'test.img',
    @p_category_ids = '[1, 4]';

-- Verify Creation
DECLARE @NewProdID INT;
SELECT @NewProdID = id FROM products WHERE slug = 'new-admin-prod';
PRINT '   Created ID: ' + CAST(@NewProdID AS NVARCHAR(20));

-- Verify Category Link
SELECT * FROM product_categories WHERE product_id = @NewProdID;

-- Test 1.2: Update Product
PRINT '>> Test 1.2: Update Price to 900...';
EXEC update_product @p_product_id = @NewProdID, @p_price = 900;
SELECT price FROM products WHERE id = @NewProdID;

-- Test 1.3: Upsert Variant
-- Add new variant
PRINT '>> Test 1.3: Add Variant (Blue, L)...';
EXEC upsert_variant 
    @p_product_id = @NewProdID,
    @p_color = 'Blue',
    @p_size = 'L',
    @p_sku = 'ADM-BLU-L',
    @p_stock = 50,
    @p_image = 'blue.jpg';

SELECT * FROM product_variants WHERE product_id = @NewProdID;

-- Update existing variant (Change stock)
PRINT '>> Test 1.3b: Update Variant Stock to 100...';
EXEC upsert_variant 
    @p_product_id = @NewProdID,
    @p_color = 'Blue',
    @p_size = 'L',
    @p_sku = 'ADM-BLU-L',
    @p_stock = 100,
    @p_image = 'blue.jpg';

SELECT stock FROM product_variants WHERE sku = 'ADM-BLU-L';

-- Test 1.4: Delete Product (Soft Delete)
PRINT '>> Test 1.4: Soft Delete Product...';
EXEC delete_product @p_product_id = @NewProdID;
SELECT id, is_active FROM products WHERE id = @NewProdID;

-- Test 1.5: Delete Variant (Hard Delete)
DECLARE @VarID INT;
SELECT @VarID = id FROM product_variants WHERE sku = 'ADM-BLU-L';
PRINT '>> Test 1.5: Delete Variant ID ' + CAST(@VarID AS NVARCHAR(20)) + '...';
EXEC delete_variant @p_variant_id = @VarID;
SELECT * FROM product_variants WHERE id = @VarID; -- Should be empty
GO

PRINT '';
PRINT '=============================================';
PRINT '       TESTING PROMOTION MANAGEMENT';
PRINT '=============================================';

-- Test 2.1: Create Voucher
PRINT '>> Test 2.1: Create Voucher "TEST2026"...';
EXEC upsert_voucher 
    @p_code = 'TEST2026', 
    @p_value = 10000, 
    @p_type = 'FIXED', 
    @p_stock = 100,
    @p_start_date = '2026-01-01', 
    @p_end_date = '2026-12-31';

SELECT * FROM vouchers WHERE code = 'TEST2026';
DECLARE @VoucherID INT;
SELECT @VoucherID = id FROM vouchers WHERE code = 'TEST2026';

-- Test 2.2: Update Voucher
PRINT '>> Test 2.2: Update Stock to 200...';
EXEC upsert_voucher @p_id = @VoucherID, @p_stock = 200;
SELECT stock FROM vouchers WHERE id = @VoucherID;

-- Test 2.3: Delete Voucher (Unused)
PRINT '>> Test 2.3: Delete Unused Voucher (Hard delete)...';
EXEC delete_voucher @p_id = @VoucherID;
SELECT * FROM vouchers WHERE id = @VoucherID; -- Should be empty

-- Test 2.4: Delete Voucher (Used - Logic Check)
-- Voucher 'WELCOME50' was used in test_customer_part2.sql
DECLARE @UsedVoucherID INT;
SELECT @UsedVoucherID = id FROM vouchers WHERE code = 'WELCOME50';

PRINT '>> Test 2.4: Update Used Voucher (WELCOME50) to Soft Delete...';
EXEC delete_voucher @p_id = @UsedVoucherID;
SELECT id, code, is_active FROM vouchers WHERE id = @UsedVoucherID; -- Should be Inactive, not deleted

-- Test 2.5: Banner Mgmt
PRINT '>> Test 2.5: Create & Delete Banner...';
EXEC upsert_banner @p_title = 'Test Banner', @p_image_url = 'test.jpg';
-- Assume ID is latest
DECLARE @BanID INT = SCOPE_IDENTITY(); 
-- (Note: SCOPE_IDENTITY inside EXEC might not propagate out simply, better to select max)
SELECT TOP 1 @BanID = id FROM banners ORDER BY id DESC;

EXEC delete_banner @p_id = @BanID;
SELECT * FROM banners WHERE id = @BanID; -- Empty
GO
