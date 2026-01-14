USE ECommerceDBDemo5;
GO

-- 2.1. CUSTOMER FEATURES OPTIMIZATION

-- Optimize: Browse Products (Newest & Active)
CREATE NONCLUSTERED INDEX idx_products_active_newest 
ON products(is_active, created_at DESC) 
INCLUDE (name, price, thumbnail, rating, review_count); 
GO

-- Optimize: Browse Products (Filter by Category)
CREATE NONCLUSTERED INDEX idx_product_categories_category_id 
ON product_categories(category_id) 
INCLUDE (product_id);
GO

-- Optimize: Browse Products (Filter by Price)
IF NOT EXISTS(SELECT * FROM sys.indexes WHERE name = 'idx_products_price' AND object_id = OBJECT_ID('products'))
BEGIN
    CREATE NONCLUSTERED INDEX idx_products_price 
    ON products(price) 
    INCLUDE (name, thumbnail);
END
GO

-- Optimize: Search Products by Name
IF NOT EXISTS(SELECT * FROM sys.indexes WHERE name = 'idx_products_name' AND object_id = OBJECT_ID('products'))
BEGIN
    CREATE NONCLUSTERED INDEX idx_products_name 
    ON products(name);
END
GO

-- Optimize: Product Detail (Variant Lookup)
CREATE NONCLUSTERED INDEX idx_product_variants_product 
ON product_variants(product_id) 
INCLUDE (color, size, stock, image);
GO

-- Optimize: Product Detail (Reviews)
CREATE NONCLUSTERED INDEX idx_reviews_product_created 
ON reviews(product_id, created_at DESC) 
INCLUDE (rating, comment, user_id);
GO

-- Optimize: "My Orders" History
CREATE NONCLUSTERED INDEX idx_orders_user_created 
ON orders(user_id, created_at DESC) 
INCLUDE (status, total_amount, final_amount, payment_status);
GO

-- Optimize: Cart View
CREATE NONCLUSTERED INDEX idx_cart_items_cart_id 
ON cart_items(cart_id) 
INCLUDE (variant_id, quantity);
GO


-- 2.2. ADMIN FEATURES OPTIMIZATION

-- Optimize: Admin Reports (Revenue & Best Sellers by Date)
CREATE NONCLUSTERED INDEX idx_orders_created_at 
ON orders(created_at) 
INCLUDE (status, final_amount);
GO

-- Optimize: Admin Order Management (Filter by Status)
CREATE NONCLUSTERED INDEX idx_orders_status 
ON orders(status) 
INCLUDE (user_id, total_amount, created_at);
GO

-- Optimize: Admin Support
CREATE NONCLUSTERED INDEX idx_support_messages_user 
ON support_messages(user_id) 
INCLUDE (content, status, created_at);
GO

-- Optimize: Revenue by Category Report
CREATE NONCLUSTERED INDEX idx_product_categories_cat 
ON product_categories(category_id) 
INCLUDE (product_id);
GO

-- Optimize: Best Sellers Report (Variant aggregation)
CREATE NONCLUSTERED INDEX idx_order_items_variant_id 
ON order_items(variant_id) 
INCLUDE (quantity, price);
GO
