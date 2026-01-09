-- ============================================================
-- BULK INSERT PRODUCTS FOR PERFORMANCE TESTING
-- Generates 50,000 products with Variants and Categories
-- ============================================================

USE ECommerceDBIndexTest2;
GO

SET NOCOUNT ON;
PRINT 'STARTING BULK INSERT...';

DECLARE @i INT = 1;
DECLARE @Total INT = 50000; -- Number of products to generate
DECLARE @NewID INT;
DECLARE @RandomPrice DECIMAL(10,2);
DECLARE @RandomName NVARCHAR(200);
DECLARE @RandomSlug NVARCHAR(200);

BEGIN TRANSACTION;

WHILE @i <= @Total
BEGIN
    -- Generate Random Data
    SET @RandomPrice = CAST(RAND() * 1000000 + 50000 AS INT); -- Price between 50k and 1M
    SET @RandomName = CONCAT('Bulk Product ', @i, ' - ', CHECKSUM(NEWID()));
    SET @RandomSlug = CONCAT('bulk-product-', @i, '-', CAST(NEWID() AS NVARCHAR(36)));

    -- 1. Insert Product
    INSERT INTO products (name, slug, description, original_price, price, thumbnail, is_active, rating, review_count)
    VALUES (
        @RandomName, 
        @RandomSlug, 
        'This is a randomly generated product for testing indexes.',
        @RandomPrice * 1.2, -- Original price 20% higher
        @RandomPrice,
        'https://via.placeholder.com/300',
        1,
        CAST(RAND() * 5 AS DECIMAL(2,1)), -- Random Rating 0-5
        CAST(RAND() * 100 AS INT) -- Random Review Count 0-100
    );

    SET @NewID = SCOPE_IDENTITY();

    -- 2. Insert Variant (Assume 1 variant per product for speed)
    INSERT INTO product_variants (product_id, color, size, sku, stock, image)
    VALUES (
        @NewID, 
        'Default', 
        'M', 
        CONCAT('SKU-', @NewID, '-', @i), 
        100, 
        NULL
    );

    -- 3. Insert Category (Random Category 1-5)
    INSERT INTO product_categories (product_id, category_id)
    VALUES (@NewID, CAST(RAND() * 4 + 1 AS INT));

    -- Print progress every 5000 records
    IF @i % 5000 = 0
    BEGIN
        PRINT CONCAT('Inserted ', @i, ' products...');
		-- Commit and Restart Transaction to keep log size manageable
		COMMIT TRANSACTION;
		BEGIN TRANSACTION;
    END

    SET @i = @i + 1;
END

COMMIT TRANSACTION;
    SET @i = @i + 1;
END

PRINT 'DONE! 50,000 Products inserted.';

-- =============================================
-- PART 2: BULK INSERT ORDERS & REVIEWS
-- =============================================
PRINT 'STARTING BULK INSERT FOR ORDERS & REVIEWS...';
DECLARE @j INT = 1;
DECLARE @TotalOrders INT = 20000;
DECLARE @RandUserID INT;
DECLARE @RandTotal DECIMAL(10,2);
DECLARE @RandDate DATETIME2;

BEGIN TRANSACTION;
WHILE @j <= @TotalOrders
BEGIN
    SET @RandUserID = CAST(RAND() * 2 + 1 AS INT); -- User ID 1, 2, or 3 (small pool but fine)
    SET @RandTotal = CAST(RAND() * 5000000 + 100000 AS INT);
    -- Random Date within last 60 days
    SET @RandDate = DATEADD(day, -CAST(RAND() * 60 AS INT), GETDATE());

    -- 1. Insert Order
    INSERT INTO orders (user_id, shipping_address, payment_method, status, total_amount, final_amount, payment_status, created_at)
    VALUES (
        @RandUserID, 
        'Bulk Address 123', 
        'COD', 
        CASE WHEN @j % 5 = 0 THEN 'PENDING' ELSE 'COMPLETED' END, -- 20% Pending
        @RandTotal, 
        @RandTotal, 
        'PAID', 
        @RandDate
    );

    -- 2. Insert Review (for random product 1-1000)
    INSERT INTO reviews (user_id, product_id, rating, comment, created_at)
    VALUES (
        @RandUserID,
        CAST(RAND() * 1000 + 1 AS INT), -- Review for first 1000 products
        5,
        'Auto generated review for testing index.',
        @RandDate
    );

    IF @j % 5000 = 0
    BEGIN
        PRINT CONCAT('Inserted ', @j, ' orders & reviews...');
		COMMIT TRANSACTION;
		BEGIN TRANSACTION;
    END

    SET @j = @j + 1;
END
COMMIT TRANSACTION;
PRINT 'DONE! 20,000 Orders & Reviews inserted.';
GO
