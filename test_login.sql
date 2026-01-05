USE ECommerceDB1;
GO

PRINT '==================================================';
PRINT 'TESTING LOGIN FEATURE';
PRINT '==================================================';

DECLARE @v_email NVARCHAR(255) = 'simple_test@address.com';
DECLARE @v_password NVARCHAR(MAX) = '123';

-- 1. Setup: Register a User first
PRINT '>> 1. Setup: Registering user for login test...';
IF EXISTS (SELECT 1 FROM users WHERE email = @v_email)
    DELETE FROM users WHERE email = @v_email;

EXEC register_user 
    @p_email = @v_email, 
    @p_password = @v_password, 
    @p_name = 'Login Tester', 
    @p_phone = '0987654321';

DECLARE @v_email NVARCHAR(255) = 'simple_test@address.com';
DECLARE @v_password NVARCHAR(MAX) = '123';

-- 2. Test Success Login
PRINT '>> 2. Test Success Login (Correct Email & Password)...';
PRINT '   Expect: JSON result with "SUCCESS"';
EXEC login_user 
    @p_email = @v_email, 
    @p_password = @v_password;

-- 3. Test Failed Login (Wrong Password)
PRINT '>> 3. Test Failed Login (Wrong Password)...';
PRINT '   Expect: Error "Invalid email or password."';
BEGIN TRY
    EXEC login_user 
        @p_email = @v_email, 
        @p_password = 'wrongpassword';
    PRINT '   [FAIL] Did not catch error!';
END TRY
BEGIN CATCH
    PRINT '   [OK] Error Caught: ' + ERROR_MESSAGE();
END CATCH;

-- 4. Test Failed Login (Wrong Email)
PRINT '>> 4. Test Failed Login (Non-existent Email)...';
PRINT '   Expect: Error "Invalid email or password."';
BEGIN TRY
    EXEC login_user 
        @p_email = 'ghost@example.com', 
        @p_password = @v_password;
    PRINT '   [FAIL] Did not catch error!';
END TRY
BEGIN CATCH
    PRINT '   [OK] Error Caught: ' + ERROR_MESSAGE();
END CATCH;
GO
