USE ECommerceDB1;
GO

PRINT '==================================================';
PRINT 'TESTING ADDRESS FEATURE (SIMPLE)';
PRINT '==================================================';

DECLARE @v_email NVARCHAR(255) = 'simple_test@address.com';
DECLARE @v_user_id INT;

-- 1. Register
PRINT '>> 1. Registering...';
IF EXISTS (SELECT 1 FROM users WHERE email = @v_email)
    DELETE FROM users WHERE email = @v_email;

EXEC register_user 
    @p_email = @v_email, 
    @p_password = '123', 
    @p_name = 'Simple Tester', 
    @p_phone = '000111222';

SELECT @v_user_id = id FROM users WHERE email = @v_email;
PRINT '   User Created ID: ' + CAST(@v_user_id AS NVARCHAR(20));

-- 2. Add Address 1 (Default)
PRINT '>> 2. Add Address 1 (Should be Default)...';
EXEC add_address 
    @p_user_id = 7,
    @p_recipient_name = 'Home',
    @p_phone = '0909090909',
    @p_city = 'Hanoi',
    @p_district = 'Cau Giay',
    @p_ward = 'Dich Vong',
    @p_detail = '123 Xuan Thuy';

-- 3. Add Address 2 (Normal)
PRINT '>> 3. Add Address 2 (Should be Normal)...';
EXEC add_address 
    @p_user_id = @v_user_id,
    @p_recipient_name = 'Work',
    @p_phone = '0901010101',
    @p_city = 'Hanoi',
    @p_district = 'Ba Dinh',
    @p_ward = 'Kim Ma',
    @p_detail = '456 Kim Ma';

-- 4. View Addresses
PRINT '>> 4. View My Addresses...';
EXEC get_my_addresses @p_user_id = 7;
GO
