USE ECommerceDBDemo5;
GO
-- 1. Insert Users
INSERT INTO users (email, password, name, phone, role, avatar) VALUES 
('admin@store.com', 'hashed_pass_admin', 'Admin User', '0901234567', 'ADMIN', 'https://ui-avatars.com/api/?name=Admin'),
('customer1@gmail.com', 'hashed_pass_1', 'John Doe', '0912345678', 'CUSTOMER', 'https://ui-avatars.com/api/?name=John+Doe'),
('customer2@gmail.com', 'hashed_pass_2', 'Jane Smith', '0923456789', 'CUSTOMER', 'https://ui-avatars.com/api/?name=Jane+Smith');

-- 2. Insert Payment Methods
INSERT INTO payment_methods (name, code, description, image, is_active) VALUES 
('Credit Card', 'CC', 'Visa/Mastercard', 'https://example.com/cc.png', 1),
('Cash on Delivery', 'COD', 'Pay upon receipt', 'https://example.com/cod.png', 1),
('E-Wallet', 'MOMO', 'Momo Wallet', 'https://example.com/momo.png', 1);

-- 3. Insert Addresses
INSERT INTO addresses (user_id, recipient_name, phone, city, district, ward, detail, is_default) VALUES 
(2, 'John Doe', '0912345678', 'Ho Chi Minh', 'District 1', 'Ben Nghe', '123 Le Loi St', 1),
(2, 'John Wife', '0911111111', 'Ho Chi Minh', 'District 7', 'Tan Phong', '456 Nguyen Van Linh', 0),
(3, 'Jane Smith', '0923456789', 'Ha Noi', 'Ba Dinh', 'Kim Ma', '789 Kim Ma St', 1);

-- 4. Insert Categories
SET IDENTITY_INSERT categories ON;
INSERT INTO categories (id, name, slug, parent_id) VALUES 
(1, 'Men', 'men', NULL),
(2, 'Women', 'women', NULL),
(3, 'Accessories', 'accessories', NULL),
(4, 'T-Shirts', 'men-tshirts', 1),
(5, 'Dresses', 'women-dresses', 2);
SET IDENTITY_INSERT categories OFF;

-- 5. Insert Products
SET IDENTITY_INSERT products ON;
INSERT INTO products (id, name, slug, description, original_price, price, thumbnail, is_active, rating, review_count) VALUES 
(1, 'Classic White T-Shirt', 'classic-white-tshirt', 'Premium cotton t-shirt', 200000, 150000, 'https://isto.pt/cdn/shop/files/Classic_TShirt_White_2.webp?v=1765458167', 1, 4.5, 2),
(2, 'Summer Floral Dress', 'summer-floral-dress', 'Lightweight summer dress', 500000, 450000, 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTpEpTdC1_Rb9LwH6vDM-T_MlQ3kmYp7TYotw&s', 1, 5.0, 1),
(3, 'Leather Belt', 'leather-belt', 'Genuine leather belt', 300000, 250000, 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTf-EoB9COi9CA7DVoSCsQ6QQ8TPwAo_FXcAw&s', 1, 0, 0),
(4, 'Discontinued Jacket', 'old-jacket', 'Old winter collection', 1000000, 500000, 'https://example.com/jacket.jpg', 0, 0, 0); -- Inactive
SET IDENTITY_INSERT products OFF;

-- 6. Insert Product Categories
INSERT INTO product_categories (product_id, category_id) VALUES 
(1, 1), (1, 4), -- T-Shirt -> Men, T-Shirts
(2, 2), (2, 5), -- Dress -> Women, Dresses
(3, 3),         -- Belt -> Accessories
(4, 1);

-- 7. Insert Product Variants
INSERT INTO product_variants (product_id, color, size, sku, stock, image) VALUES 
-- T-Shirt
(1, 'White', 'M', 'TS-WHT-M', 100, NULL),
(1, 'White', 'L', 'TS-WHT-L', 50, NULL),
(1, 'Black', 'M', 'TS-BLK-M', 0, NULL), -- Out of stock
-- Dress
(2, 'Red', 'S', 'DR-RED-S', 20, NULL),
(2, 'Red', 'M', 'DR-RED-M', 20, NULL),
-- Belt
(3, 'Brown', 'OneSize', 'BLT-BRN', 15, NULL);

-- 8. Insert Vouchers
INSERT INTO vouchers (code, value, type, stock, start_date, end_date, is_active) VALUES 
('WELCOME50', 50000, 'FIXED', 100, GETDATE(), DATEADD(day, 30, GETDATE()), 1),
('SUMMER10', 10, 'PERCENTAGE', 50, GETDATE(), DATEADD(day, 7, GETDATE()), 1),
('EXPIRED2025', 20000, 'FIXED', 10, DATEADD(year, -1, GETDATE()), DATEADD(month, -1, GETDATE()), 1);

-- 9. Insert Banners
INSERT INTO banners (title, image_url, link_url, display_order) VALUES 
('New Arrival', 'https://example.com/banner1.jpg', '/new-arrival', 1),
('Free Shipping', 'https://example.com/banner2.jpg', '/policy', 2);

-- 10. Insert Orders (Past History)
-- Order 1: Completed (User 2)
INSERT INTO orders (user_id, shipping_address, payment_method, status, total_amount, final_amount, payment_status, created_at) VALUES 
(2, '123 Le Loi St, HCM', 'COD', 'COMPLETED', 150000, 150000, 'PAID', DATEADD(day, -10, GETDATE()));

DECLARE @order1_id INT = SCOPE_IDENTITY();
INSERT INTO order_items (order_id, variant_id, quantity, price) VALUES 
(@order1_id, 1, 1, 150000); -- 1x White T-Shirt M

-- Order 2: Pending (User 2)
INSERT INTO orders (user_id, shipping_address, payment_method, status, total_amount, final_amount, payment_status, created_at) VALUES 
(2, '123 Le Loi St, HCM', 'E-Wallet', 'PENDING', 450000, 450000, 'UNPAID', GETDATE());

DECLARE @order2_id INT = SCOPE_IDENTITY();
INSERT INTO order_items (order_id, variant_id, quantity, price) VALUES 
(@order2_id, 4, 1, 450000); -- 1x Red Dress S

-- 11. Insert Reviews (Must correspond to completed orders)
INSERT INTO reviews (user_id, product_id, rating, comment, created_at) VALUES 
(2, 1, 5, 'Great t-shirt!', DATEADD(day, -5, GETDATE()));

-- 12. Insert Wishlist
INSERT INTO user_favorites (user_id, variant_id) VALUES 
(2, 4); -- User 2 likes Red Dress S

-- 13. Insert Carts (User 3 has items in cart)
INSERT INTO carts (user_id) VALUES (3);
DECLARE @cart_id INT = SCOPE_IDENTITY();
INSERT INTO cart_items (cart_id, variant_id, quantity) VALUES 
(@cart_id, 2, 2); -- 2x White T-Shirt L

-- 14. Support Messages
INSERT INTO support_messages (user_id, content, status) VALUES 
(2, 'When will my pending order ship?', 'OPEN');

PRINT 'Data insertion completed successfully!';
