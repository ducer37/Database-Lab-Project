USE ECommerceDBDemo5;
GO

CREATE OR ALTER TRIGGER trg_prevent_negative_stock
ON product_variants
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (SELECT 1 FROM inserted WHERE stock < 0)
    BEGIN
        RAISERROR('ERROR: Stock cannot be negative. Transaction rolled back.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

PRINT 'Created: trg_prevent_negative_stock';
GO

CREATE OR ALTER TRIGGER trg_audit_order_status_change
ON orders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @order_id INT, @old_status NVARCHAR(20), @new_status NVARCHAR(20);
    DECLARE @old_payment NVARCHAR(20), @new_payment NVARCHAR(20);
    
    SELECT 
        @order_id = i.id,
        @old_status = d.status,
        @new_status = i.status,
        @old_payment = d.payment_status,
        @new_payment = i.payment_status
    FROM inserted i
    INNER JOIN deleted d ON i.id = d.id
    WHERE i.status <> d.status OR i.payment_status <> d.payment_status;
    
    IF @order_id IS NOT NULL
    BEGIN
        PRINT CONCAT('AUDIT: Order #', @order_id, ' status changed: ', @old_status, ' -> ', @new_status, 
                     ' | Payment: ', @old_payment, ' -> ', @new_payment);
    END
END;
GO

PRINT 'Created: trg_audit_order_status_change';
GO


CREATE OR ALTER TRIGGER trg_address_single_default
ON addresses
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (SELECT 1 FROM inserted WHERE is_default = 1)
    BEGIN
        UPDATE a
        SET a.is_default = 0
        FROM addresses a
        INNER JOIN inserted i ON a.user_id = i.user_id
        WHERE a.id <> i.id 
          AND a.is_default = 1 
          AND i.is_default = 1;
    END
END;
GO

PRINT 'Created: trg_address_single_default';
GO

CREATE OR ALTER TRIGGER trg_user_payment_single_default
ON user_payments
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (SELECT 1 FROM inserted WHERE is_default = 1)
    BEGIN
        UPDATE up
        SET up.is_default = 0
        FROM user_payments up
        INNER JOIN inserted i ON up.user_id = i.user_id
        WHERE up.id <> i.id 
          AND up.is_default = 1 
          AND i.is_default = 1;
    END
END;
GO

PRINT 'Created: trg_user_payment_single_default';
GO
