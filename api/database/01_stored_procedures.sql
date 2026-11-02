/* 01 - STORED PROCEDURES. Ejecutar después de los archivos 03 y 02. */
USE NewTalentLoans;
GO
IF NOT EXISTS(
    SELECT 1
    FROM EstadoPrestamo
    WHERE EstadoPrestamo_Nombre=N'Aprobado')
    INSERT EstadoPrestamo(EstadoPrestamo_Nombre)
    VALUES(N'Aprobado');
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE sp_RegistrarCliente
@Nombre NVARCHAR(100), @Apellido NVARCHAR(100), @Cedula NVARCHAR(30), @Sueldo DECIMAL(18, 2),
@Calle NVARCHAR(150), @Numero NVARCHAR(20)=NULL, @Sector NVARCHAR(100)=NULL, @Referencia NVARCHAR(500)=NULL,
@Provincia NVARCHAR(100), @Ciudad NVARCHAR(100), @Telefono NVARCHAR(30), @Correo NVARCHAR(254), @ContrasenaHash NVARCHAR(255)
AS
BEGIN
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF NULLIF(LTRIM(RTRIM(@Nombre)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@Apellido)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@Cedula)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@Calle)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@Provincia)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@Ciudad)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@Telefono)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@Correo)), N'') IS NULL OR NULLIF(@ContrasenaHash, N'') IS NULL
    THROW 50100, N'Faltan datos obligatorios del cliente.', 1;
IF @Sueldo IS NULL OR @Sueldo<0
    THROW 50101, N'El sueldo debe ser mayor o igual a cero.', 1;
IF NOT EXISTS(
    SELECT 1
    FROM Rol
    WHERE Rol_Nombre=N'Cliente')
    THROW 50102, N'No existe el rol Cliente.', 1;
BEGIN TRY
BEGIN TRANSACTION;
DECLARE @ProvinceId INT, @CityId INT, @AddressId INT, @AccessId INT, @ClientId INT, @RoleId INT;
SELECT @RoleId=Rol_ID
    FROM Rol
    WHERE Rol_Nombre=N'Cliente';
SELECT @ProvinceId=Provincia_ID
    FROM Provincia WITH(UPDLOCK, HOLDLOCK)
    WHERE Provincia_Nombre=LTRIM(RTRIM(@Provincia));
IF @ProvinceId IS NULL
    BEGIN
    INSERT Provincia(Provincia_Nombre)
    VALUES(LTRIM(RTRIM(@Provincia)));
SET @ProvinceId=CONVERT(INT, SCOPE_IDENTITY());
END
SELECT @CityId=Ciudad_ID
    FROM Ciudad WITH(UPDLOCK, HOLDLOCK)
    WHERE Provincia_ID=@ProvinceId AND Ciudad_Nombre=LTRIM(RTRIM(@Ciudad));
IF @CityId IS NULL
    BEGIN
    INSERT Ciudad(Provincia_ID, Ciudad_Nombre)
    VALUES(@ProvinceId, LTRIM(RTRIM(@Ciudad)));
SET @CityId=CONVERT(INT, SCOPE_IDENTITY());
END
INSERT Direccion(Ciudad_ID, Direccion_Calle, Direccion_Numero, Direccion_Sector, Direccion_Descripcion)
    VALUES(@CityId, LTRIM(RTRIM(@Calle)), NULLIF(LTRIM(RTRIM(@Numero)), N''), NULLIF(LTRIM(RTRIM(@Sector)), N''), NULLIF(LTRIM(RTRIM(@Referencia)), N''));
SET @AddressId=CONVERT(INT, SCOPE_IDENTITY());
INSERT Acceso(Rol_ID, Acceso_Correo, Acceso_ContrasenaHash)
    VALUES(@RoleId, LOWER(LTRIM(RTRIM(@Correo))), @ContrasenaHash);
SET @AccessId=CONVERT(INT, SCOPE_IDENTITY());
INSERT Cliente(Direccion_ID, Acceso_ID, Cliente_Nombre, Cliente_Apellido, Cliente_Cedula, Cliente_Sueldo)
    VALUES(@AddressId, @AccessId, LTRIM(RTRIM(@Nombre)), LTRIM(RTRIM(@Apellido)), LTRIM(RTRIM(@Cedula)), @Sueldo);
SET @ClientId=CONVERT(INT, SCOPE_IDENTITY());
INSERT Telefono(Cliente_ID, Telefono_Numero)
    VALUES(@ClientId, LTRIM(RTRIM(@Telefono)));
INSERT Correo(Cliente_ID, Correo_Direccion)
    VALUES(@ClientId, LOWER(LTRIM(RTRIM(@Correo))));
INSERT Auditoria(Acceso_ID, Auditoria_Entidad, Auditoria_RegistroId, Auditoria_Accion, Auditoria_Detalle)
    VALUES(@AccessId, N'Cliente', CONVERT(NVARCHAR(100), @ClientId), N'INSERT', N'Registro de cliente');
COMMIT;
SELECT @ClientId AS Cliente_ID;
END TRY
BEGIN CATCH
IF XACT_STATE()<>0
    ROLLBACK;
IF ERROR_NUMBER() IN(2601, 2627)
    THROW 50103, N'El correo o la cédula ya están registrados.', 1;
THROW;
END CATCH
END
GO
CREATE OR ALTER PROCEDURE sp_CrearSolicitud
@Cliente_ID INT, @TipoPrestamo_ID INT, @MetodoPago_ID INT, @Monto DECIMAL(18, 2), @Plazo INT, @Motivo NVARCHAR(500)=NULL, @Moneda_ID INT=NULL, @Acceso_ID INT=NULL
AS
BEGIN
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @Cliente_ID IS NULL OR @TipoPrestamo_ID IS NULL OR @MetodoPago_ID IS NULL OR @Monto IS NULL OR @Plazo IS NULL OR @Monto<=0 OR @Plazo NOT BETWEEN 1 AND 120
    THROW 50110, N'Monto, tipo, método o plazo inválido.', 1;
BEGIN TRY
BEGIN TRANSACTION;
IF NOT EXISTS(
    SELECT 1
    FROM Cliente
    WHERE Cliente_ID=@Cliente_ID)
    THROW 50111, N'Cliente no encontrado.', 1;
IF @Acceso_ID IS NOT NULL AND NOT EXISTS(
    SELECT 1
    FROM Cliente
    WHERE Cliente_ID=@Cliente_ID AND Acceso_ID=@Acceso_ID)
    THROW 50116, N'La cuenta no corresponde al cliente.', 1;
IF NOT EXISTS(
    SELECT 1
    FROM TipoPrestamo
    WHERE TipoPrestamo_ID=@TipoPrestamo_ID)
    THROW 50112, N'Tipo de préstamo no encontrado.', 1;
IF NOT EXISTS(
    SELECT 1
    FROM MetodoPago
    WHERE MetodoPago_ID=@MetodoPago_ID)
    THROW 50113, N'Método de pago no encontrado.', 1;
IF @Moneda_ID IS NULL
    SELECT @Moneda_ID=Moneda_ID
    FROM Moneda
    WHERE Moneda_Codigo='DOP' AND Moneda_Activa=1;
IF @Moneda_ID IS NULL OR NOT EXISTS(
    SELECT 1
    FROM Moneda
    WHERE Moneda_ID=@Moneda_ID AND Moneda_Activa=1)
    THROW 50114, N'Moneda inválida o inactiva.', 1;
DECLARE @StateId INT, @NewId INT;
SELECT @StateId=EstadoSolicitud_ID
    FROM EstadoSolicitud
    WHERE EstadoSolicitud_Nombre=N'Pendiente';
IF @StateId IS NULL
    THROW 50115, N'Falta el estado Pendiente.', 1;
INSERT Solicitud(Cliente_ID, TipoPrestamo_ID, MetodoPago_ID, Moneda_ID, EstadoSolicitud_ID, Solicitud_Monto, Solicitud_Plazo, Solicitud_Motivo)
    VALUES(@Cliente_ID, @TipoPrestamo_ID, @MetodoPago_ID, @Moneda_ID, @StateId, @Monto, @Plazo, NULLIF(LTRIM(RTRIM(@Motivo)), N''));
SET @NewId=CONVERT(INT, SCOPE_IDENTITY());
INSERT Auditoria(Acceso_ID, Auditoria_Entidad, Auditoria_RegistroId, Auditoria_Accion, Auditoria_Detalle)
    VALUES(@Acceso_ID, N'Solicitud', CONVERT(NVARCHAR(100), @NewId), N'INSERT', N'Solicitud de préstamo creada');
COMMIT;
SELECT @NewId AS Solicitud_ID;
END TRY
BEGIN CATCH
IF XACT_STATE()<>0
    ROLLBACK;
THROW;
END CATCH
END
GO
CREATE OR ALTER PROCEDURE sp_ResolverSolicitud
@Solicitud_ID INT, @Decision NVARCHAR(20), @TipoPrestamo_ID INT=NULL, @Empleado_ID INT=NULL,
@Garante_Nombre NVARCHAR(150)=NULL, @Garante_Cedula NVARCHAR(30)=NULL, @Garante_Telefono NVARCHAR(30)=NULL, @Comentario NVARCHAR(500)=NULL
AS
BEGIN
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @Solicitud_ID IS NULL OR @Decision IS NULL OR @Decision NOT IN(N'Aprobada', N'Rechazada')
    THROW 50120, N'Decisión inválida.', 1;
BEGIN TRY
BEGIN TRANSACTION;
DECLARE @ClientId INT, @Amount DECIMAL(18, 2), @Term INT, @CurrentStatus INT, @Pending INT, @Resolved INT, @TypeId INT, @Rate DECIMAL(5, 2), @Salary DECIMAL(18, 2), @LoanStatus INT, @LoanId INT=NULL, @Payment DECIMAL(18, 2), @MonthlyRate DECIMAL(18, 10), @Balance DECIMAL(18, 2), @Interest DECIMAL(18, 2), @Capital DECIMAL(18, 2), @n INT=1;
SELECT @ClientId=s.Cliente_ID, @Amount=s.Solicitud_Monto, @Term=s.Solicitud_Plazo, @CurrentStatus=s.EstadoSolicitud_ID, @TypeId=COALESCE(@TipoPrestamo_ID, s.TipoPrestamo_ID), @Salary=c.Cliente_Sueldo
FROM Solicitud s WITH(UPDLOCK, HOLDLOCK)
    JOIN Cliente c ON c.Cliente_ID=s.Cliente_ID
    WHERE s.Solicitud_ID=@Solicitud_ID;
IF @ClientId IS NULL
    THROW 50121, N'Solicitud no encontrada.', 1;
SELECT @Pending=EstadoSolicitud_ID
    FROM EstadoSolicitud
    WHERE EstadoSolicitud_Nombre=N'Pendiente';
IF @CurrentStatus<>@Pending
    THROW 50122, N'Solo se pueden resolver solicitudes pendientes.', 1;
SELECT @Resolved=EstadoSolicitud_ID
    FROM EstadoSolicitud
    WHERE EstadoSolicitud_Nombre=@Decision;
IF @Resolved IS NULL
    THROW 50123, N'No existe el estado solicitado.', 1;
IF @Decision=N'Aprobada'
BEGIN
IF @TypeId IS NULL
    THROW 50124, N'Seleccione el tipo de préstamo.', 1;
SELECT @Rate=TipoPrestamo_TasaBase
    FROM TipoPrestamo
    WHERE TipoPrestamo_ID=@TypeId;
IF @Rate IS NULL
    THROW 50125, N'Tipo de préstamo no encontrado.', 1;
IF @Amount>(
    SELECT Cliente_Sueldo
    FROM Cliente
    WHERE Cliente_ID=@ClientId) AND (NULLIF(LTRIM(RTRIM(@Garante_Nombre)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@Garante_Cedula)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@Garante_Telefono)), N'') IS NULL)
    THROW 50126, N'El monto requiere los datos completos del garante.', 1;
IF EXISTS(
    SELECT 1
    FROM Prestamo
    WHERE Solicitud_ID=@Solicitud_ID)
    THROW 50127, N'La solicitud ya tiene préstamo.', 1;
SELECT @LoanStatus=EstadoPrestamo_ID
    FROM EstadoPrestamo
    WHERE EstadoPrestamo_Nombre=N'Aprobado';
IF @LoanStatus IS NULL
    THROW 50128, N'Falta el estado Aprobado.', 1;
INSERT Prestamo(Solicitud_ID, TipoPrestamo_ID, EstadoPrestamo_ID, Prestamo_Monto, Prestamo_Tasa, Prestamo_Plazo, Prestamo_FechaDesembolso, Prestamo_Saldo)
    VALUES(@Solicitud_ID, @TypeId, @LoanStatus, @Amount, @Rate, @Term, NULL, @Amount);
SET @LoanId=CONVERT(INT, SCOPE_IDENTITY());
IF NULLIF(LTRIM(RTRIM(@Garante_Nombre)), N'') IS NOT NULL
    INSERT Garante(Prestamo_ID, Garante_Nombre, Garante_Cedula, Garante_Telefono)
    VALUES(@LoanId, @Garante_Nombre, @Garante_Cedula, @Garante_Telefono);
SET @MonthlyRate=CONVERT(DECIMAL(18, 10), @Rate)/1200;
SET @Payment=CASE WHEN @MonthlyRate=0 THEN ROUND(@Amount/@Term, 2) ELSE ROUND(@Amount*@MonthlyRate/(1-POWER(1+@MonthlyRate, -@Term)), 2)
    END;
SET @Balance=@Amount;
WHILE @n<=@Term
BEGIN
SET @Interest=ROUND(@Balance*@MonthlyRate, 2);
SET @Capital=CASE WHEN @n=@Term THEN @Balance ELSE @Payment-@Interest
    END;
INSERT Cuota(Prestamo_ID, Cuota_Numero, Cuota_FechaVencimiento, Cuota_Capital, Cuota_Interes, Cuota_Monto, Cuota_Saldo, Cuota_Estado)
    VALUES(@LoanId, @n, DATEADD(MONTH, @n, CONVERT(date, SYSDATETIME())), @Capital, @Interest, @Capital+@Interest, @Capital+@Interest, N'Pendiente');
SET @Balance=@Balance-@Capital;
SET @n+=1;
END
UPDATE Prestamo
    SET Prestamo_Saldo=(
    SELECT SUM(Cuota_Saldo)
    FROM Cuota
    WHERE Prestamo_ID=@LoanId)
    WHERE Prestamo_ID=@LoanId;
END
UPDATE Solicitud
    SET EstadoSolicitud_ID=@Resolved, TipoPrestamo_ID=COALESCE(@TypeId, TipoPrestamo_ID)
    WHERE Solicitud_ID=@Solicitud_ID;
INSERT HistorialSolicitud(Solicitud_ID, EstadoSolicitud_ID, Empleado_ID, HistorialSolicitud_Comentario)
    VALUES(@Solicitud_ID, @Resolved, @Empleado_ID, NULLIF(LTRIM(RTRIM(@Comentario)), N''));
COMMIT;
SELECT @Solicitud_ID AS Solicitud_ID, @Decision AS Decision, @LoanId AS Prestamo_ID;
END TRY
BEGIN CATCH
IF XACT_STATE()<>0
    ROLLBACK;
THROW;
END CATCH
END
GO
CREATE OR ALTER PROCEDURE sp_RegistrarDesembolso
@Prestamo_ID INT, @MetodoPago_ID INT, @Monto DECIMAL(18, 2), @Acceso_ID INT=NULL, @Referencia NVARCHAR(100)=NULL, @Observacion NVARCHAR(500)=NULL
AS
BEGIN
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @Prestamo_ID IS NULL OR @MetodoPago_ID IS NULL OR @Monto IS NULL OR @Monto<=0
    THROW 50140, N'Préstamo, método y monto de desembolso son obligatorios.', 1;
BEGIN TRY
BEGIN TRANSACTION;
DECLARE @StateId INT, @LoanState INT, @ApprovedAmount DECIMAL(18, 2), @DisbursementId INT, @EmployeeId INT;
SELECT @ApprovedAmount=p.Prestamo_Monto, @LoanState=p.EstadoPrestamo_ID
    FROM Prestamo p WITH(UPDLOCK, HOLDLOCK)
    WHERE p.Prestamo_ID=@Prestamo_ID;
IF @ApprovedAmount IS NULL
    THROW 50141, N'Préstamo no encontrado.', 1;
SELECT @StateId=EstadoPrestamo_ID
    FROM EstadoPrestamo
    WHERE EstadoPrestamo_Nombre=N'Aprobado';
IF @LoanState<>@StateId
    THROW 50142, N'Solo se desembolsan préstamos aprobados.', 1;
IF ABS(@Monto-@ApprovedAmount)>=0.01
    THROW 50143, N'El desembolso debe coincidir con el monto aprobado.', 1;
IF NOT EXISTS(
    SELECT 1
    FROM MetodoPago
    WHERE MetodoPago_ID=@MetodoPago_ID)
    THROW 50144, N'Método de pago no encontrado.', 1;
IF EXISTS(
    SELECT 1
    FROM Desembolso
    WHERE Prestamo_ID=@Prestamo_ID AND Desembolso_Estado=N'Procesado')
    THROW 50145, N'El préstamo ya tiene un desembolso procesado.', 1;
SELECT @EmployeeId=Empleado_ID
    FROM Empleado
    WHERE Acceso_ID=@Acceso_ID;
INSERT Desembolso(Prestamo_ID, MetodoPago_ID, Empleado_ID, Desembolso_Monto, Desembolso_Referencia, Desembolso_Estado, Desembolso_Observacion)
    VALUES(@Prestamo_ID, @MetodoPago_ID, @EmployeeId, @Monto, @Referencia, N'Procesado', @Observacion);
SET @DisbursementId=CONVERT(INT, SCOPE_IDENTITY());
SELECT @StateId=EstadoPrestamo_ID
    FROM EstadoPrestamo
    WHERE EstadoPrestamo_Nombre=N'Activo';
IF @StateId IS NULL
    THROW 50146, N'Falta el estado Activo.', 1;
UPDATE Prestamo
    SET EstadoPrestamo_ID=@StateId, Prestamo_FechaDesembolso=SYSDATETIME()
    WHERE Prestamo_ID=@Prestamo_ID;
COMMIT;
SELECT @DisbursementId AS Desembolso_ID, @Prestamo_ID AS Prestamo_ID;
END TRY
BEGIN CATCH
IF XACT_STATE()<>0
    ROLLBACK;
THROW;
END CATCH
END
GO
CREATE OR ALTER PROCEDURE sp_RegistrarPago
@Cliente_ID INT, @Monto DECIMAL(18, 2), @MetodoPago_ID INT, @Prestamo_ID INT=NULL, @Cuota_ID INT=NULL, @Referencia NVARCHAR(100)=NULL
AS
BEGIN
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @Cliente_ID IS NULL OR @MetodoPago_ID IS NULL OR @Monto IS NULL OR @Monto<=0
    THROW 50130, N'Cliente, método y monto son obligatorios.', 1;
BEGIN TRY
BEGIN TRANSACTION;
DECLARE @LoanId INT, @LoanBalance DECIMAL(18, 2), @PaymentId INT;
IF NOT EXISTS(
    SELECT 1
    FROM Cliente
    WHERE Cliente_ID=@Cliente_ID)
    THROW 50131, N'Cliente no encontrado.', 1;
IF NOT EXISTS(
    SELECT 1
    FROM MetodoPago
    WHERE MetodoPago_ID=@MetodoPago_ID)
    THROW 50132, N'Método de pago no encontrado.', 1;
SELECT TOP(1) @LoanId=p.Prestamo_ID, @LoanBalance=p.Prestamo_Saldo
    FROM Prestamo p WITH(UPDLOCK, HOLDLOCK)
    JOIN Solicitud s ON s.Solicitud_ID=p.Solicitud_ID
    JOIN EstadoPrestamo e ON e.EstadoPrestamo_ID=p.EstadoPrestamo_ID
    WHERE s.Cliente_ID=@Cliente_ID AND (@Prestamo_ID IS NULL OR p.Prestamo_ID=@Prestamo_ID) AND e.EstadoPrestamo_Nombre=N'Activo' ORDER BY p.Prestamo_ID DESC;
IF @LoanId IS NULL
    THROW 50133, N'No existe un préstamo activo para el cliente.', 1;
IF @Monto>@LoanBalance
    THROW 50134, N'El monto supera el saldo pendiente.', 1;
IF @Cuota_ID IS NOT NULL AND NOT EXISTS(
    SELECT 1
    FROM Cuota
    WHERE Cuota_ID=@Cuota_ID AND Prestamo_ID=@LoanId AND Cuota_Saldo>0)
    THROW 50135, N'La cuota no corresponde al préstamo o ya está pagada.', 1;
INSERT Pago(Prestamo_ID, MetodoPago_ID, Cliente_ID, Cuota_ID, Pago_Monto, Pago_Referencia)
    VALUES(@LoanId, @MetodoPago_ID, @Cliente_ID, @Cuota_ID, @Monto, @Referencia);
SET @PaymentId=CONVERT(INT, SCOPE_IDENTITY());
COMMIT;
SELECT @PaymentId AS Pago_ID, (
    SELECT Prestamo_Saldo
    FROM Prestamo
    WHERE Prestamo_ID=@LoanId) AS Saldo;
END TRY
BEGIN CATCH
IF XACT_STATE()<>0
    ROLLBACK;
THROW;
END CATCH
END
GO
CREATE OR ALTER PROCEDURE sp_RevertirPago
@Pago_ID INT, @Motivo NVARCHAR(500), @Acceso_ID INT=NULL, @ReferenciaExterna NVARCHAR(100)=NULL
AS
BEGIN
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF NULLIF(LTRIM(RTRIM(@Motivo)), N'') IS NULL
    THROW 50040, N'Indique el motivo de la reversión.', 1;
BEGIN TRY
BEGIN TRANSACTION;
DECLARE @Monto DECIMAL(18, 2), @Estado NVARCHAR(20);
SELECT @Monto=Pago_Monto, @Estado=Pago_Estado
    FROM Pago WITH(UPDLOCK, HOLDLOCK)
    WHERE Pago_ID=@Pago_ID;
IF @Monto IS NULL
    THROW 50041, N'Pago no encontrado.', 1;
IF @Estado<>N'Aplicado'
    THROW 50042, N'Solo se puede revertir un pago aplicado.', 1;
INSERT ReversionPago(Pago_ID, Acceso_ID, ReversionPago_Monto, ReversionPago_Motivo, ReversionPago_ReferenciaExterna)
    VALUES(@Pago_ID, @Acceso_ID, @Monto, @Motivo, @ReferenciaExterna);
EXEC sys.sp_set_session_context @key=N'PagoReversion', @value=1;
UPDATE Pago
    SET Pago_Estado=N'Revertido', Pago_ReversadoFecha=SYSDATETIME(), Pago_ReversionMotivo=@Motivo
    WHERE Pago_ID=@Pago_ID;
EXEC sys.sp_set_session_context @key=N'PagoReversion', @value=NULL;
UPDATE ReversionPago
    SET ReversionPago_Estado=N'Aplicada'
    WHERE Pago_ID=@Pago_ID;
COMMIT;
END TRY
BEGIN CATCH
EXEC sys.sp_set_session_context @key=N'PagoReversion', @value=NULL;
IF XACT_STATE()<>0
    ROLLBACK;
THROW;
END CATCH
END
GO
CREATE OR ALTER PROCEDURE sp_RevertirDesembolso
@Desembolso_ID INT, @Motivo NVARCHAR(500), @Acceso_ID INT=NULL, @ReferenciaExterna NVARCHAR(100)=NULL
AS
BEGIN
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF NULLIF(LTRIM(RTRIM(@Motivo)), N'') IS NULL
    THROW 50043, N'Indique el motivo de la reversión.', 1;
BEGIN TRY
BEGIN TRANSACTION;
DECLARE @loan INT, @amount DECIMAL(18, 2), @status NVARCHAR(30), @cancelStatus INT;
SELECT @loan=d.Prestamo_ID, @amount=d.Desembolso_Monto, @status=d.Desembolso_Estado
    FROM Desembolso d WITH(UPDLOCK, HOLDLOCK)
    WHERE d.Desembolso_ID=@Desembolso_ID;
IF @loan IS NULL
    THROW 50044, N'Desembolso no encontrado.', 1;
IF @status<>N'Procesado'
    THROW 50045, N'Solo se puede revertir un desembolso procesado.', 1;
IF EXISTS(
    SELECT 1
    FROM Pago
    WHERE Prestamo_ID=@loan AND Pago_Estado=N'Aplicado')
    THROW 50046, N'No se puede revertir un desembolso con pagos aplicados; revierta los pagos primero.', 1;
SELECT @cancelStatus=EstadoPrestamo_ID
    FROM EstadoPrestamo
    WHERE EstadoPrestamo_Nombre=N'Cancelado';
IF @cancelStatus IS NULL
    THROW 50047, N'Falta el estado de préstamo Cancelado.', 1;
INSERT ReversionDesembolso(Desembolso_ID, Acceso_ID, ReversionDesembolso_Monto, ReversionDesembolso_Motivo, ReversionDesembolso_ReferenciaExterna)
    VALUES(@Desembolso_ID, @Acceso_ID, @amount, @Motivo, @ReferenciaExterna);
EXEC sys.sp_set_session_context @key=N'DesembolsoReversion', @value=1;
UPDATE Desembolso
    SET Desembolso_Estado=N'Revertido', Desembolso_Observacion=
    LEFT(CONCAT(COALESCE(Desembolso_Observacion+N' | ', N''), N'Reversión: ', @Motivo), 500)
    WHERE Desembolso_ID=@Desembolso_ID;
EXEC sys.sp_set_session_context @key=N'DesembolsoReversion', @value=NULL;
UPDATE Prestamo
    SET EstadoPrestamo_ID=@cancelStatus, Prestamo_Saldo=0
    WHERE Prestamo_ID=@loan;
COMMIT;
END TRY
BEGIN CATCH
EXEC sys.sp_set_session_context @key=N'DesembolsoReversion', @value=NULL;
IF XACT_STATE()<>0
    ROLLBACK;
THROW;
END CATCH
END
GO
