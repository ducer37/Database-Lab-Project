USE ECommerceDBDemo5;
GO

CREATE OR ALTER PROCEDURE register_user
    @p_email NVARCHAR(255),
    @p_password NVARCHAR(MAX),
    @p_name NVARCHAR(100),
    @p_phone NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM users WHERE email = @p_email)
    BEGIN
        SELECT 'ERROR: Email already existed!' AS result;
        RETURN;
    END

    -- Hash password using SHA2_256 and convert to hex string
    DECLARE @hashed_password NVARCHAR(MAX);
    SET @hashed_password = CONVERT(NVARCHAR(MAX), HASHBYTES('SHA2_256', @p_password), 2);

    INSERT INTO users (email, password, name, phone, role)
    VALUES (@p_email, @hashed_password, @p_name, @p_phone, 'CUSTOMER');

    DECLARE @new_id INT = SCOPE_IDENTITY();
    SELECT CONCAT('SUCCESS: Successfully register new account. User ID: ', @new_id) AS result;
END;
GO

-- 1.2. Login
CREATE OR ALTER PROCEDURE login_user
    @p_email NVARCHAR(255),
    @p_password NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_user_id INT, @v_role NVARCHAR(50), @v_name NVARCHAR(100), @v_avatar NVARCHAR(MAX);

    -- Hash the input password and compare with stored hash
    DECLARE @hashed_password NVARCHAR(MAX);
    SET @hashed_password = CONVERT(NVARCHAR(MAX), HASHBYTES('SHA2_256', @p_password), 2);

    SELECT @v_user_id = id, @v_role = role, @v_name = name, @v_avatar = avatar
    FROM users 
    WHERE email = @p_email AND password = @hashed_password;

    IF @v_user_id IS NULL
        THROW 50001, 'Invalid email or password.', 1;

    SELECT 
        'SUCCESS' as status,
        @v_user_id as user_id,
        @p_email as email,
        @v_name as name,
        @v_role as role,
        @v_avatar as avatar
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
END;
GO

-- 1.3. Update Profile
CREATE OR ALTER PROCEDURE update_profile
    @p_user_id INT,
    @p_name NVARCHAR(100) = NULL,
    @p_phone NVARCHAR(20) = NULL,
    @p_password NVARCHAR(MAX) = NULL,
    @p_avatar NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE users
    SET name = ISNULL(@p_name, name),
        phone = ISNULL(@p_phone, phone),
        password = ISNULL(@p_password, password),
        avatar = ISNULL(@p_avatar, avatar)
    WHERE id = @p_user_id;

    IF @@ROWCOUNT = 0
        THROW 50002, 'User ID not found.', 1;

    SELECT 'SUCCESS: Profile updated.' AS result;
END;
GO

-- 2. Product browsing

-- 2.1. Search products
CREATE OR ALTER PROCEDURE browse_products
    @p_keyword NVARCHAR(200) = NULL,
    @p_category_slug NVARCHAR(100) = NULL,
    @p_color NVARCHAR(50) = NULL,
    @p_size NVARCHAR(50) = NULL,
    @p_min_price DECIMAL(18,2) = 0,
    @p_max_price DECIMAL(18,2) = 999999999,
    @p_min_rating FLOAT = 0,
    @p_sort_by NVARCHAR(20) = 'newest', -- 'newest', 'price_asc', 'price_desc', 'best_rating'
    @p_limit INT = 10,
    @p_offset INT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        p.id as product_id,
        p.name as product_name,
        p.original_price,
        p.price as current_price,
        p.thumbnail,
        p.rating as avg_rating,
        p.review_count as total_reviews,
        c.name as category_name,
        p.created_at
    FROM products p
    LEFT JOIN product_categories pc ON p.id = pc.product_id
    LEFT JOIN categories c ON pc.category_id = c.id
    LEFT JOIN product_variants pv ON p.id = pv.product_id
    WHERE p.is_active = 1
      AND (@p_keyword IS NULL OR p.name LIKE '%' + @p_keyword + '%' OR p.description LIKE '%' + @p_keyword + '%')
      AND (@p_category_slug IS NULL OR c.slug = @p_category_slug)
      AND (@p_min_price IS NULL OR CAST(p.price AS DECIMAL(18,2)) >= @p_min_price)
      AND (@p_max_price IS NULL OR CAST(p.price AS DECIMAL(18,2)) <= @p_max_price)
      AND (p.rating >= @p_min_rating)
      AND (@p_color IS NULL OR pv.color LIKE @p_color)
      AND (@p_size IS NULL OR pv.size LIKE @p_size)
    GROUP BY p.id, p.name, p.original_price, p.price, p.thumbnail, p.rating, p.review_count, c.name, p.created_at
    ORDER BY
        CASE WHEN @p_sort_by = 'newest' THEN p.created_at END DESC,
        CASE WHEN @p_sort_by = 'price_asc' THEN p.price END ASC,
        CASE WHEN @p_sort_by = 'price_desc' THEN p.price END DESC,
        CASE WHEN @p_sort_by = 'best_rating' THEN p.rating END DESC,
        p.id ASC
    OFFSET @p_offset ROWS FETCH NEXT @p_limit ROWS ONLY;
END;
GO

-- 2.2. Get trending products
CREATE OR ALTER PROCEDURE get_trending_products
    @p_limit INT = 5
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@p_limit)
        p.id as product_id,
        p.name as product_name,
        p.price,
        p.thumbnail,
        SUM(oi.quantity) as total_sold
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.id
    JOIN product_variants pv ON oi.variant_id = pv.id
    JOIN products p ON pv.product_id = p.id
    WHERE o.status = 'COMPLETED'
      AND o.created_at >= DATEADD(day, -30, GETDATE())
    GROUP BY p.id, p.name, p.price, p.thumbnail
    ORDER BY total_sold DESC;
END;
GO

-- 2.3. Get product details
CREATE OR ALTER PROCEDURE get_product_details
    @p_product_id INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Check exist
    IF NOT EXISTS (SELECT 1 FROM products WHERE id = @p_product_id AND is_active = 1)
        THROW 50010, 'Product ID found or inactive.', 1;

    SELECT 
        info = JSON_QUERY((
            SELECT id, name, slug, description, original_price, price, thumbnail, rating, review_count
            FROM products 
            WHERE id = @p_product_id
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )),
        variants = JSON_QUERY((
            SELECT id, color, size, sku, stock, image
            FROM product_variants
            WHERE product_id = @p_product_id
            FOR JSON PATH
        )),
        latest_reviews = JSON_QUERY((
            SELECT TOP 5 u.name as user_name, r.rating, r.comment, r.created_at
            FROM reviews r
            JOIN users u ON r.user_id = u.id
            WHERE r.product_id = @p_product_id
            ORDER BY r.created_at DESC
            FOR JSON PATH
        ))
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
END;
GO

-- 3. Cart Management

-- 3.1. Add item to cart
CREATE OR ALTER PROCEDURE cart_add_item
    @p_user_id INT,
    @p_variant_id INT,
    @p_quantity INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_stock INT, @v_is_active BIT;
    DECLARE @v_cart_id INT;

    -- Check Product
    SELECT @v_stock = pv.stock, @v_is_active = p.is_active
    FROM product_variants pv
    JOIN products p ON pv.product_id = p.id
    WHERE pv.id = @p_variant_id;

    -- Get current quantity in cart
    DECLARE @v_current_cart_qty INT = 0;
    SELECT @v_current_cart_qty = ISNULL(ci.quantity, 0)
    FROM cart_items ci
    JOIN carts c ON ci.cart_id = c.id
    WHERE c.user_id = @p_user_id AND ci.variant_id = @p_variant_id;
    
    SET @v_current_cart_qty = ISNULL(@v_current_cart_qty, 0);

    IF @v_stock IS NULL THROW 50011, 'Product variant not found!', 1;
    IF @v_is_active = 0 THROW 50012, 'This product is not sold!', 1;
    
    -- Total (In Cart + New) vs Stock
    IF (@v_current_cart_qty + @p_quantity) > @v_stock 
       THROW 50013, 'Product out of stock (including items already in your cart)!', 1;

    -- Get/Create Cart
    SELECT @v_cart_id = id FROM carts WHERE user_id = @p_user_id;

    IF @v_cart_id IS NULL
    BEGIN
        INSERT INTO carts (user_id) VALUES (@p_user_id);
        SET @v_cart_id = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE carts SET updated_at = GETDATE() WHERE id = @v_cart_id;
    END

    -- Upsert Item using MERGE
    MERGE cart_items AS target
    USING (SELECT @v_cart_id, @p_variant_id) AS source (cart_id, variant_id)
    ON (target.cart_id = source.cart_id AND target.variant_id = source.variant_id)
    WHEN MATCHED THEN
        UPDATE SET quantity = target.quantity + @p_quantity
    WHEN NOT MATCHED THEN
        INSERT (cart_id, variant_id, quantity)
        VALUES (@v_cart_id, @p_variant_id, @p_quantity);

    SELECT 'SUCCESS: Item added to cart.' AS result;
END;
GO

-- 3.2. Update item quantity
CREATE OR ALTER PROCEDURE cart_update_item_quantity
    @p_user_id INT,
    @p_variant_id INT,
    @p_new_quantity INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_cart_id INT, @v_stock INT;

    SELECT @v_cart_id = id FROM carts WHERE user_id = @p_user_id;
    IF @v_cart_id IS NULL THROW 50014, 'Cart not exists.', 1;

    IF @p_new_quantity <= 0
    BEGIN
        DELETE FROM cart_items WHERE cart_id = @v_cart_id AND variant_id = @p_variant_id;
        SELECT 'SUCCESS: Delete item from cart.' AS result;
        RETURN;
    END

    SELECT @v_stock = stock FROM product_variants WHERE id = @p_variant_id;
    IF @p_new_quantity > @v_stock THROW 50015, 'Product out of stock.', 1;

    UPDATE cart_items 
    SET quantity = @p_new_quantity
    WHERE cart_id = @v_cart_id AND variant_id = @p_variant_id;

    IF @@ROWCOUNT = 0 THROW 50016, 'Item not in cart yet.', 1;

    SELECT 'SUCCESS: Updated new quantity.' AS result;
END;
GO

-- 3.3. Remove item
CREATE OR ALTER PROCEDURE cart_remove_item
    @p_user_id INT,
    @p_variant_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_cart_id INT;

    SELECT @v_cart_id = id FROM carts WHERE user_id = @p_user_id;
    IF @v_cart_id IS NULL THROW 50017, 'User does not have a cart.', 1;

    DELETE FROM cart_items 
    WHERE cart_id = @v_cart_id AND variant_id = @p_variant_id;

    IF @@ROWCOUNT = 0 THROW 50018, 'Item not in cart to delete.', 1;

    SELECT 'SUCCESS: Delete item from cart.' AS result;
END;
GO

-- 3.4. View Cart
CREATE OR ALTER PROCEDURE cart_view_details
    @p_user_id INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        ci.variant_id,
        p.name as product_name,
        p.thumbnail,
        p.price,
        pv.color,
        pv.size,
        ci.quantity,
        (p.price * ci.quantity) as subtotal,
        pv.stock as stock_available,
        p.is_active
    FROM cart_items ci
    JOIN carts c ON ci.cart_id = c.id
    JOIN product_variants pv ON ci.variant_id = pv.id
    JOIN products p ON pv.product_id = p.id
    WHERE c.user_id = @p_user_id
    ORDER BY ci.id DESC;
END;
GO

-- 4. Checkout & Payment

-- 4.1. Collect Voucher
CREATE OR ALTER PROCEDURE collect_voucher
    @p_user_id INT,
    @p_voucher_code NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_voucher_id INT;

    SELECT @v_voucher_id = id
    FROM vouchers
    WHERE code = @p_voucher_code
      AND is_active = 1
      AND stock > 0
      AND GETDATE() BETWEEN start_date AND end_date;

    IF @v_voucher_id IS NULL THROW 50019, 'Voucher code invalid/expired/out of stock', 1;

    IF EXISTS (SELECT 1 FROM user_vouchers WHERE user_id = @p_user_id AND voucher_id = @v_voucher_id)
        THROW 50020, 'You have already collected this voucher.', 1;

    INSERT INTO user_vouchers (user_id, voucher_id, is_used)
    VALUES (@p_user_id, @v_voucher_id, 0);

    SELECT 'SUCCESS: Voucher collected.' AS result;
END;
GO

-- 4.2. View Owned Vouchers
CREATE OR ALTER PROCEDURE view_my_vouchers
    @p_user_id INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        v.id as voucher_id,
        v.code,
        v.value,
        v.type,
        v.end_date,
        CASE 
            WHEN v.end_date < GETDATE() THEN 'EXPIRED'
            WHEN v.stock <= 0 THEN 'OUT_OF_STOCK'
            ELSE 'READY'
        END AS status
    FROM user_vouchers uv
    JOIN vouchers v ON uv.voucher_id = v.id
    WHERE uv.user_id = @p_user_id
      AND uv.is_used = 0
    ORDER BY v.end_date ASC;
END;
GO

-- 4.3. Checkout (Complex Transaction)
CREATE OR ALTER PROCEDURE checkout
    @p_user_id INT,
    @p_address_id INT,
    @p_payment_method_id INT,
    @p_voucher_id INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON; -- Rollback immediately on error

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @v_cart_id INT;
        DECLARE @v_address_snapshot NVARCHAR(MAX);
        DECLARE @v_payment_name NVARCHAR(50);
        
        DECLARE @v_total_amount DECIMAL(10,2) = 0;
        DECLARE @v_shipping_fee DECIMAL(10,2) = 15000.00;
        DECLARE @v_discount_amount DECIMAL(10,2) = 0;
        DECLARE @v_final_amount DECIMAL(10,2);
        DECLARE @v_new_order_id INT;

        -- 1. Validate Address
        SELECT @v_address_snapshot = CONCAT(recipient_name, ', ', detail, ', ', ward, ', ', district, ', ', city, ' - Tel: ', phone)
        FROM addresses
        WHERE id = @p_address_id AND user_id = @p_user_id;

        IF @v_address_snapshot IS NULL THROW 50021, 'Invalid Address!', 1;

        -- 2. Validate Payment
        SELECT @v_payment_name = name FROM payment_methods WHERE id = @p_payment_method_id AND is_active = 1;
        IF @v_payment_name IS NULL THROW 50022, 'Invalid Payment Method!', 1;

        -- 3. Get Cart
        SELECT @v_cart_id = id FROM carts WHERE user_id = @p_user_id; -- Add WITH (UPDLOCK) if strict concurrency needed
        IF @v_cart_id IS NULL THROW 50023, 'Cart not found!', 1;

        IF NOT EXISTS (SELECT 1 FROM cart_items WHERE cart_id = @v_cart_id)
            THROW 50024, 'Cart is empty!', 1;

        -- 4. Stock Check & Total Calculation
        DECLARE @CartContent TABLE (
            variant_id INT, 
            quantity INT, 
            price DECIMAL(10,2),
            stock INT,
            is_active BIT
        );

        INSERT INTO @CartContent
        SELECT ci.variant_id, ci.quantity, p.price, pv.stock, p.is_active
        FROM cart_items ci
        JOIN product_variants pv ON ci.variant_id = pv.id
        JOIN products p ON pv.product_id = p.id
        WHERE ci.cart_id = @v_cart_id;

        -- Validate items
        IF EXISTS (SELECT 1 FROM @CartContent WHERE is_active = 0)
            THROW 50025, 'Some products are not valid for sale.', 1;
        
        IF EXISTS (SELECT 1 FROM @CartContent WHERE quantity > stock)
            THROW 50026, 'Some products are out of stock.', 1;

        SELECT @v_total_amount = SUM(quantity * price) FROM @CartContent;

        -- 5. Process Voucher
        IF @p_voucher_id IS NOT NULL
        BEGIN
            DECLARE @v_val DECIMAL(10,2), @v_type NVARCHAR(20), @v_uv_id INT;
            
            SELECT @v_val = v.value, @v_type = v.type, @v_uv_id = uv.id
            FROM vouchers v
            JOIN user_vouchers uv ON v.id = uv.voucher_id
            WHERE v.id = @p_voucher_id 
              AND uv.user_id = @p_user_id 
              AND uv.is_used = 0
              AND v.is_active = 1
              AND GETDATE() BETWEEN v.start_date AND v.end_date
              AND v.stock > 0;

            IF @v_val IS NULL THROW 50027, 'Voucher invalid or cannot apply.', 1;

            IF @v_type = 'PERCENTAGE'
                SET @v_discount_amount = @v_total_amount * (@v_val / 100);
            ELSE
                SET @v_discount_amount = @v_val;

            IF @v_discount_amount > @v_total_amount SET @v_discount_amount = @v_total_amount;
        END

        -- 6. Final Calculation
        SET @v_final_amount = @v_total_amount + @v_shipping_fee - @v_discount_amount;
        IF @v_final_amount < 0 SET @v_final_amount = 0;

        -- 7. Create Order
        INSERT INTO orders (
            user_id, shipping_address, payment_method, voucher_id,
            status, total_amount, shipping_fee, discount_amount, final_amount,
            payment_status, created_at
        ) VALUES (
            @p_user_id, @v_address_snapshot, @v_payment_name, @p_voucher_id,
            'PENDING', @v_total_amount, @v_shipping_fee, @v_discount_amount, @v_final_amount,
            'UNPAID', GETDATE()
        );
        SET @v_new_order_id = SCOPE_IDENTITY();

        -- 8. Save Order Items
        INSERT INTO order_items (order_id, variant_id, quantity, price)
        SELECT @v_new_order_id, variant_id, quantity, price FROM @CartContent;

        -- 9. Update Inventory
        UPDATE pv
        SET pv.stock = pv.stock - cc.quantity
        FROM product_variants pv
        JOIN @CartContent cc ON pv.id = cc.variant_id;

        -- 10. Update Voucher
        IF @p_voucher_id IS NOT NULL
        BEGIN
            UPDATE user_vouchers SET is_used = 1, claimed_at = GETDATE() WHERE id = @v_uv_id;
            UPDATE vouchers SET stock = stock - 1, used_count = used_count + 1 WHERE id = @p_voucher_id;
        END

        -- 11. Clear Cart
        DELETE FROM cart_items WHERE cart_id = @v_cart_id;

        COMMIT TRANSACTION;

        SELECT 'SUCCESS' as status, @v_new_order_id as order_id, @v_final_amount as final_amount 
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 5. Order Tracking & Wishlist/Review

-- 5.1. View Order History
CREATE OR ALTER PROCEDURE view_order_history
    @p_user_id INT
AS
BEGIN
    SELECT 
        o.id as order_id,
        o.shipping_address,
        o.payment_method,
        o.status,
        (SELECT COUNT(*) FROM order_items oi WHERE oi.order_id = o.id) AS total_items,
        o.final_amount,
        o.payment_status,
        o.created_at
    FROM orders o
    WHERE o.user_id = @p_user_id
    ORDER BY o.created_at DESC;
END;
GO

-- 5.2. Cancel Order
CREATE OR ALTER PROCEDURE cancel_order
    @p_user_id INT,
    @p_order_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
            
        DECLARE @v_current_status NVARCHAR(20);
        SELECT @v_current_status = status FROM orders WITH (UPDLOCK) WHERE id = @p_order_id AND user_id = @p_user_id;

        IF @v_current_status IS NULL THROW 50028, 'Order not found', 1;
        IF @v_current_status <> 'PENDING' THROW 50029, 'Cannot cancel non-pending order', 1;

        UPDATE orders SET status = 'CANCELLED', updated_at = GETDATE() WHERE id = @p_order_id;

        -- Restock
        UPDATE pv
        SET pv.stock = pv.stock + oi.quantity
        FROM product_variants pv
        JOIN order_items oi ON pv.id = oi.variant_id
        WHERE oi.order_id = @p_order_id;

        -- Restore Voucher Credit
        UPDATE v
        SET v.stock = v.stock + 1, v.used_count = v.used_count - 1
        FROM vouchers v
        JOIN orders o ON o.voucher_id = v.id
        WHERE o.id = @p_order_id;

        -- NEW: Restore User Voucher Usage (Reset is_used to 0)
        UPDATE uv
        SET uv.is_used = 0
        FROM user_vouchers uv
        JOIN orders o ON o.user_id = uv.user_id AND o.voucher_id = uv.voucher_id
        WHERE o.id = @p_order_id;

        COMMIT TRANSACTION;
        SELECT 'SUCCESS: Order cancelled.' AS result;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 6.1 View Wishlist
CREATE OR ALTER PROCEDURE view_wishlist
    @p_user_id INT
AS
BEGIN
    SELECT 
        pv.id AS variant_id,
        p.name AS product_name,
        p.thumbnail,
        p.price,
        pv.color,
        pv.size,
        pv.stock
    FROM user_favorites uf
    JOIN product_variants pv ON uf.variant_id = pv.id
    JOIN products p ON pv.product_id = p.id
    WHERE uf.user_id = @p_user_id;
END;
GO

-- 6.2 Add to Wishlist
CREATE OR ALTER PROCEDURE add_to_wishlist
    @p_user_id INT,
    @p_variant_id INT
AS
BEGIN
    IF NOT EXISTS (SELECT 1 FROM product_variants WHERE id = @p_variant_id)
        THROW 50030, 'Variant not found', 1;

    IF NOT EXISTS (SELECT 1 FROM user_favorites WHERE user_id = @p_user_id AND variant_id = @p_variant_id)
    BEGIN
        INSERT INTO user_favorites (user_id, variant_id) VALUES (@p_user_id, @p_variant_id);
    END
    SELECT 'SUCCESS: Added to wishlist.' AS result;
END;
GO

-- 6.3 Remove from Wishlist
CREATE OR ALTER PROCEDURE remove_from_wishlist
    @p_user_id INT,
    @p_variant_id INT
AS
BEGIN
    DELETE FROM user_favorites WHERE user_id = @p_user_id AND variant_id = @p_variant_id;
    SELECT 'SUCCESS: Removed from wishlist.' AS result;
END;
GO

-- 7. Reviews & Support (Simplified)
CREATE OR ALTER PROCEDURE submit_product_review
    @p_user_id INT,
    @p_product_id INT,
    @p_rating INT,
    @p_comment NVARCHAR(MAX)
AS
BEGIN
    IF @p_rating < 1 OR @p_rating > 5 THROW 50031, 'Rating 1-5', 1;

    -- Verify Purchase
    IF NOT EXISTS (
        SELECT 1 FROM order_items oi
        JOIN orders o ON oi.order_id = o.id
        JOIN product_variants pv ON oi.variant_id = pv.id
        WHERE o.user_id = @p_user_id AND pv.product_id = @p_product_id AND o.status = 'COMPLETED'
    ) THROW 50032, 'You must purchase this product first.', 1;

    INSERT INTO reviews (user_id, product_id, rating, comment, created_at)
    VALUES (@p_user_id, @p_product_id, @p_rating, @p_comment, GETDATE());

    -- Update Product Stats
    UPDATE products
    SET rating = (SELECT AVG(CAST(rating AS FLOAT)) FROM reviews WHERE product_id = @p_product_id),
        review_count = (SELECT COUNT(*) FROM reviews WHERE product_id = @p_product_id)
    WHERE id = @p_product_id;

    SELECT 'SUCCESS: Review submitted.' AS result;
END;
GO

CREATE OR ALTER PROCEDURE send_support_message
    @p_user_id INT,
    @p_content NVARCHAR(MAX)
AS
BEGIN
    INSERT INTO support_messages (user_id, content, status, created_at)
    VALUES (@p_user_id, @p_content, 'OPEN', GETDATE());
    
    SELECT 'SUCCESS: Message sent.' AS result;
END;
GO
-- 6.4 Add Address
CREATE OR ALTER PROCEDURE add_address
    @p_user_id INT,
    @p_recipient_name NVARCHAR(100),
    @p_phone NVARCHAR(20),
    @p_city NVARCHAR(100),
    @p_district NVARCHAR(100) = NULL,
    @p_ward NVARCHAR(100) = NULL,
    @p_detail NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @v_is_default BIT = 0;
    
    -- If user has no address, set this as default
    IF NOT EXISTS (SELECT 1 FROM addresses WHERE user_id = @p_user_id)
    BEGIN
        SET @v_is_default = 1;
    END

    INSERT INTO addresses (user_id, recipient_name, phone, city, district, ward, detail, is_default)
    VALUES (@p_user_id, @p_recipient_name, @p_phone, @p_city, @p_district, @p_ward, @p_detail, @v_is_default);


    SELECT 'SUCCESS: Address added.' as result;
END;
GO

-- 6.5 Get My Addresses
CREATE OR ALTER PROCEDURE get_my_addresses
    @p_user_id INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        id as address_id,
        recipient_name,
        phone,
        city,
        district,
        ward,
        detail,
        is_default
    FROM addresses
    WHERE user_id = @p_user_id
    ORDER BY is_default DESC, id DESC;
END;
GO

-- 6.6 Update Address
CREATE OR ALTER PROCEDURE update_address
    @p_address_id INT,
    @p_user_id INT,
    @p_recipient_name NVARCHAR(100) = NULL,
    @p_phone NVARCHAR(20) = NULL,
    @p_city NVARCHAR(100) = NULL,
    @p_district NVARCHAR(100) = NULL,
    @p_ward NVARCHAR(100) = NULL,
    @p_detail NVARCHAR(MAX) = NULL,
    @p_is_default BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE addresses
    SET recipient_name = ISNULL(@p_recipient_name, recipient_name),
        phone = ISNULL(@p_phone, phone),
        city = ISNULL(@p_city, city),
        district = ISNULL(@p_district, district),
        ward = ISNULL(@p_ward, ward),
        detail = ISNULL(@p_detail, detail),
        is_default = ISNULL(@p_is_default, is_default)
    WHERE id = @p_address_id AND user_id = @p_user_id;

    IF @@ROWCOUNT = 0 THROW 50033, 'Address not found or unauthorized.', 1;

    -- If set to default, unset others
    IF @p_is_default = 1
    BEGIN
        UPDATE addresses 
        SET is_default = 0 
        WHERE user_id = @p_user_id AND id <> @p_address_id;
    END

    SELECT 'SUCCESS: Address updated.' AS result;
END;
GO

-- 6.7 Delete Address
CREATE OR ALTER PROCEDURE delete_address
    @p_address_id INT,
    @p_user_id INT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM addresses WHERE id = @p_address_id AND user_id = @p_user_id;

    IF @@ROWCOUNT = 0 THROW 50034, 'Address not found or unauthorized.', 1;

    SELECT 'SUCCESS: Address deleted.' AS result;
END;
GO
