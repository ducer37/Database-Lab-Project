const express = require('express');
const sql = require('mssql');
const path = require('path');
require('dotenv').config();

const app = express();

// --- DATABASE CONFIGURATION ---
const dbConfig = {
    user: process.env.DB_USER,
    password: process.env.DB_PASS,
    server: process.env.DB_SERVER,
    database: process.env.DB_NAME,
    port: parseInt(process.env.DB_PORT) || 1434, // Default SQL Server port is 1433, but custom might be 1434
    options: {
        encrypt: true, 
        trustServerCertificate: true // For local dev
    }
};

// Global DB Connection Pool
let pool;

const connectDB = async () => {
    try {
        pool = await sql.connect(dbConfig);
        console.log("✅ SQL Server Connected!");
    } catch (err) {
        console.error("❌ Database Connection Failed:", err.message);
        // Do not exit, keep trying or let the user fix .env
    }
};

// Initial Connection
connectDB();

// --- MIDDLEWARE ---
// Inject 'sql' into every request so we can use req.sql.query(...)
app.use((req, res, next) => {
    req.sql = sql; 
    req.pool = pool;
    next();
});

app.use(express.urlencoded({ extended: true })); 
app.use(express.json());
app.use(express.static(path.join(__dirname, '../public'))); // Correct static path relative to src

// --- VIEW ENGINE ---
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// --- ROUTES ---

// 1. Home / Dashboard
app.get('/', (req, res) => {
    res.render('layout', {
        title: 'E-Commerce Lab',
        body: `
            <div class="text-center">
                <h1>Welcome to E-Commerce DB Lab</h1>
                <p class="lead">Manual Testing Dashboard for SQL Server Stored Procedures.</p>
                
                <div class="mt-4">
                    <p>Status: <span class="badge ${pool && pool.connected ? 'bg-success' : 'bg-danger'}">
                        ${pool && pool.connected ? 'Database Connected' : 'Database Disconnected'}
                    </span></p>
                </div>

                <div class="row mt-5">
                    <div class="col-md-4">
                        <div class="card p-3">
                            <h3>🛒 Customers</h3>
                            <a href="/products" class="btn btn-primary">Browse Products</a>
                            <a href="/login" class="btn btn-outline-primary mt-2">Login / Register</a>
                        </div>
                    </div>
                     <div class="col-md-4">
                        <div class="card p-3">
                            <h3>🛍️ Order</h3>
                            <a href="/cart" class="btn btn-success">My Cart</a>
                            <a href="/orders" class="btn btn-outline-success mt-2">Order History</a>
                        </div>
                    </div>
                    <div class="col-md-4">
                        <div class="card p-3">
                            <h3>🛠️ Admin</h3>
                            <a href="/admin/products" class="btn btn-warning">Manage Products</a>
                            <a href="/admin/reports" class="btn btn-outline-warning mt-2">View Reports</a>
                        </div>
                    </div>
                </div>
            </div>
        `
    });
});

// 2. Browse Products (Filter)
app.get('/products', async (req, res) => {
    try {
        const pool = req.pool;
        if (!pool) throw new Error("Database not connected");

        const q = req.query;

        // Call SP: browse_products
        const result = await pool.request()
            .input('p_keyword', sql.NVarChar, q.keyword || null)
            .input('p_category_slug', sql.NVarChar, q.category_slug || null)
            .input('p_min_price', sql.Decimal, q.min_price || 0)
            .input('p_max_price', sql.Decimal, q.max_price || 999999999)
            .input('p_sort_by', sql.NVarChar, q.sort_by || 'newest')
            .input('p_limit', sql.Int, 20)
            .input('p_offset', sql.Int, 0)
            .execute('browse_products');

        res.render('layout', {
            title: 'Products',
            body: await ejsBody('products', { 
                products: result.recordset,
                query: q
            })
        });

    } catch (err) {
        console.error(err);
        res.send("Error: " + err.message);
    }
});

// Helper to render body partial
async function ejsBody(view, data) {
    return new Promise((resolve, reject) => {
        app.render(view, data, (err, str) => {
            if (err) reject(err);
            else resolve(str);
        });
    });
}

// Product Detail Route
app.get('/product/:id', async (req, res) => {
    try {
        const result = await req.pool.request()
            .input('p_product_id', sql.Int, req.params.id)
            .execute('get_product_details');
        
        // Parse the complex JSON result
        const jsonStr = Object.values(result.recordset[0])[0];
        const data = JSON.parse(jsonStr);

        res.render('layout', {
            title: data.info.name,
            body: await ejsBody('product_detail', { 
                info: data.info, 
                variants: data.variants, 
                reviews: data.latest_reviews 
            })
        });

    } catch (err) {
        res.send("Error: " + err.message);
    }
});

// 1.3 Update Profile (New)
app.post('/profile/update', async (req, res) => {
    try {
        await req.pool.request()
            .input('p_user_id', sql.Int, req.body.user_id)
            .input('p_name', sql.NVarChar, req.body.name || null)
            .input('p_phone', sql.NVarChar, req.body.phone || null)
            .input('p_password', sql.NVarChar, req.body.password || null)
            .input('p_avatar', sql.NVarChar, req.body.avatar || null)
            .execute('update_profile');

        res.render('layout', {
            title: 'Profile Updated',
            body: `
                <div class="alert alert-success text-center">
                    <h3>✅ Profile Updated Successfully!</h3>
                    <p>User ID: <strong>${req.body.user_id}</strong> has been updated.</p>
                    <a href="/" class="btn btn-primary">Back to Login</a>
                </div>
            `
        });
    } catch (err) {
        res.render('layout', { title: 'Update Failed', body: `<div class="alert alert-danger">${err.message}</div>` });
    }
});

// 3. Auth Routes
app.get('/login', async (req, res) => {
    try {
        res.render('layout', { title: 'Login', body: await ejsBody('login', { userId: undefined }) });
    } catch (err) {
        res.send("Error: " + err.message);
    }
});

app.post('/register', async (req, res) => {
    try {
        const pool = req.pool;
        const result = await pool.request()
            .input('p_email', sql.NVarChar, req.body.email)
            .input('p_password', sql.NVarChar, req.body.password)
            .input('p_name', sql.NVarChar, req.body.name)
            .input('p_phone', sql.NVarChar, req.body.phone)
            .execute('register_user');

        // SP returns: "SUCCESS: Successfully register new account. User ID: 12"
        // Let's parse the ID after "User ID: "
        let newUserId = 'REGISTERED';
        const msg = Object.values(result.recordset[0])[0]; // Get the first column value
        
        const match = msg.match(/User ID:\s*(\d+)/);
        if (match && match[1]) {
            newUserId = match[1];
        }

        res.render('layout', { title: 'Login', body: await ejsBody('login', { userId: newUserId, success: 'Registered Successfully! Copy your ID down below.' }) });

    } catch (err) {
        res.render('layout', { title: 'Login', body: await ejsBody('login', { userId: undefined, error: err.message }) });
    }
});

app.post('/login', async (req, res) => {
    try {
        const result = await req.pool.request()
            .input('p_email', sql.NVarChar, req.body.email)
            .input('p_password', sql.NVarChar, req.body.password)
            .execute('login_user');
        
        // Result is JSON string in column [0]
        const userJson = result.recordset[0]; 
        const key = Object.keys(userJson)[0];
        const userData = JSON.parse(userJson[key]);

        res.render('layout', { 
            title: 'Login Success', 
            body: await ejsBody('login', { 
                userId: userData.user_id,
                userName: userData.name,
                userEmail: userData.email,
                userRole: userData.role,
                userAvatar: userData.avatar,
                success: 'Logged In!' 
            }) 
        });

    } catch (err) {
        res.render('layout', { title: 'Login', body: await ejsBody('login', { userId: undefined, error: err.message }) });
    }
});

// 4. Cart & Checkout Routes
app.post('/cart/add', async (req, res) => {
    try {
        await req.pool.request()
            .input('p_user_id', sql.Int, req.body.user_id)
            .input('p_variant_id', sql.Int, req.body.variant_id)
            .input('p_quantity', sql.Int, req.body.quantity || 1)
            .execute('cart_add_item');
        
        // Redirect to cart
        res.redirect(`/cart?user_id=${req.body.user_id}`);
    } catch (err) {
        res.send(`Error adding to cart: ${err.message} <br> <a href="/products">Back</a>`);
    }
});

app.get('/cart', async (req, res) => {
    try {
        const userId = req.query.user_id;
        let items = [];
        
        if (userId) {
            const result = await req.pool.request()
                .input('p_user_id', sql.Int, userId)
                .execute('cart_view_details');
            items = result.recordset;
        }

        res.render('layout', { 
            title: 'My Cart', 
            body: await ejsBody('cart', { userId: userId, cartItems: items }) 
        });

    } catch (err) {
         res.render('layout', { title: 'My Cart', body: `Error: ${err.message}` });
    }
});

app.post('/cart/update', async (req, res) => {
    try {
        await req.pool.request()
            .input('p_user_id', sql.Int, req.body.user_id)
            .input('p_variant_id', sql.Int, req.body.variant_id)
            .input('p_new_quantity', sql.Int, req.body.quantity)
            .execute('cart_update_item_quantity');
        res.redirect(`/cart?user_id=${req.body.user_id}`);
    } catch (err) { 
        res.send(`Error updating cart: ${err.message} <br> <a href="/cart?user_id=${req.body.user_id}">Back</a>`); 
    }
});

app.post('/cart/remove', async (req, res) => {
    try {
        await req.pool.request()
            .input('p_user_id', sql.Int, req.body.user_id)
            .input('p_variant_id', sql.Int, req.body.variant_id)
            .execute('cart_remove_item');
        res.redirect(`/cart?user_id=${req.body.user_id}`);
    } catch (err) { res.send(err.message); }
});

app.post('/checkout', async (req, res) => {
    try {
        const voucherId = req.body.voucher_id ? parseInt(req.body.voucher_id) : null;
        
        const result = await req.pool.request()
            .input('p_user_id', sql.Int, req.body.user_id)
            .input('p_address_id', sql.Int, req.body.address_id)
            .input('p_payment_method_id', sql.Int, req.body.payment_method_id)
            .input('p_voucher_id', sql.Int, voucherId) // Pass NULL if empty
            .execute('checkout');

        // Parse result JSON
        const key = Object.keys(result.recordset[0])[0];
        const orderData = JSON.parse(result.recordset[0][key]);

        res.send(`
            <h1>✅ Order Placed Successfully!</h1>
            <h3>Order ID: ${orderData.order_id}</h3>
            <h3>Final Amount: ${orderData.final_amount}</h3>
            <a href="/">Back Home</a>
        `);

    } catch (err) {
        res.send(`❌ Checkout Failed: ${err.message}`);
    }
});
// 4. Addressbook Routes
app.get('/addresses', async (req, res) => {
    try {
        const userId = req.query.user_id;
        let addresses = [];
        if (userId) {
            const result = await req.pool.request()
                .input('p_user_id', sql.Int, userId)
                .execute('get_my_addresses');
            addresses = result.recordset;
        }
        res.render('layout', { 
            title: 'My Addresses', 
            body: await ejsBody('addresses', { userId, addresses }) 
        });
    } catch (err) { res.render('layout', { title: 'Address Error', body: err.message }); }
});

app.post('/addresses/add', async (req, res) => {
    try {
        await req.pool.request()
            .input('p_user_id', sql.Int, req.body.user_id)
            .input('p_recipient_name', sql.NVarChar, req.body.recipient_name)
            .input('p_phone', sql.NVarChar, req.body.phone)
            .input('p_city', sql.NVarChar, req.body.city)
            .input('p_district', sql.NVarChar, req.body.district)
            .input('p_detail', sql.NVarChar, req.body.detail)
            .execute('add_address');
        res.redirect(`/addresses?user_id=${req.body.user_id}`);
    } catch (err) { res.send(err.message); }
});

// NEW: Delete Address
app.post('/addresses/delete', async (req, res) => {
    try {
        await req.pool.request()
            .input('p_address_id', sql.Int, req.body.address_id)
            .input('p_user_id', sql.Int, req.body.user_id)
            .execute('delete_address');
        res.redirect(`/addresses?user_id=${req.body.user_id}`);
    } catch (err) { res.send(err.message); }
});

// NEW: Show Edit Address Page
app.get('/addresses/edit/:id', async (req, res) => {
    try {
        const userId = req.query.user_id;
        // Reuse get_my_addresses and filter in JS (Simple approach)
        const result = await req.pool.request()
            .input('p_user_id', sql.Int, userId)
            .execute('get_my_addresses');
            
        const address = result.recordset.find(a => a.address_id == req.params.id);
        
        if (!address) throw new Error('Address not found or unauthorized');

        res.render('layout', {
            title: 'Edit Address',
            body: await ejsBody('addresses_edit', { userId, address })
        });
    } catch (err) { res.send(err.message); }
});

// NEW: Update Address Action
app.post('/addresses/update', async (req, res) => {
    try {
        await req.pool.request()
            .input('p_address_id', sql.Int, req.body.address_id)
            .input('p_user_id', sql.Int, req.body.user_id)
            .input('p_recipient_name', sql.NVarChar, req.body.recipient_name)
            .input('p_phone', sql.NVarChar, req.body.phone)
            .input('p_city', sql.NVarChar, req.body.city)
            .input('p_district', sql.NVarChar, req.body.district)
            .input('p_detail', sql.NVarChar, req.body.detail)
            .input('p_is_default', sql.Bit, req.body.is_default ? 1 : 0)
            .execute('update_address');

        res.redirect(`/addresses?user_id=${req.body.user_id}`);
    } catch (err) { res.send(err.message); }
});

// 4.1 Voucher Routes
app.get('/vouchers', async (req, res) => {
    try {
        const userId = req.query.user_id;
        let vouchers = [];

        if (userId) {
            const result = await req.pool.request()
                .input('p_user_id', sql.Int, userId)
                .execute('view_my_vouchers');
            vouchers = result.recordset;
        }

        res.render('layout', {
            title: 'My Vouchers',
            body: await ejsBody('vouchers', { userId, vouchers })
        });
    } catch (err) {
        res.render('layout', { title: 'My Vouchers', body: `Error: ${err.message}` });
    }
});

app.post('/vouchers/collect', async (req, res) => {
    try {
        await req.pool.request()
            .input('p_user_id', sql.Int, req.body.user_id)
            .input('p_voucher_code', sql.NVarChar, req.body.voucher_code)
            .execute('collect_voucher');
        
        res.redirect(`/vouchers?user_id=${req.body.user_id}`);
    } catch (err) {
        res.send(`Error collecting voucher: ${err.message} <br> <a href="/vouchers?user_id=${req.body.user_id}">Back</a>`);
    }
});

// 5. Order History Routes
app.get('/orders', async (req, res) => {
    try {
        const userId = req.query.user_id;
        let orders = [];

        if (userId) {
            const result = await req.pool.request()
                .input('p_user_id', sql.Int, userId)
                .execute('view_order_history');
            orders = result.recordset;
        }

        res.render('layout', {
            title: 'My Orders',
            body: await ejsBody('orders', { userId, orders })
        });
    } catch (err) {
        res.render('layout', { title: 'My Orders', body: `Error: ${err.message}` });
    }
});

app.post('/orders/cancel', async (req, res) => {
    try {
        await req.pool.request()
            .input('p_user_id', sql.Int, req.body.user_id)
            .input('p_order_id', sql.Int, req.body.order_id)
            .execute('cancel_order');
        
        res.redirect(`/orders?user_id=${req.body.user_id}`);
    } catch (err) {
        res.send(`Error cancelling order: ${err.message} <br> <a href="/orders?user_id=${req.body.user_id}">Back</a>`);
    }
});

// 6. Admin Routes (Products)
app.get('/admin/products', async (req, res) => {
    try {
        // Reuse browse_products SP to list items
        const result = await req.pool.request()
            .input('p_limit', sql.Int, 50)
            .input('p_offset', sql.Int, 0)
            .execute('browse_products');

        res.render('layout', {
            title: 'Admin Products',
            body: await ejsBody('admin_products', { products: result.recordset })
        });
    } catch (err) {
        res.render('layout', { title: 'Admin Error', body: err.message });
    }
});

// NEW: Edit Product Page
app.get('/admin/products/edit/:id', async (req, res) => {
    try {
        const result = await req.pool.request()
            .input('p_product_id', sql.Int, req.params.id)
            .execute('get_product_details');
            
        // The SP returns a single JSON string because of FOR JSON PATH at the end
        // key look like JSON_F52E2B61-18A1-11d1-B105-00805F49916B
        const jsonString = Object.values(result.recordset[0])[0]; 
        const productData = JSON.parse(jsonString);
        
        const info = productData.info;
        const variants = productData.variants;

        res.render('layout', {
            title: `Edit Product #${req.params.id}`,
            body: await ejsBody('admin_product_edit', { info, variants })
        });
    } catch (err) {
        res.send(`Error loading product: ${err.message}`);
    }
});

// NEW: Update Product Action
app.post('/admin/products/update', async (req, res) => {
    try {
        await req.pool.request()
            .input('p_product_id', sql.Int, req.body.product_id)
            .input('p_name', sql.NVarChar, req.body.name)
            .input('p_price', sql.Decimal(10, 2), req.body.price)
            .input('p_thumbnail', sql.NVarChar, req.body.thumbnail)
            .input('p_description', sql.NVarChar, req.body.description)
            .execute('update_product');
            
        res.redirect('/admin/products');
    } catch (err) {
        res.send(`Update Failed: ${err.message} <a href="/admin/products/edit/${req.body.product_id}">Try Again</a>`);
    }
});

app.post('/admin/products/create', async (req, res) => {
    try {
        await req.pool.request()
            .input('p_name', sql.NVarChar, req.body.name)
            .input('p_slug', sql.NVarChar, req.body.slug)
            .input('p_description', sql.NVarChar, req.body.description)
            .input('p_original_price', sql.Decimal, req.body.original_price)
            .input('p_price', sql.Decimal, req.body.price)
            .input('p_thumbnail', sql.NVarChar, req.body.thumbnail)
            .input('p_category_ids', sql.NVarChar, req.body.category_ids) // Must be JSON "[1,2]"
            .execute('create_product');

        res.redirect('/admin/products');
    } catch (err) {
        res.send(`Error creating product: ${err.message} <br> <a href="/admin/products">Back</a>`);
    }
});

app.post('/admin/products/delete', async (req, res) => {
    try {
        await req.pool.request()
            .input('p_product_id', sql.Int, req.body.product_id)
            .execute('delete_product');
        res.redirect('/admin/products');
    } catch (err) { res.send(err.message); }
});

// 7. Admin Routes (Orders)
app.get('/admin/orders', async (req, res) => {
    try {
        const queryStatus = req.query.status || null;
        
        const result = await req.pool.request()
            .input('p_status', sql.NVarChar, queryStatus)
            .execute('view_orders');

        res.render('layout', {
            title: 'Manage Orders',
            body: await ejsBody('admin_orders', { orders: result.recordset, status: queryStatus })
        });
    } catch (err) {
        res.render('layout', { title: 'Admin Error', body: err.message });
    }
});

app.post('/admin/orders/update', async (req, res) => {
    try {
        await req.pool.request()
            .input('p_order_id', sql.Int, req.body.order_id)
            .input('p_new_status', sql.NVarChar, req.body.new_status)
            .execute('update_order_status');
        
        res.redirect('/admin/orders');
    } catch (err) {
        res.send(`Error updating order: ${err.message} <br> <a href="/admin/orders">Back</a>`);
    }
});

// 8. Admin Routes (Reports)
app.get('/admin/reports', async (req, res) => {
    try {
        // Default to last 30 days if no date provided
        const today = new Date();
        const lastMonth = new Date();
        lastMonth.setDate(today.getDate() - 30);

        const sDate = req.query.start_date || lastMonth.toISOString().split('T')[0];
        const eDate = req.query.end_date || today.toISOString().split('T')[0];

        // 1. Revenue Report
        const revResult = await req.pool.request()
            .input('p_start_date', sql.Date, sDate)
            .input('p_end_date', sql.Date, eDate)
            .execute('report_revenue_by_date');

        // 2. Best Sellers
        const bestResult = await req.pool.request()
            .input('p_limit', sql.Int, 10)
            .input('p_start_date', sql.Date, sDate) // Pass as Date/DateTime2
            .input('p_end_date', sql.Date, eDate)
            .execute('report_best_sellers');

        res.render('layout', {
            title: 'Reports',
            body: await ejsBody('admin_reports', { 
                startDate: sDate, 
                endDate: eDate,
                revenueData: revResult.recordset,
                bestSellers: bestResult.recordset
            })
        });

    } catch (err) {
        res.render('layout', { title: 'Report Error', body: err.message });
    }
});

// Start Server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🚀 Server running at http://localhost:${PORT}`);
});
