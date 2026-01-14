-- Admin Logic for SQL Server (Transact-SQL)
USE ECommerceDBDemo5;
GO
-- 1. Product Management

-- 1.1. Create new product
CREATE OR ALTER PROCEDURE create_product
    @p_name NVARCHAR(200),
    @p_slug NVARCHAR(200), 
    @p_description NVARCHAR(MAX),
    @p_original_price DECIMAL(10,2),
    @p_price DECIMAL(10,2),
    @p_thumbnail NVARCHAR(MAX),
    @p_category_ids NVARCHAR(MAX) 
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_prod_id INT;

    -- Insert into Products
    INSERT INTO products (name, slug, description, original_price, price, thumbnail, is_active)
    VALUES (@p_name, @p_slug, @p_description, @p_original_price, @p_price, @p_thumbnail, 1);
    
    SET @v_prod_id = SCOPE_IDENTITY();

    -- Link Categories using OPENJSON
    IF @p_category_ids IS NOT NULL
    BEGIN
        INSERT INTO product_categories (product_id, category_id)
        SELECT @v_prod_id, value
        FROM OPENJSON(@p_category_ids)
        WHERE NOT EXISTS (
            SELECT 1 FROM product_categories 
            WHERE product_id = @v_prod_id AND category_id = CAST(value AS INT)
        );
    END;

    SELECT 'SUCCESS' as status, @v_prod_id as product_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
END;
GO

-- 1.2. Update product information
CREATE OR ALTER PROCEDURE update_product
    @p_product_id INT,
    @p_name NVARCHAR(200) = NULL,
    @p_description NVARCHAR(MAX) = NULL,
    @p_price DECIMAL(10,2) = NULL,
    @p_thumbnail NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE products
    SET name = ISNULL(@p_name, name),
        description = ISNULL(@p_description, description),
        price = ISNULL(@p_price, price),
        thumbnail = ISNULL(@p_thumbnail, thumbnail),
        updated_at = GETDATE()
    WHERE id = @p_product_id;

    IF @@ROWCOUNT = 0
        THROW 50001, 'Product ID not found!', 1;

    SELECT 'SUCCESS: Product updated.' AS result;
END;
GO

-- 1.3. Add new product variant (Upsert)
CREATE OR ALTER PROCEDURE upsert_variant
    @p_product_id INT,
    @p_color NVARCHAR(50),
    @p_size NVARCHAR(50),
    @p_sku NVARCHAR(100),
    @p_stock INT,
    @p_image NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    MERGE product_variants AS target
    USING (SELECT @p_product_id, @p_color, @p_size) AS source (product_id, color, size)
    ON (target.product_id = source.product_id AND target.color = source.color AND target.size = source.size)
    WHEN MATCHED THEN
        UPDATE SET 
            stock = @p_stock,
            sku = @p_sku,
            image = @p_image
    WHEN NOT MATCHED THEN
        INSERT (product_id, color, size, sku, stock, image)
        VALUES (@p_product_id, @p_color, @p_size, @p_sku, @p_stock, @p_image);

    SELECT 'SUCCESS: Variant processed (Added or Updated).' AS result;
END;
GO

-- 1.4. Delete product (Soft Delete)
CREATE OR ALTER PROCEDURE delete_product
    @p_product_id INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE products
    SET is_active = 0,
        updated_at = GETDATE()
    WHERE id = @p_product_id;

    IF @@ROWCOUNT = 0
        THROW 50002, 'Product ID not found!', 1;

    SELECT 'SUCCESS: Product deactivated.' AS result;
END;
GO

-- 1.5. Delete variant (Hard Delete logic)
CREATE OR ALTER PROCEDURE delete_variant
    @p_variant_id INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Check if exists in Orders
    IF EXISTS (SELECT 1 FROM order_items WHERE variant_id = @p_variant_id)
    BEGIN
        THROW 50003, 'Cannot delete Variant: It exists in past orders. Please update Stock to 0 instead.', 1;
    END

    DELETE FROM product_variants WHERE id = @p_variant_id;

    IF @@ROWCOUNT = 0
        THROW 50004, 'Variant ID not found!', 1;

    SELECT 'SUCCESS: Variant deleted permanently.' AS result;
END;
GO

-- 2. Promotion Management

-- 2.1. Upsert Voucher
CREATE OR ALTER PROCEDURE upsert_voucher
    @p_id INT = NULL,
    @p_code NVARCHAR(50) = NULL,
    @p_value DECIMAL(10,2) = 0,
    @p_type NVARCHAR(20) = 'FIXED',
    @p_stock INT = 0,
    @p_start_date DATETIME2 = NULL,
    @p_end_date DATETIME2 = NULL,
    @p_is_active BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @p_id IS NULL
    BEGIN
        IF EXISTS (SELECT 1 FROM vouchers WHERE code = @p_code)
            THROW 50005, 'Voucher code already exists!', 1;

        INSERT INTO vouchers (code, value, type, stock, start_date, end_date, is_active)
        VALUES (@p_code, @p_value, @p_type, @p_stock, @p_start_date, @p_end_date, @p_is_active);
        
        SELECT 'SUCCESS: Promotion created.' AS result;
    END
    ELSE
    BEGIN
        UPDATE vouchers
        SET code = ISNULL(@p_code, code),
            value = ISNULL(@p_value, value),
            type = ISNULL(@p_type, type),
            stock = ISNULL(@p_stock, stock),
            start_date = ISNULL(@p_start_date, start_date),
            end_date = ISNULL(@p_end_date, end_date),
            is_active = ISNULL(@p_is_active, is_active)
        WHERE id = @p_id;

        IF @@ROWCOUNT = 0 THROW 50006, 'Voucher ID not found', 1;
        
        SELECT 'SUCCESS: Promotion updated.' AS result;
    END
END;
GO

-- 2.2. Delete Voucher
CREATE OR ALTER PROCEDURE delete_voucher
    @p_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_used_count INT;

    SELECT @v_used_count = used_count FROM vouchers WHERE id = @p_id;

    IF @v_used_count > 0
    BEGIN
        UPDATE vouchers SET is_active = 0 WHERE id = @p_id;
        SELECT 'NOTICE: Voucher has usage history. Deactivate voucher instead of delete.' AS result;
    END
    ELSE
    BEGIN
        DELETE FROM vouchers WHERE id = @p_id;
        SELECT 'SUCCESS: Voucher deleted permanently.' AS result;
    END
END;
GO

-- 2.3. Upsert Banner
CREATE OR ALTER PROCEDURE upsert_banner
    @p_id INT = NULL,
    @p_title NVARCHAR(200) = NULL,
    @p_image_url NVARCHAR(MAX) = NULL,
    @p_link_url NVARCHAR(MAX) = NULL,
    @p_display_order INT = 0,
    @p_is_active BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @p_id IS NULL
    BEGIN
        INSERT INTO banners (title, image_url, link_url, display_order, is_active)
        VALUES (@p_title, @p_image_url, @p_link_url, @p_display_order, @p_is_active);
        SELECT 'SUCCESS: Banner created.' AS result;
    END
    ELSE
    BEGIN
        UPDATE banners
        SET title = ISNULL(@p_title, title),
            image_url = ISNULL(@p_image_url, image_url),
            link_url = ISNULL(@p_link_url, link_url),
            display_order = ISNULL(@p_display_order, display_order),
            is_active = ISNULL(@p_is_active, is_active),
            updated_at = GETDATE()
        WHERE id = @p_id;

        IF @@ROWCOUNT = 0 THROW 50007, 'Banner ID not found', 1;
        SELECT 'SUCCESS: Banner updated.' AS result;
    END
END;
GO

-- 2.4. Delete Banner
CREATE OR ALTER PROCEDURE delete_banner
    @p_id INT
AS
BEGIN
    DELETE FROM banners WHERE id = @p_id;
    IF @@ROWCOUNT = 0 THROW 50008, 'Banner ID not found', 1;
    SELECT 'SUCCESS: Banner deleted.' AS result;
END;
GO

-- 3. Order Management

-- 3.1. View Orders
CREATE OR ALTER PROCEDURE view_orders
    @p_status NVARCHAR(20) = NULL,
    @p_start_date DATETIME2 = NULL,
    @p_end_date DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        o.id as order_id,
        u.email as user_email,
        o.total_amount,
        o.final_amount,
        o.status,
        o.payment_method,
        o.created_at
    FROM orders o
    JOIN users u ON o.user_id = u.id
    WHERE (@p_status IS NULL OR o.status = @p_status)
      AND (@p_start_date IS NULL OR o.created_at >= @p_start_date)
      AND (@p_end_date IS NULL OR o.created_at <= @p_end_date)
    ORDER BY o.created_at DESC;
END;
GO

-- 3.2. Update Order Status
CREATE OR ALTER PROCEDURE update_order_status
    @p_order_id INT,
    @p_new_status NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_current_status NVARCHAR(20);

    -- Check and Lock
    SELECT @v_current_status = status 
    FROM orders WITH (UPDLOCK) 
    WHERE id = @p_order_id;

    IF @v_current_status IS NULL
        THROW 50009, 'Order ID not found', 1;

    -- Update status
    UPDATE orders            
    SET status = @p_new_status, updated_at = GETDATE() 
    WHERE id = @p_order_id;

    -- Restock logic
    IF @p_new_status IN ('CANCELLED', 'RETURNED') 
       AND @v_current_status NOT IN ('CANCELLED', 'RETURNED')
    BEGIN
        UPDATE pv
        SET pv.stock = pv.stock + oi.quantity
        FROM product_variants pv
        JOIN order_items oi ON pv.id = oi.variant_id
        WHERE oi.order_id = @p_order_id;
        
        IF @p_new_status = 'RETURNED'
        BEGIN
            UPDATE orders SET payment_status = 'REFUNDED' WHERE id = @p_order_id;
        END
    END
    ELSE IF @p_new_status = 'COMPLETED'
    BEGIN
        UPDATE orders SET payment_status = 'PAID' WHERE id = @p_order_id;
    END

    SELECT CONCAT('SUCCESS: Status updated to ', @p_new_status) AS result;
END;
GO

-- 4. Reports

-- 4.1. Revenue By Date
CREATE OR ALTER PROCEDURE report_revenue_by_date
    @p_start_date DATE,
    @p_end_date DATE
AS
BEGIN
    SELECT 
        CAST(created_at AS DATE) as sale_date,
        COUNT(id) as total_orders,
        ISNULL(SUM(final_amount), 0) as total_revenue
    FROM orders
    WHERE status = 'COMPLETED'
      AND CAST(created_at AS DATE) BETWEEN @p_start_date AND @p_end_date
    GROUP BY CAST(created_at AS DATE)
    ORDER BY sale_date DESC;
END;
GO

-- 4.2. Best Sellers
CREATE OR ALTER PROCEDURE report_best_sellers
    @p_limit INT = 10,
    @p_start_date DATETIME2 = NULL,
    @p_end_date DATETIME2 = NULL
AS
BEGIN
    SELECT TOP (@p_limit)
        p.id as product_id,
        p.name as product_name,
        SUM(oi.quantity) as qty_sold,
        SUM(oi.quantity * oi.price) as revenue
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.id
    JOIN product_variants pv ON oi.variant_id = pv.id
    JOIN products p ON pv.product_id = p.id
    WHERE o.status = 'COMPLETED'
      AND (@p_start_date IS NULL OR o.created_at >= @p_start_date)
      AND (@p_end_date IS NULL OR o.created_at <= @p_end_date)
    GROUP BY p.id, p.name
    ORDER BY qty_sold DESC;
END;
GO

-- 4.3. Revenue by Category
CREATE OR ALTER PROCEDURE report_revenue_by_category
    @p_start_date DATETIME2 = NULL,
    @p_end_date DATETIME2 = NULL
AS
BEGIN
    SELECT 
        c.id as category_id,
        c.name as category_name,
        SUM(oi.quantity * oi.price) as total_revenue
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.id
    JOIN product_variants pv ON oi.variant_id = pv.id
    JOIN product_categories pc ON pv.product_id = pc.product_id
    JOIN categories c ON pc.category_id = c.id
    WHERE o.status = 'COMPLETED'
      AND (@p_start_date IS NULL OR o.created_at >= @p_start_date)
      AND (@p_end_date IS NULL OR o.created_at <= @p_end_date)
    GROUP BY c.id, c.name
    ORDER BY total_revenue DESC;
END;
GO
