CREATE DATABASE ECommerceDBDemo5;
GO
USE ECommerceDBDemo5;
GO


-- 1. Users Table
CREATE TABLE users (
    id INT IDENTITY(1,1) PRIMARY KEY,
    email NVARCHAR(255) UNIQUE NOT NULL,
    password NVARCHAR(MAX) NOT NULL,
    name NVARCHAR(100),
    phone NVARCHAR(20),
    role NVARCHAR(20) DEFAULT 'CUSTOMER',
    avatar NVARCHAR(MAX),
    created_at DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT CK_Users_Role CHECK (role IN ('CUSTOMER', 'ADMIN'))
);

-- 2. Payment Methods
CREATE TABLE payment_methods (
    id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    code NVARCHAR(50) UNIQUE NOT NULL,
    description NVARCHAR(MAX),
    image NVARCHAR(MAX),
    is_active BIT DEFAULT 1
);

-- 3. User Payments
CREATE TABLE user_payments (
    id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL,
    payment_method_id INT NOT NULL,
    provider NVARCHAR(50),
    account_number NVARCHAR(50) NOT NULL,
    expiry_date NVARCHAR(20),
    is_default BIT DEFAULT 0,
    created_at DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id)
);

-- 4. Addresses
CREATE TABLE addresses (
    id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL,
    recipient_name NVARCHAR(100) NOT NULL,
    phone NVARCHAR(20) NOT NULL,
    city NVARCHAR(100) NOT NULL,
    district NVARCHAR(100),
    ward NVARCHAR(100),
    detail NVARCHAR(MAX) NOT NULL,
    is_default BIT DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 5. Categories
CREATE TABLE categories (
    id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    slug NVARCHAR(100) UNIQUE NOT NULL,
    image NVARCHAR(MAX),
    parent_id INT,
    FOREIGN KEY (parent_id) REFERENCES categories(id)
);

-- 6. Products
CREATE TABLE products (
    id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(200) NOT NULL,
    slug NVARCHAR(200) UNIQUE NOT NULL,
    description NVARCHAR(MAX),
    thumbnail NVARCHAR(MAX),
    original_price DECIMAL(10,2) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    is_active BIT DEFAULT 1,
    rating FLOAT DEFAULT 0,
    review_count INT DEFAULT 0,
    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE()
);

-- 7. Product Variants
CREATE TABLE product_variants (
    id INT IDENTITY(1,1) PRIMARY KEY,
    product_id INT NOT NULL,
    color NVARCHAR(50) NOT NULL,
    size NVARCHAR(50) NOT NULL,
    sku NVARCHAR(100) UNIQUE,
    image NVARCHAR(MAX),
    stock INT DEFAULT 0,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    CONSTRAINT UQ_Product_Color_Size UNIQUE (product_id, color, size)
);

-- 8. Product Categories (Many-to-Many)
CREATE TABLE product_categories (
    product_id INT NOT NULL,
    category_id INT NOT NULL,
    PRIMARY KEY (product_id, category_id),
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
);

-- 9. Carts
CREATE TABLE carts (
    id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT UNIQUE NOT NULL,
    updated_at DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 10. Cart Items
CREATE TABLE cart_items (
    id INT IDENTITY(1,1) PRIMARY KEY,
    cart_id INT NOT NULL,
    variant_id INT NOT NULL,
    quantity INT NOT NULL,
    FOREIGN KEY (cart_id) REFERENCES carts(id) ON DELETE CASCADE,
    FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE CASCADE,
    CONSTRAINT UQ_Cart_Variant UNIQUE (cart_id, variant_id)
);

-- 11. Vouchers
CREATE TABLE vouchers (
    id INT IDENTITY(1,1) PRIMARY KEY,
    code NVARCHAR(50) UNIQUE NOT NULL,
    value DECIMAL(10,2) NOT NULL,
    type NVARCHAR(20) DEFAULT 'FIXED',
    stock INT DEFAULT 0,
    used_count INT DEFAULT 0,
    start_date DATETIME2 NOT NULL,
    end_date DATETIME2 NOT NULL,
    is_active BIT DEFAULT 1
);

-- 12. Orders
CREATE TABLE orders (
    id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL,
    shipping_address NVARCHAR(MAX) NOT NULL,
    payment_method NVARCHAR(50) NOT NULL,
    voucher_id INT,
    status NVARCHAR(20) DEFAULT 'PENDING',
    total_amount DECIMAL(10,2) NOT NULL,
    shipping_fee DECIMAL(10,2) DEFAULT 0,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    final_amount DECIMAL(10,2) NOT NULL,
    payment_status NVARCHAR(20) DEFAULT 'UNPAID',
    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (user_id) REFERENCES users(id), 
    FOREIGN KEY (voucher_id) REFERENCES vouchers(id),
    CONSTRAINT CK_Order_Status CHECK (status IN ('PENDING', 'CONFIRMED', 'SHIPPING', 'COMPLETED', 'CANCELLED', 'RETURNED')),
    CONSTRAINT CK_Payment_Status CHECK (payment_status IN ('PAID', 'UNPAID', 'REFUNDED'))
);

-- 13. Order Items
CREATE TABLE order_items (
    id INT IDENTITY(1,1) PRIMARY KEY,
    order_id INT NOT NULL,
    variant_id INT NOT NULL,
    quantity INT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (variant_id) REFERENCES product_variants(id), 
    CONSTRAINT UQ_Order_Variant UNIQUE (order_id, variant_id)
);

-- 14. User Vouchers
CREATE TABLE user_vouchers (
    id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL,
    voucher_id INT NOT NULL,
    is_used BIT DEFAULT 0,
    claimed_at DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (voucher_id) REFERENCES vouchers(id) ON DELETE CASCADE,
    CONSTRAINT UQ_User_Voucher UNIQUE (user_id, voucher_id)
);

-- 15. User Favorites (Wishlist)
CREATE TABLE user_favorites (
    user_id INT NOT NULL,
    variant_id INT NOT NULL,
    PRIMARY KEY (user_id, variant_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE CASCADE
);

-- 16. Reviews
CREATE TABLE reviews (
    id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL,
    product_id INT NOT NULL,
    rating INT NOT NULL,
    comment NVARCHAR(MAX),
    created_at DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (user_id) REFERENCES users(id), 
    FOREIGN KEY (product_id) REFERENCES products(id)
);

-- 17. Support Messages
CREATE TABLE support_messages (
    id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL,
    content NVARCHAR(MAX) NOT NULL,
    status NVARCHAR(20) DEFAULT 'OPEN',
    created_at DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- 18. Banners
CREATE TABLE banners (
    id INT IDENTITY(1,1) PRIMARY KEY,
    title NVARCHAR(200),
    image_url NVARCHAR(MAX) NOT NULL,
    link_url NVARCHAR(MAX),
    display_order INT DEFAULT 0,
    is_active BIT DEFAULT 1,
    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE()
);
