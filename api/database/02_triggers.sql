/* 02 - TRIGGERS adaptados a NewTalentLoans. Ejecutar después del archivo 03. */
USE NewTalentLoans;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER TRIGGER TR_Pago_AfterInsert ON Pago AFTER
    INSERT AS
BEGIN
SET NOCOUNT ON;
IF EXISTS(
    SELECT 1
    FROM inserted
    WHERE Pago_Estado<>N'Aplicado')
    THROW 50017, N'Un pago nuevo siempre debe iniciar en estado Aplicado.', 1;
DECLARE @pid INT, @loan INT, @method INT, @client INT, @target INT, @amount DECIMAL(18, 2), @balance DECIMAL(18, 2), @loanState NVARCHAR(40), @owner INT, @remain DECIMAL(18, 2), @installment INT, @part DECIMAL(18, 2), @first BIT;
DECLARE c CURSOR LOCAL FAST_FORWARD FOR
    SELECT Pago_ID, Prestamo_ID, MetodoPago_ID, Cliente_ID, Cuota_ID, Pago_Monto
    FROM inserted ORDER BY Pago_ID;
OPEN c;
FETCH NEXT
    FROM c
    INTO @pid, @loan, @method, @client, @target, @amount;
WHILE @@FETCH_STATUS=0
BEGIN
SELECT @balance=p.Prestamo_Saldo, @loanState=e.EstadoPrestamo_Nombre, @owner=s.Cliente_ID
    FROM Prestamo p WITH(UPDLOCK, HOLDLOCK)
    JOIN EstadoPrestamo e ON e.EstadoPrestamo_ID=p.EstadoPrestamo_ID
    JOIN Solicitud s ON s.Solicitud_ID=p.Solicitud_ID
    WHERE p.Prestamo_ID=@loan;
IF @balance IS NULL
    THROW 50010, N'El préstamo no existe.', 1;
IF @amount<=0 OR @amount>@balance
    THROW 50011, N'El monto excede el saldo o no es válido.', 1;
IF @loanState<>N'Activo'
    THROW 50012, N'El préstamo aún no ha sido desembolsado o no está activo.', 1;
IF @owner<>@client
    THROW 50013, N'El pago no corresponde al cliente del préstamo.', 1;
IF NOT EXISTS(
    SELECT 1
    FROM MetodoPago
    WHERE MetodoPago_ID=@method)
    THROW 50014, N'Método de pago inválido.', 1;
IF @target IS NOT NULL AND NOT EXISTS(
    SELECT 1
    FROM Cuota
    WHERE Cuota_ID=@target AND Prestamo_ID=@loan AND Cuota_Saldo>0)
    THROW 50025, N'La cuota indicada no está pendiente en este préstamo.', 1;
SET @remain=@amount;
SET @first=1;
WHILE @remain>0
BEGIN
SET @installment=NULL;
SET @part=NULL;
IF @first=1 AND @target IS NOT NULL
SELECT @installment=Cuota_ID, @part=Cuota_Saldo
    FROM Cuota WITH(UPDLOCK)
    WHERE Cuota_ID=@target AND Prestamo_ID=@loan AND Cuota_Saldo>0;
IF @installment IS NULL
SELECT TOP(1) @installment=Cuota_ID, @part=Cuota_Saldo
    FROM Cuota WITH(UPDLOCK)
    WHERE Prestamo_ID=@loan AND Cuota_Saldo>0 ORDER BY Cuota_FechaVencimiento, Cuota_Numero;
IF @installment IS NULL BREAK;
SET @part=CASE WHEN @part<@remain THEN @part ELSE @remain
    END;
UPDATE Cuota
    SET Cuota_Saldo=Cuota_Saldo-@part, Cuota_Estado=CASE WHEN Cuota_Saldo-@part=0 THEN N'Pagada' ELSE N'Parcial'
    END
    WHERE Cuota_ID=@installment;
INSERT PagoCuota(Pago_ID, Cuota_ID, PagoCuota_Monto)
    VALUES(@pid, @installment, @part);
SET @remain=@remain-@part;
SET @first=0;
END
IF @remain>0 AND EXISTS(
    SELECT 1
    FROM Cuota
    WHERE Prestamo_ID=@loan)
    THROW 50015, N'No se pudo distribuir el pago entre las cuotas.', 1;
UPDATE Prestamo
    SET Prestamo_Saldo=Prestamo_Saldo-@amount,
EstadoPrestamo_ID=CASE WHEN Prestamo_Saldo-@amount=0 THEN COALESCE((
    SELECT TOP(1) EstadoPrestamo_ID
    FROM EstadoPrestamo
    WHERE EstadoPrestamo_Nombre IN(N'Pagado', N'Finalizado') ORDER BY CASE EstadoPrestamo_Nombre WHEN N'Pagado' THEN 0 ELSE 1
    END), EstadoPrestamo_ID) ELSE EstadoPrestamo_ID
    END
WHERE Prestamo_ID=@loan;
/* Los pagos se reciben presencialmente. La aplicación registra la confirmación interna,
   pero no emite recibos, facturas ni comprobantes al cliente. */
INSERT Auditoria(Acceso_ID, Auditoria_Entidad, Auditoria_RegistroId, Auditoria_Accion, Auditoria_Detalle, Auditoria_DireccionIP)
SELECT a.Acceso_ID, N'Pago', CONVERT(nvarchar(100), @pid), N'INSERT', CONCAT(N'Pago aplicado: ', @amount, N' al préstamo #', @loan), NULL
    FROM Cliente cl
    JOIN Acceso a ON a.Acceso_ID=cl.Acceso_ID
    WHERE cl.Cliente_ID=@client;
FETCH NEXT
    FROM c
    INTO @pid, @loan, @method, @client, @target, @amount;
END
CLOSE c;
DEALLOCATE c;
END
GO
CREATE OR ALTER TRIGGER TR_Pago_AfterUpdate ON Pago AFTER
    UPDATE AS
BEGIN
SET NOCOUNT ON;
IF EXISTS(
    SELECT 1
    FROM inserted i
    JOIN deleted d ON d.Pago_ID=i.Pago_ID
    WHERE i.Prestamo_ID<>d.Prestamo_ID OR i.MetodoPago_ID<>d.MetodoPago_ID OR i.Cliente_ID<>d.Cliente_ID OR ISNULL(i.Cuota_ID, 0)<>ISNULL(d.Cuota_ID, 0) OR i.Pago_Monto<>d.Pago_Monto)
    THROW 50018, N'Los datos contables de un pago son inmutables.', 1;
IF
    UPDATE(Pago_Estado) AND EXISTS(
    SELECT 1
    FROM inserted i
    JOIN deleted d ON d.Pago_ID=i.Pago_ID
    WHERE i.Pago_Estado<>d.Pago_Estado AND NOT(d.Pago_Estado=N'Aplicado' AND i.Pago_Estado=N'Revertido'))
    THROW 50019, N'Transición de estado de pago no permitida.', 1;
IF NOT
    UPDATE(Pago_Estado)
    RETURN;
DECLARE @pid INT, @loan INT, @amount DECIMAL(18, 2), @reason NVARCHAR(500);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR
    SELECT i.Pago_ID, i.Prestamo_ID, i.Pago_Monto, i.Pago_ReversionMotivo
    FROM inserted i
    JOIN deleted d ON d.Pago_ID=i.Pago_ID
    WHERE d.Pago_Estado=N'Aplicado' AND i.Pago_Estado=N'Revertido';
OPEN c;
FETCH NEXT
    FROM c
    INTO @pid, @loan, @amount, @reason;
WHILE @@FETCH_STATUS=0
BEGIN
IF ISNULL(TRY_CONVERT(bit, SESSION_CONTEXT(N'PagoReversion')), 0)<>1
    THROW 50016, N'Use sp_RevertirPago para cancelar un pago y conservar su trazabilidad.', 1;
UPDATE q
    SET Cuota_Saldo=CASE WHEN q.Cuota_Saldo+x.Monto>q.Cuota_Monto THEN q.Cuota_Monto ELSE q.Cuota_Saldo+x.Monto
    END,
Cuota_Estado=CASE WHEN q.Cuota_Saldo+x.Monto>=q.Cuota_Monto THEN N'Pendiente' ELSE N'Parcial'
    END
FROM Cuota q
    JOIN (
    SELECT Cuota_ID, SUM(PagoCuota_Monto) Monto
    FROM PagoCuota
    WHERE Pago_ID=@pid GROUP BY Cuota_ID) x ON x.Cuota_ID=q.Cuota_ID;
UPDATE Prestamo
    SET Prestamo_Saldo=CASE WHEN EXISTS(
    SELECT 1
    FROM Cuota
    WHERE Prestamo_ID=@loan) THEN (
    SELECT SUM(Cuota_Saldo)
    FROM Cuota
    WHERE Prestamo_ID=@loan) ELSE p.Prestamo_Saldo+@amount
    END,
EstadoPrestamo_ID=CASE WHEN e.EstadoPrestamo_Nombre IN(N'Pagado', N'Finalizado') THEN COALESCE((
    SELECT TOP(1) EstadoPrestamo_ID
    FROM EstadoPrestamo
    WHERE EstadoPrestamo_Nombre=N'Activo'), p.EstadoPrestamo_ID) ELSE p.EstadoPrestamo_ID
    END
FROM Prestamo p
    JOIN EstadoPrestamo e ON e.EstadoPrestamo_ID=p.EstadoPrestamo_ID
    WHERE p.Prestamo_ID=@loan;
INSERT Auditoria(Acceso_ID, Auditoria_Entidad, Auditoria_RegistroId, Auditoria_Accion, Auditoria_Detalle)
SELECT r.Acceso_ID, N'Pago', CONVERT(nvarchar(100), @pid), N'UPDATE', CONCAT(N'Pago revertido: ', @amount, N'. Motivo: ', @reason)
    FROM ReversionPago r
    WHERE r.Pago_ID=@pid;
FETCH NEXT
    FROM c
    INTO @pid, @loan, @amount, @reason;
END
CLOSE c;
DEALLOCATE c;
END
GO
CREATE OR ALTER TRIGGER TR_Pago_PreventDelete ON Pago AFTER
    DELETE AS
BEGIN
SET NOCOUNT ON;
IF EXISTS(
    SELECT 1
    FROM deleted)
    THROW 50020, N'Los pagos no se borran; use sp_RevertirPago para conservar trazabilidad.', 1;
END
GO
CREATE OR ALTER TRIGGER TR_Desembolso_AfterUpdate ON Desembolso AFTER
    UPDATE,
    DELETE AS
BEGIN
SET NOCOUNT ON;
IF EXISTS(
    SELECT 1
    FROM deleted) AND NOT EXISTS(
    SELECT 1
    FROM inserted)
    THROW 50021, N'Los desembolsos no se borran.', 1;
IF EXISTS(
    SELECT 1
    FROM inserted i
    JOIN deleted d ON d.Desembolso_ID=i.Desembolso_ID
    WHERE (i.Prestamo_ID<>d.Prestamo_ID OR i.MetodoPago_ID<>d.MetodoPago_ID OR i.Desembolso_Monto<>d.Desembolso_Monto) OR (i.Desembolso_Estado<>d.Desembolso_Estado AND NOT(d.Desembolso_Estado=N'Procesado' AND i.Desembolso_Estado=N'Revertido')))
    THROW 50022, N'Use sp_RevertirDesembolso para cancelar un desembolso.', 1;
IF EXISTS(
    SELECT 1
    FROM inserted i
    JOIN deleted d ON d.Desembolso_ID=i.Desembolso_ID
    WHERE i.Desembolso_Estado<>d.Desembolso_Estado AND ISNULL(TRY_CONVERT(bit, SESSION_CONTEXT(N'DesembolsoReversion')), 0)<>1)
    THROW 50023, N'La reversión del desembolso requiere el procedimiento autorizado.', 1;
END
GO
CREATE OR ALTER TRIGGER TR_Desembolso_AfterInsert ON Desembolso AFTER
    INSERT AS
BEGIN
SET NOCOUNT ON;
IF EXISTS(
    SELECT 1
    FROM inserted
    WHERE Desembolso_Estado<>N'Procesado')
    THROW 50024, N'Un desembolso nuevo debe iniciar como Procesado.', 1;
END
GO
CREATE OR ALTER TRIGGER TR_Solicitud_AfterUpdate ON Solicitud AFTER
    INSERT,
    UPDATE AS
BEGIN
SET NOCOUNT ON;
IF EXISTS(
    SELECT 1
    FROM inserted i
    JOIN TipoPrestamo t ON t.TipoPrestamo_ID=i.TipoPrestamo_ID
    WHERE i.Solicitud_Monto<t.TipoPrestamo_MontoMinimo OR i.Solicitud_Monto>t.TipoPrestamo_MontoMaximo)
    THROW 50032, N'Monto fuera del rango permitido para el tipo de préstamo.', 1;
IF EXISTS(
    SELECT 1
    FROM inserted i
    JOIN TipoPrestamo t ON t.TipoPrestamo_ID=i.TipoPrestamo_ID
    WHERE i.Solicitud_Plazo<t.TipoPrestamo_PlazoMinimo OR i.Solicitud_Plazo>t.TipoPrestamo_PlazoMaximo)
    THROW 50033, N'Plazo fuera del rango permitido para el tipo de préstamo.', 1;
IF
    UPDATE(EstadoSolicitud_ID) AND EXISTS(
    SELECT 1
    FROM inserted i
    JOIN deleted d ON d.Solicitud_ID=i.Solicitud_ID
    JOIN EstadoSolicitud e ON e.EstadoSolicitud_ID=d.EstadoSolicitud_ID
    JOIN EstadoSolicitud n ON n.EstadoSolicitud_ID=i.EstadoSolicitud_ID
    WHERE e.EstadoSolicitud_Nombre IN(N'Aprobada', N'Rechazada') AND n.EstadoSolicitud_Nombre=N'Pendiente')
    THROW 50030, N'Una solicitud evaluada no puede volver a Pendiente.', 1;
IF EXISTS(
    SELECT 1
    FROM inserted i
    JOIN deleted d ON d.Solicitud_ID=i.Solicitud_ID
    JOIN EstadoSolicitud e ON e.EstadoSolicitud_ID=d.EstadoSolicitud_ID
    WHERE e.EstadoSolicitud_Nombre IN(N'Aprobada', N'Rechazada') AND (i.Cliente_ID<>d.Cliente_ID OR i.Solicitud_Monto<>d.Solicitud_Monto OR i.Solicitud_Plazo<>d.Solicitud_Plazo OR ISNULL(i.TipoPrestamo_ID, 0)<>ISNULL(d.TipoPrestamo_ID, 0)))
    THROW 50031, N'Una solicitud evaluada no puede cambiar de cliente, monto, plazo o tipo.', 1;
END
GO
CREATE OR ALTER TRIGGER TR_Prestamo_AfterUpdate ON Prestamo AFTER
    UPDATE AS
BEGIN
SET NOCOUNT ON;
IF
    UPDATE(EstadoPrestamo_ID) AND EXISTS(
    SELECT 1
    FROM inserted i
    JOIN deleted d ON d.Prestamo_ID=i.Prestamo_ID
    JOIN EstadoPrestamo old ON old.EstadoPrestamo_ID=d.EstadoPrestamo_ID
    JOIN EstadoPrestamo new ON new.EstadoPrestamo_ID=i.EstadoPrestamo_ID
    WHERE old.EstadoPrestamo_Nombre IN(N'Pagado', N'Finalizado', N'Cancelado') AND new.EstadoPrestamo_Nombre IN(N'Activo', N'Aprobado') AND ISNULL(TRY_CONVERT(bit, SESSION_CONTEXT(N'PagoReversion')), 0)<>1)
    THROW 50034, N'Un préstamo cerrado solo puede reabrirse al revertir un pago.', 1;
INSERT Auditoria(Acceso_ID, Auditoria_Entidad, Auditoria_RegistroId, Auditoria_Accion, Auditoria_Detalle)
SELECT NULL, N'Prestamo', CONVERT(nvarchar(100), i.Prestamo_ID), N'UPDATE', CONCAT(N'Estado del préstamo: ', old.EstadoPrestamo_Nombre, N' -> ', new.EstadoPrestamo_Nombre)
FROM inserted i
    JOIN deleted d ON d.Prestamo_ID=i.Prestamo_ID
    JOIN EstadoPrestamo old ON old.EstadoPrestamo_ID=d.EstadoPrestamo_ID
    JOIN EstadoPrestamo new ON new.EstadoPrestamo_ID=i.EstadoPrestamo_ID
    WHERE i.EstadoPrestamo_ID<>d.EstadoPrestamo_ID;
END
GO
CREATE OR ALTER TRIGGER TR_Acceso_AfterUpdate ON Acceso AFTER
    UPDATE AS
BEGIN
SET NOCOUNT ON;
INSERT Auditoria(Acceso_ID, Auditoria_Entidad, Auditoria_RegistroId, Auditoria_Accion, Auditoria_Detalle)
SELECT i.Acceso_ID, N'Acceso', CONVERT(nvarchar(100), i.Acceso_ID), N'UPDATE', CONCAT(N'Cuenta modificada; activo: ', i.Acceso_Activo, N'; rol: ', r.Rol_Nombre, N'; correo: ', i.Acceso_Correo, CASE WHEN i.Acceso_ContrasenaHash<>d.Acceso_ContrasenaHash THEN N'; contraseña actualizada' ELSE N''
    END)
FROM inserted i
    JOIN deleted d ON d.Acceso_ID=i.Acceso_ID
    JOIN Rol r ON r.Rol_ID=i.Rol_ID
WHERE i.Acceso_Activo<>d.Acceso_Activo OR i.Rol_ID<>d.Rol_ID OR i.Acceso_Correo<>d.Acceso_Correo OR i.Acceso_ContrasenaHash<>d.Acceso_ContrasenaHash;
END
GO
