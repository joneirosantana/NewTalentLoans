/* =====================================================================
   NEW TALENT LOANS - Pruebas de los triggers adicionales
   ---------------------------------------------------------------------
   Script   : NewTalentLoans_Tests_Triggers.sql
   Autor    : Rousvet (para revision de Enrique Rodriguez Santana)
   Base     : NewTalentLoans  (motor: SQL Server)
   Requiere : NewTalentLoans_completo.sql con la seccion 6.6 de triggers
              (TR_Solicitud_AfterUpdate, TR_Prestamo_AfterUpdate,
              TR_Acceso_AfterUpdate) y TR_Pago_AfterInsert activos.

   Mismo estilo que NewTalentLoans_Tests.sql: tabla #Resultados con OK/FAIL.
   Crea un cliente de prueba (cedula TEST-TRG-01), corre las pruebas y al
   final borra todo lo que creo, asi que se puede ejecutar varias veces.

   TS1-TS6  TR_Solicitud_AfterUpdate   (errores 50030 a 50033)
   TP1-TP3  TR_Prestamo_AfterUpdate    (error 50034 y auditoria)
   TA1-TA6  TR_Acceso_AfterUpdate      (error 50035 y auditoria)
   TC1      compatibilidad: INSERT ... OUTPUT INSERTED como hace el PHP
   ===================================================================== */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

USE NewTalentLoans;
GO

IF OBJECT_ID(N'tempdb..#Resultados') IS NOT NULL DROP TABLE #Resultados;
CREATE TABLE #Resultados (
    Prueba      NVARCHAR(20),
    Descripcion NVARCHAR(200),
    Resultado   NVARCHAR(10),
    Detalle     NVARCHAR(500)
);
IF OBJECT_ID(N'tempdb..#Ctx') IS NOT NULL DROP TABLE #Ctx;
CREATE TABLE #Ctx (Clave NVARCHAR(30) NOT NULL PRIMARY KEY, Valor INT NULL);
GO

PRINT N'';
PRINT N'=========================================================';
PRINT N'  PRE-VERIFICACION: triggers activos';
PRINT N'=========================================================';

DECLARE @Faltan NVARCHAR(300) = N'';
IF ISNULL(OBJECTPROPERTY(OBJECT_ID(N'dbo.TR_Pago_AfterInsert', N'TR'), N'ExecIsTriggerDisabled'), 1) = 1
    SET @Faltan = @Faltan + N' TR_Pago_AfterInsert';
IF ISNULL(OBJECTPROPERTY(OBJECT_ID(N'dbo.TR_Solicitud_AfterUpdate', N'TR'), N'ExecIsTriggerDisabled'), 1) = 1
    SET @Faltan = @Faltan + N' TR_Solicitud_AfterUpdate';
IF ISNULL(OBJECTPROPERTY(OBJECT_ID(N'dbo.TR_Prestamo_AfterUpdate', N'TR'), N'ExecIsTriggerDisabled'), 1) = 1
    SET @Faltan = @Faltan + N' TR_Prestamo_AfterUpdate';
IF ISNULL(OBJECTPROPERTY(OBJECT_ID(N'dbo.TR_Acceso_AfterUpdate', N'TR'), N'ExecIsTriggerDisabled'), 1) = 1
    SET @Faltan = @Faltan + N' TR_Acceso_AfterUpdate';

IF @Faltan <> N''
BEGIN
    PRINT N'FAIL: faltan o estan deshabilitados:' + @Faltan;
    THROW 50099, N'No se puede continuar sin los triggers activos.', 1;
END
PRINT N'OK:   los 4 triggers estan creados y habilitados.';
GO

/* =====================================================================
   0. LIMPIEZA DE DATOS DE CORRIDAS ANTERIORES
   ===================================================================== */
PRINT N'';
PRINT N'=========================================================';
PRINT N'  0. LIMPIEZA DE DATOS DE PRUEBAS ANTERIORES';
PRINT N'=========================================================';

DECLARE @Limp_UsrId INT, @Limp_AccId INT, @Limp_DirId INT, @Limp_PresId INT, @Limp_SolId INT;
SELECT @Limp_UsrId = Usuario_ID FROM dbo.Usuario WHERE Usuario_Cedula = N'TEST-TRG-01';

IF @Limp_UsrId IS NOT NULL
BEGIN
    WHILE EXISTS (SELECT 1 FROM dbo.Prestamo P
                  INNER JOIN dbo.Solicitud S ON S.Solicitud_ID = P.Prestamo_SolicitudId
                  WHERE S.Solicitud_UsuarioId = @Limp_UsrId)
    BEGIN
        SELECT TOP (1) @Limp_PresId = P.Prestamo_ID, @Limp_SolId = P.Prestamo_SolicitudId
        FROM dbo.Prestamo P
        INNER JOIN dbo.Solicitud S ON S.Solicitud_ID = P.Prestamo_SolicitudId
        WHERE S.Solicitud_UsuarioId = @Limp_UsrId;

        DELETE FROM dbo.Auditoria   WHERE Auditoria_Tabla = N'Pago' AND Auditoria_RegistroId IN (SELECT Pago_ID FROM dbo.Pago WHERE Pago_PrestamoId = @Limp_PresId);
        DELETE FROM dbo.Auditoria   WHERE Auditoria_Tabla = N'Prestamo' AND Auditoria_RegistroId = @Limp_PresId;
        DELETE FROM dbo.Facturacion WHERE Facturacion_PagoId IN (SELECT Pago_ID FROM dbo.Pago WHERE Pago_PrestamoId = @Limp_PresId);
        DELETE FROM dbo.PagoCuota   WHERE PagoCuota_PagoId IN (SELECT Pago_ID FROM dbo.Pago WHERE Pago_PrestamoId = @Limp_PresId);
        DELETE FROM dbo.Pago        WHERE Pago_PrestamoId = @Limp_PresId;
        DELETE FROM dbo.Mora        WHERE Mora_CuotaId IN (SELECT Cuota_ID FROM dbo.Cuota WHERE Cuota_PrestamoId = @Limp_PresId);
        DELETE FROM dbo.Cuota       WHERE Cuota_PrestamoId = @Limp_PresId;
        DELETE FROM dbo.Garante     WHERE Garante_PrestamoId = @Limp_PresId;
        DELETE FROM dbo.Prestamo    WHERE Prestamo_ID = @Limp_PresId;
        DELETE FROM dbo.EvaluacionSolicitud WHERE EvaluacionSolicitud_SolicitudId = @Limp_SolId;
        DELETE FROM dbo.Auditoria   WHERE Auditoria_Tabla = N'Solicitud' AND Auditoria_RegistroId = @Limp_SolId;
        DELETE FROM dbo.Solicitud   WHERE Solicitud_ID = @Limp_SolId;
    END

    DELETE FROM dbo.Auditoria WHERE Auditoria_Tabla = N'Solicitud' AND Auditoria_RegistroId IN (SELECT Solicitud_ID FROM dbo.Solicitud WHERE Solicitud_UsuarioId = @Limp_UsrId);
    DELETE FROM dbo.EvaluacionSolicitud WHERE EvaluacionSolicitud_SolicitudId IN (SELECT Solicitud_ID FROM dbo.Solicitud WHERE Solicitud_UsuarioId = @Limp_UsrId);
    DELETE FROM dbo.Solicitud WHERE Solicitud_UsuarioId = @Limp_UsrId;

    SELECT @Limp_AccId = Usuario_AccesoId, @Limp_DirId = Usuario_DireccionId FROM dbo.Usuario WHERE Usuario_ID = @Limp_UsrId;
    DELETE FROM dbo.Telefono WHERE Telefono_UsuarioId = @Limp_UsrId;
    DELETE FROM dbo.Correo   WHERE Correo_UsuarioId = @Limp_UsrId;
    DELETE FROM dbo.Usuario  WHERE Usuario_ID = @Limp_UsrId;
    DELETE FROM dbo.Auditoria WHERE Auditoria_Tabla = N'Acceso' AND Auditoria_RegistroId = @Limp_AccId;
    DELETE FROM dbo.Acceso   WHERE Acceso_ID = @Limp_AccId;
    DELETE FROM dbo.Direccion WHERE Direccion_ID = @Limp_DirId;
END

/* Acceso suelto que crea la prueba TC1 */
DELETE FROM dbo.Auditoria WHERE Auditoria_Tabla = N'Acceso' AND Auditoria_RegistroId IN (SELECT Acceso_ID FROM dbo.Acceso WHERE Acceso_Correo = N'tc1.trg@newtalentloans.local');
DELETE FROM dbo.Acceso WHERE Acceso_Correo = N'tc1.trg@newtalentloans.local';

PRINT N'OK:   limpieza terminada.';
GO

/* =====================================================================
   1. PREPARANDO DATOS DE PRUEBA
   ===================================================================== */
PRINT N'';
PRINT N'=========================================================';
PRINT N'  1. PREPARANDO DATOS DE PRUEBA';
PRINT N'=========================================================';

DECLARE @RolCli INT      = (SELECT Rol_ID FROM dbo.Rol WHERE Rol_Nombre = N'Cliente');
DECLARE @CiudadId INT    = (SELECT TOP (1) Ciudad_ID FROM dbo.Ciudad ORDER BY Ciudad_ID);
DECLARE @TipoPer INT     = (SELECT TipoPrestamo_ID FROM dbo.TipoPrestamo WHERE TipoPrestamo_Nombre = N'Personal');
DECLARE @DirId INT, @AccId INT, @UsrId INT, @SolId INT;

INSERT INTO dbo.Direccion (Direccion_CiudadId, Direccion_Descripcion)
VALUES (@CiudadId, N'Direccion del cliente de prueba de triggers');
SET @DirId = SCOPE_IDENTITY();

INSERT INTO dbo.Acceso (Acceso_RolId, Acceso_Correo, Acceso_ContrasenaHash, Acceso_Activo)
VALUES (@RolCli, N'cliente.trg@newtalentloans.local', N'HASH-DE-PRUEBA-1', 1);
SET @AccId = SCOPE_IDENTITY();

INSERT INTO dbo.Usuario (Usuario_DireccionId, Usuario_AccesoId, Usuario_Nombre, Usuario_Apellido, Usuario_Cedula, Usuario_Sueldo)
VALUES (@DirId, @AccId, N'Cliente', N'Triggers', N'TEST-TRG-01', 200000);
SET @UsrId = SCOPE_IDENTITY();

INSERT INTO dbo.Solicitud (Solicitud_UsuarioId, Solicitud_Monto, Solicitud_Plazo, Solicitud_Motivo, Solicitud_Estado, Solicitud_TipoPrestamoId)
VALUES (@UsrId, 60000, 6, N'Prueba de TR_Solicitud_AfterUpdate', N'Pendiente', @TipoPer);
SET @SolId = SCOPE_IDENTITY();

INSERT INTO #Ctx (Clave, Valor) VALUES (N'Usr', @UsrId);
INSERT INTO #Ctx (Clave, Valor) VALUES (N'Acc', @AccId);
INSERT INTO #Ctx (Clave, Valor) VALUES (N'Dir', @DirId);
INSERT INTO #Ctx (Clave, Valor) VALUES (N'SolPend', @SolId);
INSERT INTO #Ctx (Clave, Valor) VALUES (N'TipoPer', @TipoPer);
INSERT INTO #Ctx (Clave, Valor) VALUES (N'Admin',
    (SELECT TOP (1) U.Usuario_ID FROM dbo.Usuario U
     INNER JOIN dbo.Acceso A ON A.Acceso_ID = U.Usuario_AccesoId
     INNER JOIN dbo.Rol R ON R.Rol_ID = A.Acceso_RolId
     WHERE R.Rol_Nombre = N'Administrador' AND A.Acceso_Activo = 1 ORDER BY U.Usuario_ID));

PRINT N'OK:   cliente de prueba (Usuario_ID = ' + CAST(@UsrId AS NVARCHAR(10)) + N', sueldo 200000) y solicitud Personal 60000 a 6 meses (Solicitud_ID = ' + CAST(@SolId AS NVARCHAR(10)) + N').';
GO

/* =====================================================================
   TS1-TS3. TR_Solicitud_AfterUpdate sobre una solicitud Pendiente
   ===================================================================== */
PRINT N'';
PRINT N'=========================================================';
PRINT N'  TS1. UPDATE con monto fuera de rango (debe fallar 50030)';
PRINT N'=========================================================';

DECLARE @Sol INT = (SELECT Valor FROM #Ctx WHERE Clave = N'SolPend');
BEGIN TRY
    UPDATE dbo.Solicitud SET Solicitud_Monto = 900000 WHERE Solicitud_ID = @Sol;
    INSERT INTO #Resultados VALUES (N'TS1', N'Monto fuera de rango (Personal max 500000)', N'FAIL', N'El trigger no bloqueo el UPDATE.');
    PRINT N'FAIL: el UPDATE no debio permitirse.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 50030
    BEGIN
        INSERT INTO #Resultados VALUES (N'TS1', N'Monto fuera de rango (Personal max 500000)', N'OK', N'THROW 50030: ' + ERROR_MESSAGE());
        PRINT N'OK:   el trigger rechazo con 50030 como se esperaba.';
    END
    ELSE
    BEGIN
        INSERT INTO #Resultados VALUES (N'TS1', N'Monto fuera de rango (Personal max 500000)', N'FAIL', N'Codigo inesperado ' + CAST(ERROR_NUMBER() AS NVARCHAR(10)) + N': ' + ERROR_MESSAGE());
        PRINT N'FAIL: codigo inesperado ' + CAST(ERROR_NUMBER() AS NVARCHAR(10));
    END
END CATCH
GO

PRINT N'';
PRINT N'=========================================================';
PRINT N'  TS2. UPDATE con plazo fuera de rango (debe fallar 50031)';
PRINT N'=========================================================';

DECLARE @Sol INT = (SELECT Valor FROM #Ctx WHERE Clave = N'SolPend');
BEGIN TRY
    UPDATE dbo.Solicitud SET Solicitud_Plazo = 99 WHERE Solicitud_ID = @Sol;
    INSERT INTO #Resultados VALUES (N'TS2', N'Plazo fuera de rango (Personal max 36)', N'FAIL', N'El trigger no bloqueo el UPDATE.');
    PRINT N'FAIL: el UPDATE no debio permitirse.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 50031
    BEGIN
        INSERT INTO #Resultados VALUES (N'TS2', N'Plazo fuera de rango (Personal max 36)', N'OK', N'THROW 50031: ' + ERROR_MESSAGE());
        PRINT N'OK:   el trigger rechazo con 50031 como se esperaba.';
    END
    ELSE
    BEGIN
        INSERT INTO #Resultados VALUES (N'TS2', N'Plazo fuera de rango (Personal max 36)', N'FAIL', N'Codigo inesperado ' + CAST(ERROR_NUMBER() AS NVARCHAR(10)) + N': ' + ERROR_MESSAGE());
        PRINT N'FAIL: codigo inesperado ' + CAST(ERROR_NUMBER() AS NVARCHAR(10));
    END
END CATCH
GO

PRINT N'';
PRINT N'=========================================================';
PRINT N'  TS3. UPDATE valido de una solicitud Pendiente (debe pasar)';
PRINT N'=========================================================';

DECLARE @Sol INT = (SELECT Valor FROM #Ctx WHERE Clave = N'SolPend');
DECLARE @Monto DECIMAL(18,2), @Plazo INT;
BEGIN TRY
    UPDATE dbo.Solicitud SET Solicitud_Monto = 70000, Solicitud_Plazo = 12 WHERE Solicitud_ID = @Sol;
    SELECT @Monto = Solicitud_Monto, @Plazo = Solicitud_Plazo FROM dbo.Solicitud WHERE Solicitud_ID = @Sol;
    IF @Monto = 70000 AND @Plazo = 12
    BEGIN
        INSERT INTO #Resultados VALUES (N'TS3', N'UPDATE valido de solicitud Pendiente', N'OK', N'Monto=70000 Plazo=12');
        PRINT N'OK:   monto 70000 y plazo 12 aceptados.';
    END
    ELSE
    BEGIN
        INSERT INTO #Resultados VALUES (N'TS3', N'UPDATE valido de solicitud Pendiente', N'FAIL', N'Monto=' + CAST(@Monto AS NVARCHAR(20)) + N' Plazo=' + CAST(@Plazo AS NVARCHAR(10)));
        PRINT N'FAIL: los valores no cambiaron.';
    END
END TRY
BEGIN CATCH
    INSERT INTO #Resultados VALUES (N'TS3', N'UPDATE valido de solicitud Pendiente', N'FAIL', N'Error: ' + ERROR_MESSAGE());
    PRINT N'FAIL: ' + ERROR_MESSAGE();
END CATCH
GO

/* ---------------------------------------------------------------------
   Preparacion: aprobar la solicitud con sp_EvaluarSolicitud (crea el prestamo)
   --------------------------------------------------------------------- */
DECLARE @Sol INT = (SELECT Valor FROM #Ctx WHERE Clave = N'SolPend');
DECLARE @Admin INT = (SELECT Valor FROM #Ctx WHERE Clave = N'Admin');
DECLARE @TipoPer INT = (SELECT Valor FROM #Ctx WHERE Clave = N'TipoPer');

EXEC dbo.sp_EvaluarSolicitud @SolicitudId = @Sol, @EvaluadorId = @Admin, @Decision = N'Aprobada', @TipoPrestamoId = @TipoPer;

DECLARE @PresNueva INT = (SELECT Prestamo_ID FROM dbo.Prestamo WHERE Prestamo_SolicitudId = @Sol);
IF @PresNueva IS NULL
    THROW 50099, N'La solicitud no genero prestamo: no se puede seguir con las pruebas.', 1;
INSERT INTO #Ctx (Clave, Valor) VALUES (N'Pres', @PresNueva);
PRINT N'OK:   solicitud aprobada y prestamo creado (Prestamo_ID = ' + CAST(@PresNueva AS NVARCHAR(10)) + N').';
GO

PRINT N'';
PRINT N'=========================================================';
PRINT N'  TS4. Solicitud aprobada no vuelve a Pendiente (debe fallar 50032)';
PRINT N'=========================================================';

DECLARE @Sol INT = (SELECT Valor FROM #Ctx WHERE Clave = N'SolPend');
BEGIN TRY
    UPDATE dbo.Solicitud SET Solicitud_Estado = N'Pendiente' WHERE Solicitud_ID = @Sol;
    INSERT INTO #Resultados VALUES (N'TS4', N'Solicitud aprobada vuelve a Pendiente', N'FAIL', N'El trigger no bloqueo el UPDATE.');
    PRINT N'FAIL: el UPDATE no debio permitirse.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 50032
    BEGIN
        INSERT INTO #Resultados VALUES (N'TS4', N'Solicitud aprobada vuelve a Pendiente', N'OK', N'THROW 50032: ' + ERROR_MESSAGE());
        PRINT N'OK:   el trigger rechazo con 50032 como se esperaba.';
    END
    ELSE
    BEGIN
        INSERT INTO #Resultados VALUES (N'TS4', N'Solicitud aprobada vuelve a Pendiente', N'FAIL', N'Codigo inesperado ' + CAST(ERROR_NUMBER() AS NVARCHAR(10)) + N': ' + ERROR_MESSAGE());
        PRINT N'FAIL: codigo inesperado ' + CAST(ERROR_NUMBER() AS NVARCHAR(10));
    END
END CATCH
GO

PRINT N'';
PRINT N'=========================================================';
PRINT N'  TS5. Solicitud evaluada no cambia de monto (debe fallar 50033)';
PRINT N'=========================================================';

DECLARE @Sol INT = (SELECT Valor FROM #Ctx WHERE Clave = N'SolPend');
BEGIN TRY
    UPDATE dbo.Solicitud SET Solicitud_Monto = 65000 WHERE Solicitud_ID = @Sol;
    INSERT INTO #Resultados VALUES (N'TS5', N'Solicitud evaluada cambia de monto', N'FAIL', N'El trigger no bloqueo el UPDATE.');
    PRINT N'FAIL: el UPDATE no debio permitirse.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 50033
    BEGIN
        INSERT INTO #Resultados VALUES (N'TS5', N'Solicitud evaluada cambia de monto', N'OK', N'THROW 50033: ' + ERROR_MESSAGE());
        PRINT N'OK:   el trigger rechazo con 50033 como se esperaba.';
    END
    ELSE
    BEGIN
        INSERT INTO #Resultados VALUES (N'TS5', N'Solicitud evaluada cambia de monto', N'FAIL', N'Codigo inesperado ' + CAST(ERROR_NUMBER() AS NVARCHAR(10)) + N': ' + ERROR_MESSAGE());
        PRINT N'FAIL: codigo inesperado ' + CAST(ERROR_NUMBER() AS NVARCHAR(10));
    END
END CATCH
GO

PRINT N'';
PRINT N'=========================================================';
PRINT N'  TS6. UPDATE que reenvia los mismos datos (debe pasar)';
PRINT N'=========================================================';

DECLARE @Sol INT = (SELECT Valor FROM #Ctx WHERE Clave = N'SolPend');
DECLARE @Motivo NVARCHAR(300);
BEGIN TRY
    UPDATE dbo.Solicitud
    SET Solicitud_Monto = Solicitud_Monto, Solicitud_Plazo = Solicitud_Plazo, Solicitud_Motivo = N'Motivo editado'
    WHERE Solicitud_ID = @Sol;
    SELECT @Motivo = Solicitud_Motivo FROM dbo.Solicitud WHERE Solicitud_ID = @Sol;
    IF @Motivo = N'Motivo editado'
    BEGIN
        INSERT INTO #Resultados VALUES (N'TS6', N'UPDATE con los mismos datos (PUT de la API)', N'OK', N'Se permitio editar el motivo sin cambiar monto ni plazo.');
        PRINT N'OK:   el UPDATE sin cambios reales se permitio.';
    END
    ELSE
    BEGIN
        INSERT INTO #Resultados VALUES (N'TS6', N'UPDATE con los mismos datos (PUT de la API)', N'FAIL', N'El motivo no cambio.');
        PRINT N'FAIL: el motivo no cambio.';
    END
END TRY
BEGIN CATCH
    INSERT INTO #Resultados VALUES (N'TS6', N'UPDATE con los mismos datos (PUT de la API)', N'FAIL', N'Error: ' + ERROR_MESSAGE());
    PRINT N'FAIL: ' + ERROR_MESSAGE();
END CATCH
GO

/* =====================================================================
   TP1-TP3. TR_Prestamo_AfterUpdate
   ===================================================================== */
PRINT N'';
PRINT N'=========================================================';
PRINT N'  TP1. Cambio de estado queda en Auditoria';
PRINT N'=========================================================';

DECLARE @Pres INT = (SELECT Valor FROM #Ctx WHERE Clave = N'Pres');
DECLARE @Cancelado INT = (SELECT EstadoPrestamo_ID FROM dbo.EstadoPrestamo WHERE EstadoPrestamo_Nombre = N'Cancelado');
DECLARE @Antes INT, @Despues INT, @Detalle NVARCHAR(500);
BEGIN TRY
    SELECT @Antes = COUNT(*) FROM dbo.Auditoria WHERE Auditoria_Tabla = N'Prestamo' AND Auditoria_RegistroId = @Pres AND Auditoria_Accion = N'CAMBIO_ESTADO';

    UPDATE dbo.Prestamo SET Prestamo_EstadoPrestamoId = @Cancelado WHERE Prestamo_ID = @Pres;

    SELECT @Despues = COUNT(*) FROM dbo.Auditoria WHERE Auditoria_Tabla = N'Prestamo' AND Auditoria_RegistroId = @Pres AND Auditoria_Accion = N'CAMBIO_ESTADO';
    SELECT TOP (1) @Detalle = Auditoria_Detalle FROM dbo.Auditoria
    WHERE Auditoria_Tabla = N'Prestamo' AND Auditoria_RegistroId = @Pres AND Auditoria_Accion = N'CAMBIO_ESTADO' ORDER BY Auditoria_ID DESC;

    IF @Despues = @Antes + 1 AND @Detalle LIKE N'%Activo -> Cancelado%'
    BEGIN
        INSERT INTO #Resultados VALUES (N'TP1', N'Cambio de estado del prestamo se audita', N'OK', @Detalle);
        PRINT N'OK:   ' + @Detalle;
    END
    ELSE
    BEGIN
        INSERT INTO #Resultados VALUES (N'TP1', N'Cambio de estado del prestamo se audita', N'FAIL', N'Antes=' + CAST(@Antes AS NVARCHAR(10)) + N' Despues=' + CAST(@Despues AS NVARCHAR(10)) + N' Detalle=' + ISNULL(@Detalle, N'NULL'));
        PRINT N'FAIL: ver #Resultados.';
    END
END TRY
BEGIN CATCH
    INSERT INTO #Resultados VALUES (N'TP1', N'Cambio de estado del prestamo se audita', N'FAIL', N'Error: ' + ERROR_MESSAGE());
    PRINT N'FAIL: ' + ERROR_MESSAGE();
END CATCH
GO

PRINT N'';
PRINT N'=========================================================';
PRINT N'  TP2. Prestamo Cancelado no se reabre (debe fallar 50034)';
PRINT N'=========================================================';

DECLARE @Pres INT = (SELECT Valor FROM #Ctx WHERE Clave = N'Pres');
DECLARE @Activo INT = (SELECT EstadoPrestamo_ID FROM dbo.EstadoPrestamo WHERE EstadoPrestamo_Nombre = N'Activo');
BEGIN TRY
    UPDATE dbo.Prestamo SET Prestamo_EstadoPrestamoId = @Activo WHERE Prestamo_ID = @Pres;
    INSERT INTO #Resultados VALUES (N'TP2', N'Prestamo Cancelado vuelve a Activo', N'FAIL', N'El trigger no bloqueo el UPDATE.');
    PRINT N'FAIL: el UPDATE no debio permitirse.';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 50034
    BEGIN
        INSERT INTO #Resultados VALUES (N'TP2', N'Prestamo Cancelado vuelve a Activo', N'OK', N'THROW 50034: ' + ERROR_MESSAGE());
        PRINT N'OK:   el trigger rechazo con 50034 como se esperaba.';
    END
    ELSE
    BEGIN
        INSERT INTO #Resultados VALUES (N'TP2', N'Prestamo Cancelado vuelve a Activo', N'FAIL', N'Codigo inesperado ' + CAST(ERROR_NUMBER() AS NVARCHAR(10)) + N': ' + ERROR_MESSAGE());
        PRINT N'FAIL: codigo inesperado ' + CAST(ERROR_NUMBER() AS NVARCHAR(10));
    END
END CATCH
GO

PRINT N'';
PRINT N'=========================================================';
PRINT N'  TP3. Integracion con TR_Pago_AfterInsert: al saldar el prestamo';
PRINT N'       se audita Activo -> Finalizado';
PRINT N'=========================================================';

DECLARE @Usr INT = (SELECT Valor FROM #Ctx WHERE Clave = N'Usr');
DECLARE @Admin INT = (SELECT Valor FROM #Ctx WHERE Clave = N'Admin');
DECLARE @TipoMicro INT = (SELECT TipoPrestamo_ID FROM dbo.TipoPrestamo WHERE TipoPrestamo_Nombre = N'Microcredito');
DECLARE @Efectivo INT = (SELECT MetodoPago_ID FROM dbo.MetodoPago WHERE MetodoPago_Nombre = N'Efectivo');
DECLARE @Sol2 INT, @Pres2 INT, @MontoCuota DECIMAL(18,2), @Cuenta INT, @Detalle NVARCHAR(500);
BEGIN TRY
    INSERT INTO dbo.Solicitud (Solicitud_UsuarioId, Solicitud_Monto, Solicitud_Plazo, Solicitud_Motivo, Solicitud_Estado, Solicitud_TipoPrestamoId)
    VALUES (@Usr, 1000, 1, N'Prueba TP3', N'Pendiente', @TipoMicro);
    SET @Sol2 = SCOPE_IDENTITY();

    EXEC dbo.sp_EvaluarSolicitud @SolicitudId = @Sol2, @EvaluadorId = @Admin, @Decision = N'Aprobada', @TipoPrestamoId = @TipoMicro;
    SELECT @Pres2 = Prestamo_ID FROM dbo.Prestamo WHERE Prestamo_SolicitudId = @Sol2;
    SELECT @MontoCuota = Cuota_Monto FROM dbo.Cuota WHERE Cuota_PrestamoId = @Pres2;

    INSERT INTO dbo.Pago (Pago_PrestamoId, Pago_MetodoPagoId, Pago_Monto, Pago_UsuarioId, Pago_Referencia)
    VALUES (@Pres2, @Efectivo, @MontoCuota, @Admin, N'TP3-FINALIZAR');

    SELECT @Cuenta = COUNT(*) FROM dbo.Auditoria
    WHERE Auditoria_Tabla = N'Prestamo' AND Auditoria_RegistroId = @Pres2 AND Auditoria_Accion = N'CAMBIO_ESTADO';
    SELECT TOP (1) @Detalle = Auditoria_Detalle FROM dbo.Auditoria
    WHERE Auditoria_Tabla = N'Prestamo' AND Auditoria_RegistroId = @Pres2 AND Auditoria_Accion = N'CAMBIO_ESTADO' ORDER BY Auditoria_ID DESC;

    IF @Cuenta = 1 AND @Detalle LIKE N'%Activo -> Finalizado%'
    BEGIN
        INSERT INTO #Resultados VALUES (N'TP3', N'Pago final audita Activo -> Finalizado (trigger anidado)', N'OK', @Detalle);
        PRINT N'OK:   ' + @Detalle;
    END
    ELSE
    BEGIN
        INSERT INTO #Resultados VALUES (N'TP3', N'Pago final audita Activo -> Finalizado (trigger anidado)', N'FAIL', N'Filas=' + CAST(@Cuenta AS NVARCHAR(10)) + N' Detalle=' + ISNULL(@Detalle, N'NULL'));
        PRINT N'FAIL: ver #Resultados.';
    END
END TRY
BEGIN CATCH
    INSERT INTO #Resultados VALUES (N'TP3', N'Pago final audita Activo -> Finalizado (trigger anidado)', N'FAIL', N'Error: ' + ERROR_MESSAGE());
    PRINT N'FAIL: ' + ERROR_MESSAGE();
END CATCH
GO

/* =====================================================================
   TA1-TA6. TR_Acceso_AfterUpdate
   ===================================================================== */
PRINT N'';
PRINT N'=========================================================';
PRINT N'  TA1. Desactivar y reactivar una cuenta se audita';
PRINT N'=========================================================';

DECLARE @Acc INT = (SELECT Valor FROM #Ctx WHERE Clave = N'Acc');
DECLARE @Desact INT, @Act INT;
BEGIN TRY
    UPDATE dbo.Acceso SET Acceso_Activo = 0 WHERE Acceso_ID = @Acc;
    UPDATE dbo.Acceso SET Acceso_Activo = 1 WHERE Acceso_ID = @Acc;
    SELECT @Desact = COUNT(*) FROM dbo.Auditoria WHERE Auditoria_Tabla = N'Acceso' AND Auditoria_RegistroId = @Acc AND Auditoria_Accion = N'DESACTIVACION';
    SELECT @Act    = COUNT(*) FROM dbo.Auditoria WHERE Auditoria_Tabla = N'Acceso' AND Auditoria_RegistroId = @Acc AND Auditoria_Accion = N'ACTIVACION';
    IF @Desact = 1 AND @Act = 1
    BEGIN
        INSERT INTO #Resultados VALUES (N'TA1', N'Activar/desactivar cuenta se audita', N'OK', N'DESACTIVACION=1 ACTIVACION=1');
        PRINT N'OK:   1 DESACTIVACION y 1 ACTIVACION registradas.';
    END
    ELSE
    BEGIN
        INSERT INTO #Resultados VALUES (N'TA1', N'Activar/desactivar cuenta se audita', N'FAIL', N'DESACTIVACION=' + CAST(@Desact AS NVARCHAR(10)) + N' ACTIVACION=' + CAST(@Act AS NVARCHAR(10)));
        PRINT N'FAIL: ver #Resultados.';
    END
END TRY
BEGIN CATCH
    INSERT INTO #Resultados VALUES (N'TA1', N'Activar/desactivar cuenta se audita', N'FAIL', N'Error: ' + ERROR_MESSAGE());
    PRINT N'FAIL: ' + ERROR_MESSAGE();
END CATCH
GO

PRINT N'';
PRINT N'=========================================================';
PRINT N'  TA2. Cambio de rol se audita';
PRINT N'=========================================================';

DECLARE @Acc INT = (SELECT Valor FROM #Ctx WHERE Clave = N'Acc');
DECLARE @RolCli INT = (SELECT Rol_ID FROM dbo.Rol WHERE Rol_Nombre = N'Cliente');
DECLARE @RolCaj INT = (SELECT Rol_ID FROM dbo.Rol WHERE Rol_Nombre = N'Cajero');
DECLARE @Cuenta INT, @Detalle NVARCHAR(500);
BEGIN TRY
    UPDATE dbo.Acceso SET Acceso_RolId = @RolCaj WHERE Acceso_ID = @Acc;
    SELECT @Cuenta = COUNT(*) FROM dbo.Auditoria WHERE Auditoria_Tabla = N'Acceso' AND Auditoria_RegistroId = @Acc AND Auditoria_Accion = N'CAMBIO_ROL';
    SELECT TOP (1) @Detalle = Auditoria_Detalle FROM dbo.Auditoria WHERE Auditoria_Tabla = N'Acceso' AND Auditoria_RegistroId = @Acc AND Auditoria_Accion = N'CAMBIO_ROL' ORDER BY Auditoria_ID DESC;
    UPDATE dbo.Acceso SET Acceso_RolId = @RolCli WHERE Acceso_ID = @Acc;
    IF @Cuenta = 1 AND @Detalle LIKE N'%Cliente -> Cajero%'
    BEGIN
        INSERT INTO #Resultados VALUES (N'TA2', N'Cambio de rol se audita', N'OK', @Detalle);
        PRINT N'OK:   ' + @Detalle;
    END
    ELSE
    BEGIN
        INSERT INTO #Resultados VALUES (N'TA2', N'Cambio de rol se audita', N'FAIL', N'Filas=' + CAST(@Cuenta AS NVARCHAR(10)) + N' Detalle=' + ISNULL(@Detalle, N'NULL'));
        PRINT N'FAIL: ver #Resultados.';
    END
END TRY
BEGIN CATCH
    INSERT INTO #Resultados VALUES (N'TA2', N'Cambio de rol se audita', N'FAIL', N'Error: ' + ERROR_MESSAGE());
    PRINT N'FAIL: ' + ERROR_MESSAGE();
END CATCH
GO

PRINT N'';
PRINT N'=========================================================';
PRINT N'  TA3. Cambio de contrasena se audita sin guardar el hash';
PRINT N'=========================================================';

DECLARE @Acc INT = (SELECT Valor FROM #Ctx WHERE Clave = N'Acc');
DECLARE @Cuenta INT, @Detalle NVARCHAR(500);
BEGIN TRY
    UPDATE dbo.Acceso SET Acceso_ContrasenaHash = N'HASH-DE-PRUEBA-2' WHERE Acceso_ID = @Acc;
    SELECT @Cuenta = COUNT(*) FROM dbo.Auditoria WHERE Auditoria_Tabla = N'Acceso' AND Auditoria_RegistroId = @Acc AND Auditoria_Accion = N'CAMBIO_CONTRASENA';
    SELECT TOP (1) @Detalle = Auditoria_Detalle FROM dbo.Auditoria WHERE Auditoria_Tabla = N'Acceso' AND Auditoria_RegistroId = @Acc AND Auditoria_Accion = N'CAMBIO_CONTRASENA' ORDER BY Auditoria_ID DESC;
    IF @Cuenta = 1 AND @Detalle NOT LIKE N'%HASH-DE-PRUEBA%'
    BEGIN
        INSERT INTO #Resultados VALUES (N'TA3', N'Cambio de contrasena se audita (sin hash)', N'OK', @Detalle);
        PRINT N'OK:   ' + @Detalle;
    END
    ELSE
    BEGIN
        INSERT INTO #Resultados VALUES (N'TA3', N'Cambio de contrasena se audita (sin hash)', N'FAIL', N'Filas=' + CAST(@Cuenta AS NVARCHAR(10)) + N' Detalle=' + ISNULL(@Detalle, N'NULL'));
        PRINT N'FAIL: ver #Resultados.';
    END
END TRY
BEGIN CATCH
    INSERT INTO #Resultados VALUES (N'TA3', N'Cambio de contrasena se audita (sin hash)', N'FAIL', N'Error: ' + ERROR_MESSAGE());
    PRINT N'FAIL: ' + ERROR_MESSAGE();
END CATCH
GO

PRINT N'';
PRINT N'=========================================================';
PRINT N'  TA4. Actualizar el ultimo ingreso NO genera auditoria';
PRINT N'=========================================================';

DECLARE @Acc INT = (SELECT Valor FROM #Ctx WHERE Clave = N'Acc');
DECLARE @Antes INT, @Despues INT;
BEGIN TRY
    SELECT @Antes = COUNT(*) FROM dbo.Auditoria WHERE Auditoria_Tabla = N'Acceso' AND Auditoria_RegistroId = @Acc;
    UPDATE dbo.Acceso SET Acceso_UltimoIngreso = SYSDATETIME() WHERE Acceso_ID = @Acc;
    SELECT @Despues = COUNT(*) FROM dbo.Auditoria WHERE Auditoria_Tabla = N'Acceso' AND Auditoria_RegistroId = @Acc;
    IF @Antes = @Despues
    BEGIN
        INSERT INTO #Resultados VALUES (N'TA4', N'Inicio de sesion no llena la auditoria', N'OK', N'Filas antes=' + CAST(@Antes AS NVARCHAR(10)) + N' despues=' + CAST(@Despues AS NVARCHAR(10)));
        PRINT N'OK:   el inicio de sesion no genero filas de auditoria.';
    END
    ELSE
    BEGIN
        INSERT INTO #Resultados VALUES (N'TA4', N'Inicio de sesion no llena la auditoria', N'FAIL', N'Filas antes=' + CAST(@Antes AS NVARCHAR(10)) + N' despues=' + CAST(@Despues AS NVARCHAR(10)));
        PRINT N'FAIL: el trigger audito un cambio que no debia.';
    END
END TRY
BEGIN CATCH
    INSERT INTO #Resultados VALUES (N'TA4', N'Inicio de sesion no llena la auditoria', N'FAIL', N'Error: ' + ERROR_MESSAGE());
    PRINT N'FAIL: ' + ERROR_MESSAGE();
END CATCH
GO

PRINT N'';
PRINT N'=========================================================';
PRINT N'  TA5. No se desactiva al ultimo administrador (debe fallar 50035)';
PRINT N'=========================================================';

DECLARE @Adm INT = (SELECT TOP (1) A.Acceso_ID FROM dbo.Acceso A
                    INNER JOIN dbo.Rol R ON R.Rol_ID = A.Acceso_RolId
                    WHERE R.Rol_Nombre = N'Administrador' AND A.Acceso_Activo = 1 ORDER BY A.Acceso_ID);
DECLARE @NumAdm INT = (SELECT COUNT(*) FROM dbo.Acceso A
                       INNER JOIN dbo.Rol R ON R.Rol_ID = A.Acceso_RolId
                       WHERE R.Rol_Nombre = N'Administrador' AND A.Acceso_Activo = 1);
IF @NumAdm <> 1
BEGIN
    INSERT INTO #Resultados VALUES (N'TA5', N'Desactivar al ultimo administrador', N'SKIP', N'Hay ' + CAST(@NumAdm AS NVARCHAR(10)) + N' administradores activos; la prueba necesita exactamente 1.');
    PRINT N'SKIP: la prueba necesita exactamente 1 administrador activo.';
END
ELSE
BEGIN
    BEGIN TRY
        UPDATE dbo.Acceso SET Acceso_Activo = 0 WHERE Acceso_ID = @Adm;
        /* Si llega aqui el trigger fallo: se deja la cuenta como estaba */
        UPDATE dbo.Acceso SET Acceso_Activo = 1 WHERE Acceso_ID = @Adm;
        INSERT INTO #Resultados VALUES (N'TA5', N'Desactivar al ultimo administrador', N'FAIL', N'El trigger no bloqueo el UPDATE.');
        PRINT N'FAIL: el UPDATE no debio permitirse.';
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50035
        BEGIN
            INSERT INTO #Resultados VALUES (N'TA5', N'Desactivar al ultimo administrador', N'OK', N'THROW 50035: ' + ERROR_MESSAGE());
            PRINT N'OK:   el trigger rechazo con 50035 como se esperaba.';
        END
        ELSE
        BEGIN
            INSERT INTO #Resultados VALUES (N'TA5', N'Desactivar al ultimo administrador', N'FAIL', N'Codigo inesperado ' + CAST(ERROR_NUMBER() AS NVARCHAR(10)) + N': ' + ERROR_MESSAGE());
            PRINT N'FAIL: codigo inesperado ' + CAST(ERROR_NUMBER() AS NVARCHAR(10));
        END
    END CATCH
END
GO

PRINT N'';
PRINT N'=========================================================';
PRINT N'  TA6. No se le quita el rol al ultimo administrador (debe fallar 50035)';
PRINT N'=========================================================';

DECLARE @Adm INT = (SELECT TOP (1) A.Acceso_ID FROM dbo.Acceso A
                    INNER JOIN dbo.Rol R ON R.Rol_ID = A.Acceso_RolId
                    WHERE R.Rol_Nombre = N'Administrador' AND A.Acceso_Activo = 1 ORDER BY A.Acceso_ID);
DECLARE @NumAdm INT = (SELECT COUNT(*) FROM dbo.Acceso A
                       INNER JOIN dbo.Rol R ON R.Rol_ID = A.Acceso_RolId
                       WHERE R.Rol_Nombre = N'Administrador' AND A.Acceso_Activo = 1);
DECLARE @RolAdm INT = (SELECT Rol_ID FROM dbo.Rol WHERE Rol_Nombre = N'Administrador');
DECLARE @RolCli INT = (SELECT Rol_ID FROM dbo.Rol WHERE Rol_Nombre = N'Cliente');
IF @NumAdm <> 1
BEGIN
    INSERT INTO #Resultados VALUES (N'TA6', N'Quitar el rol al ultimo administrador', N'SKIP', N'Hay ' + CAST(@NumAdm AS NVARCHAR(10)) + N' administradores activos; la prueba necesita exactamente 1.');
    PRINT N'SKIP: la prueba necesita exactamente 1 administrador activo.';
END
ELSE
BEGIN
    BEGIN TRY
        UPDATE dbo.Acceso SET Acceso_RolId = @RolCli WHERE Acceso_ID = @Adm;
        /* Si llega aqui el trigger fallo: se restaura el rol */
        UPDATE dbo.Acceso SET Acceso_RolId = @RolAdm WHERE Acceso_ID = @Adm;
        INSERT INTO #Resultados VALUES (N'TA6', N'Quitar el rol al ultimo administrador', N'FAIL', N'El trigger no bloqueo el UPDATE.');
        PRINT N'FAIL: el UPDATE no debio permitirse.';
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50035
        BEGIN
            INSERT INTO #Resultados VALUES (N'TA6', N'Quitar el rol al ultimo administrador', N'OK', N'THROW 50035: ' + ERROR_MESSAGE());
            PRINT N'OK:   el trigger rechazo con 50035 como se esperaba.';
        END
        ELSE
        BEGIN
            INSERT INTO #Resultados VALUES (N'TA6', N'Quitar el rol al ultimo administrador', N'FAIL', N'Codigo inesperado ' + CAST(ERROR_NUMBER() AS NVARCHAR(10)) + N': ' + ERROR_MESSAGE());
            PRINT N'FAIL: codigo inesperado ' + CAST(ERROR_NUMBER() AS NVARCHAR(10));
        END
    END CATCH
END
GO

/* =====================================================================
   TC1. Compatibilidad con el PHP: INSERT ... OUTPUT INSERTED (sin INTO)
   Sobre Solicitud, Prestamo y Acceso el PHP usa OUTPUT INSERTED. SQL Server
   solo lo rechaza (error 334) si la tabla tiene un trigger de INSERT, y los
   triggers nuevos son de UPDATE. Cada INSERT muestra una fila con el ID.
   ===================================================================== */
PRINT N'';
PRINT N'=========================================================';
PRINT N'  TC1. INSERT ... OUTPUT INSERTED sigue funcionando';
PRINT N'=========================================================';

DECLARE @Usr INT = (SELECT Valor FROM #Ctx WHERE Clave = N'Usr');
DECLARE @TipoPer INT = (SELECT Valor FROM #Ctx WHERE Clave = N'TipoPer');
DECLARE @RolCli INT = (SELECT Rol_ID FROM dbo.Rol WHERE Rol_Nombre = N'Cliente');
DECLARE @EstadoAct INT = (SELECT EstadoPrestamo_ID FROM dbo.EstadoPrestamo WHERE EstadoPrestamo_Nombre = N'Activo');
DECLARE @Paso NVARCHAR(30) = N'Solicitud';
DECLARE @SolTC INT;
BEGIN TRY
    INSERT INTO dbo.Solicitud (Solicitud_UsuarioId, Solicitud_Monto, Solicitud_Plazo, Solicitud_Motivo, Solicitud_TipoPrestamoId)
    OUTPUT INSERTED.Solicitud_ID
    VALUES (@Usr, 10000, 6, N'Prueba TC1 OUTPUT', @TipoPer);
    SELECT @SolTC = MAX(Solicitud_ID) FROM dbo.Solicitud WHERE Solicitud_Motivo = N'Prueba TC1 OUTPUT';

    SET @Paso = N'Prestamo';
    INSERT INTO dbo.Prestamo (Prestamo_SolicitudId, Prestamo_TipoPrestamoId, Prestamo_EstadoPrestamoId, Prestamo_Monto, Prestamo_Tasa, Prestamo_Plazo, Prestamo_FechaDesembolso, Prestamo_Saldo)
    OUTPUT INSERTED.Prestamo_ID
    VALUES (@SolTC, @TipoPer, @EstadoAct, 10000, 12, 6, SYSDATETIME(), 10000);

    SET @Paso = N'Acceso';
    INSERT INTO dbo.Acceso (Acceso_RolId, Acceso_Correo, Acceso_ContrasenaHash, Acceso_Activo)
    OUTPUT INSERTED.Acceso_ID
    VALUES (@RolCli, N'tc1.trg@newtalentloans.local', N'HASH-DE-PRUEBA-3', 1);

    INSERT INTO #Resultados VALUES (N'TC1', N'INSERT ... OUTPUT INSERTED en Solicitud, Prestamo y Acceso', N'OK', N'Los tres INSERT con OUTPUT funcionaron.');
    PRINT N'OK:   los tres INSERT con OUTPUT INSERTED funcionaron.';
END TRY
BEGIN CATCH
    INSERT INTO #Resultados VALUES (N'TC1', N'INSERT ... OUTPUT INSERTED en Solicitud, Prestamo y Acceso', N'FAIL', N'Fallo en ' + @Paso + N': ' + ERROR_MESSAGE());
    PRINT N'FAIL en ' + @Paso + N': ' + ERROR_MESSAGE();
END CATCH
GO

/* =====================================================================
   RESUMEN
   ===================================================================== */
PRINT N'';
PRINT N'=========================================================';
PRINT N'  RESUMEN DE PRUEBAS';
PRINT N'=========================================================';

SELECT Prueba, Descripcion, Resultado, Detalle
FROM #Resultados
ORDER BY LEFT(Prueba, 2), CAST(SUBSTRING(Prueba, 3, 5) AS INT);

PRINT N'';
PRINT N'--- Conteo de resultados ---';
SELECT Resultado, COUNT(*) AS Total FROM #Resultados GROUP BY Resultado;

PRINT N'';
PRINT N'--- Auditoria generada por los triggers durante esta corrida ---';
SELECT TOP (30) Auditoria_Fecha, Auditoria_Tabla, Auditoria_Accion, Auditoria_Detalle
FROM dbo.Auditoria
WHERE Auditoria_Accion IN (N'CAMBIO_ESTADO', N'ACTIVACION', N'DESACTIVACION', N'CAMBIO_ROL', N'CAMBIO_CORREO', N'CAMBIO_CONTRASENA')
ORDER BY Auditoria_ID DESC;
GO

/* =====================================================================
   LIMPIEZA FINAL: se borra todo lo que creo la prueba
   ===================================================================== */
DECLARE @Fin_UsrId INT, @Fin_AccId INT, @Fin_DirId INT, @Fin_PresId INT, @Fin_SolId INT;
SELECT @Fin_UsrId = Usuario_ID FROM dbo.Usuario WHERE Usuario_Cedula = N'TEST-TRG-01';

IF @Fin_UsrId IS NOT NULL
BEGIN
    WHILE EXISTS (SELECT 1 FROM dbo.Prestamo P
                  INNER JOIN dbo.Solicitud S ON S.Solicitud_ID = P.Prestamo_SolicitudId
                  WHERE S.Solicitud_UsuarioId = @Fin_UsrId)
    BEGIN
        SELECT TOP (1) @Fin_PresId = P.Prestamo_ID, @Fin_SolId = P.Prestamo_SolicitudId
        FROM dbo.Prestamo P
        INNER JOIN dbo.Solicitud S ON S.Solicitud_ID = P.Prestamo_SolicitudId
        WHERE S.Solicitud_UsuarioId = @Fin_UsrId;

        DELETE FROM dbo.Auditoria   WHERE Auditoria_Tabla = N'Pago' AND Auditoria_RegistroId IN (SELECT Pago_ID FROM dbo.Pago WHERE Pago_PrestamoId = @Fin_PresId);
        DELETE FROM dbo.Auditoria   WHERE Auditoria_Tabla = N'Prestamo' AND Auditoria_RegistroId = @Fin_PresId;
        DELETE FROM dbo.Facturacion WHERE Facturacion_PagoId IN (SELECT Pago_ID FROM dbo.Pago WHERE Pago_PrestamoId = @Fin_PresId);
        DELETE FROM dbo.PagoCuota   WHERE PagoCuota_PagoId IN (SELECT Pago_ID FROM dbo.Pago WHERE Pago_PrestamoId = @Fin_PresId);
        DELETE FROM dbo.Pago        WHERE Pago_PrestamoId = @Fin_PresId;
        DELETE FROM dbo.Mora        WHERE Mora_CuotaId IN (SELECT Cuota_ID FROM dbo.Cuota WHERE Cuota_PrestamoId = @Fin_PresId);
        DELETE FROM dbo.Cuota       WHERE Cuota_PrestamoId = @Fin_PresId;
        DELETE FROM dbo.Garante     WHERE Garante_PrestamoId = @Fin_PresId;
        DELETE FROM dbo.Prestamo    WHERE Prestamo_ID = @Fin_PresId;
        DELETE FROM dbo.EvaluacionSolicitud WHERE EvaluacionSolicitud_SolicitudId = @Fin_SolId;
        DELETE FROM dbo.Auditoria   WHERE Auditoria_Tabla = N'Solicitud' AND Auditoria_RegistroId = @Fin_SolId;
        DELETE FROM dbo.Solicitud   WHERE Solicitud_ID = @Fin_SolId;
    END

    DELETE FROM dbo.Auditoria WHERE Auditoria_Tabla = N'Solicitud' AND Auditoria_RegistroId IN (SELECT Solicitud_ID FROM dbo.Solicitud WHERE Solicitud_UsuarioId = @Fin_UsrId);
    DELETE FROM dbo.EvaluacionSolicitud WHERE EvaluacionSolicitud_SolicitudId IN (SELECT Solicitud_ID FROM dbo.Solicitud WHERE Solicitud_UsuarioId = @Fin_UsrId);
    DELETE FROM dbo.Solicitud WHERE Solicitud_UsuarioId = @Fin_UsrId;

    SELECT @Fin_AccId = Usuario_AccesoId, @Fin_DirId = Usuario_DireccionId FROM dbo.Usuario WHERE Usuario_ID = @Fin_UsrId;
    DELETE FROM dbo.Telefono WHERE Telefono_UsuarioId = @Fin_UsrId;
    DELETE FROM dbo.Correo   WHERE Correo_UsuarioId = @Fin_UsrId;
    DELETE FROM dbo.Usuario  WHERE Usuario_ID = @Fin_UsrId;
    DELETE FROM dbo.Auditoria WHERE Auditoria_Tabla = N'Acceso' AND Auditoria_RegistroId = @Fin_AccId;
    DELETE FROM dbo.Acceso   WHERE Acceso_ID = @Fin_AccId;
    DELETE FROM dbo.Direccion WHERE Direccion_ID = @Fin_DirId;
END

DELETE FROM dbo.Auditoria WHERE Auditoria_Tabla = N'Acceso' AND Auditoria_RegistroId IN (SELECT Acceso_ID FROM dbo.Acceso WHERE Acceso_Correo = N'tc1.trg@newtalentloans.local');
DELETE FROM dbo.Acceso WHERE Acceso_Correo = N'tc1.trg@newtalentloans.local';

PRINT N'';
PRINT N'OK:   datos de prueba eliminados.';
PRINT N'=========================================================';
PRINT N'  FIN DEL SCRIPT DE PRUEBAS DE TRIGGERS';
PRINT N'=========================================================';
GO
