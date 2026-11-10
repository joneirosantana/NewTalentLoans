/* =====================================================================
   NEW TALENT LOANS - Pruebas del trigger TR_Pago_AfterInsert (v4)
   ---------------------------------------------------------------------
   Script   : NewTalentLoans_Tests.sql
   Autor    : Rousvet (para revision de Enrique Rodriguez Santana)
   Fecha    : 2026-10-28
   Base     : NewTalentLoans  (motor: SQL Server)
   Requiere : Haber ejecutado NewTalentLoans_completo.sql primero.

   Version 4 - Correcciones:
   - T5 crea la solicitud a nombre del cliente de prueba (TEST-0001). Antes
     usaba el administrador (Usuario_ID 1), que tiene sueldo 0: el monto de
     1000 superaba el sueldo, sp_EvaluarSolicitud exigia garante (error 50026)
     y el CATCH fallaba con el error 3930 al guardar el resultado.
   - El CATCH de T5 hace ROLLBACK si la transaccion quedo inutilizable.
   - T7 verifica el primer prestamo del cliente (el de T1 a T4 y T6).
   - La limpieza borra la solicitud huerfana que dejaba T5 en versiones viejas.

   Version 3 - Correcciones:
   - Cursor eliminado, reemplazado por bucle WHILE
   - Cliente con sueldo 200000 (no requiere garante para 60000)
   - T5 usa Microcredito (monto min 1000)
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
GO

PRINT N'';
PRINT N'=========================================================';
PRINT N'  PRE-VERIFICACION: trigger activo en dbo.Pago';
PRINT N'=========================================================';

IF NOT EXISTS (
    SELECT 1 FROM sys.triggers
    WHERE  parent_id = OBJECT_ID(N'dbo.Pago')
      AND  name = N'TR_Pago_AfterInsert'
      AND  is_disabled = 0
) BEGIN
    PRINT N'FAIL: TR_Pago_AfterInsert NO esta creado o esta deshabilitado.';
    THROW 50099, N'No se puede continuar sin el trigger activo.', 1;
END
PRINT N'OK:   TR_Pago_AfterInsert activo.';
GO

/* =====================================================================
   0.5 LIMPIEZA PREVIA - borrar datos de pruebas anteriores
   ===================================================================== */
PRINT N'';
PRINT N'=========================================================';
PRINT N'  0.5 LIMPIEZA DE DATOS DE PRUEBAS ANTERIORES';
PRINT N'=========================================================';

DECLARE @Limp_UsrId INT, @Limp_AccId INT, @Limp_DirId INT;
SELECT @Limp_UsrId = Usuario_ID FROM dbo.Usuario WHERE Usuario_Cedula = N'TEST-0001';

/* Residuo de las versiones 1 a 3 de T5: solicitud pendiente de 1000 a 1 mes a nombre del administrador */
DELETE FROM dbo.Solicitud
WHERE  Solicitud_UsuarioId = (SELECT Usuario_ID FROM dbo.Usuario WHERE Usuario_Cedula = N'ADMIN-0001')
  AND  Solicitud_Estado = N'Pendiente' AND Solicitud_Motivo IS NULL
  AND  Solicitud_Monto = 1000 AND Solicitud_Plazo = 1;

IF @Limp_UsrId IS NOT NULL
BEGIN
    /* Borrar todos los prestamos del cliente de prueba (uno por vez) */
    DECLARE @Limp_PresId INT, @Limp_SolId INT;

    WHILE EXISTS (
        SELECT 1 FROM dbo.Prestamo P
        INNER JOIN dbo.Solicitud S ON S.Solicitud_ID = P.Prestamo_SolicitudId
        WHERE S.Solicitud_UsuarioId = @Limp_UsrId
    )
    BEGIN
        SELECT TOP 1 @Limp_PresId = P.Prestamo_ID, @Limp_SolId = P.Prestamo_SolicitudId
        FROM dbo.Prestamo P
        INNER JOIN dbo.Solicitud S ON S.Solicitud_ID = P.Prestamo_SolicitudId
        WHERE S.Solicitud_UsuarioId = @Limp_UsrId;

        DELETE FROM dbo.Auditoria    WHERE Auditoria_RegistroId IN (SELECT Pago_ID FROM dbo.Pago WHERE Pago_PrestamoId = @Limp_PresId) AND Auditoria_Tabla = N'Pago';
        DELETE FROM dbo.Auditoria    WHERE Auditoria_RegistroId = @Limp_PresId AND Auditoria_Tabla = N'Prestamo';
        DELETE FROM dbo.Facturacion  WHERE Facturacion_PagoId IN (SELECT Pago_ID FROM dbo.Pago WHERE Pago_PrestamoId = @Limp_PresId);
        DELETE FROM dbo.PagoCuota    WHERE PagoCuota_PagoId IN (SELECT Pago_ID FROM dbo.Pago WHERE Pago_PrestamoId = @Limp_PresId);
        DELETE FROM dbo.Pago         WHERE Pago_PrestamoId = @Limp_PresId;
        DELETE FROM dbo.Mora         WHERE Mora_CuotaId IN (SELECT Cuota_ID FROM dbo.Cuota WHERE Cuota_PrestamoId = @Limp_PresId);
        DELETE FROM dbo.Cuota        WHERE Cuota_PrestamoId = @Limp_PresId;
        DELETE FROM dbo.Garante      WHERE Garante_PrestamoId = @Limp_PresId;
        DELETE FROM dbo.Prestamo     WHERE Prestamo_ID = @Limp_PresId;
        DELETE FROM dbo.EvaluacionSolicitud WHERE EvaluacionSolicitud_SolicitudId = @Limp_SolId;
        DELETE FROM dbo.Solicitud    WHERE Solicitud_ID = @Limp_SolId;
    END

    DELETE FROM dbo.EvaluacionSolicitud
    WHERE EvaluacionSolicitud_SolicitudId IN (
        SELECT Solicitud_ID FROM dbo.Solicitud WHERE Solicitud_UsuarioId = @Limp_UsrId
    );
    DELETE FROM dbo.Solicitud WHERE Solicitud_UsuarioId = @Limp_UsrId;

    SELECT @Limp_AccId = Usuario_AccesoId, @Limp_DirId = Usuario_DireccionId
    FROM dbo.Usuario WHERE Usuario_ID = @Limp_UsrId;
    DELETE FROM dbo.Telefono WHERE Telefono_UsuarioId = @Limp_UsrId;
    DELETE FROM dbo.Correo   WHERE Correo_UsuarioId = @Limp_UsrId;
    DELETE FROM dbo.Usuario  WHERE Usuario_ID = @Limp_UsrId;
    DELETE FROM dbo.Acceso   WHERE Acceso_ID = @Limp_AccId;
    DELETE FROM dbo.Direccion WHERE Direccion_ID = @Limp_DirId;

    PRINT N'OK:   Datos anteriores eliminados.';
END
ELSE
    PRINT N'OK:   No habia datos anteriores que limpiar.';
GO

/* =====================================================================
   1. DATOS DE PRUEBA - cliente con sueldo ALTO
   ===================================================================== */
PRINT N'';
PRINT N'=========================================================';
PRINT N'  1. PREPARANDO DATOS DE PRUEBA';
PRINT N'=========================================================';

DECLARE @RolCliId    INT, @PaisId INT, @ProvId INT, @CiudadId INT, @DirId INT;
DECLARE @CliAccId    INT, @CliUsrId INT;
DECLARE @MetodoEfeId INT, @EstadoActId INT, @TipoPerId INT;

SELECT @RolCliId    = Rol_ID            FROM dbo.Rol          WHERE Rol_Nombre          = N'Cliente';
SELECT @PaisId      = Pais_ID           FROM dbo.Pais         WHERE Pais_Nombre         = N'Republica Dominicana';
SELECT @EstadoActId = EstadoPrestamo_ID FROM dbo.EstadoPrestamo WHERE EstadoPrestamo_Nombre = N'Activo';
SELECT @MetodoEfeId = MetodoPago_ID     FROM dbo.MetodoPago   WHERE MetodoPago_Nombre   = N'Efectivo';
SELECT @TipoPerId   = TipoPrestamo_ID   FROM dbo.TipoPrestamo WHERE TipoPrestamo_Nombre = N'Personal';

IF NOT EXISTS (SELECT 1 FROM dbo.Provincia WHERE Provincia_PaisId = @PaisId AND Provincia_Nombre = N'Distrito Nacional')
    INSERT INTO dbo.Provincia (Provincia_PaisId, Provincia_Nombre) VALUES (@PaisId, N'Distrito Nacional');
SELECT @ProvId = Provincia_ID FROM dbo.Provincia WHERE Provincia_PaisId = @PaisId AND Provincia_Nombre = N'Distrito Nacional';

IF NOT EXISTS (SELECT 1 FROM dbo.Ciudad WHERE Ciudad_ProvinciaId = @ProvId AND Ciudad_Nombre = N'Santo Domingo')
    INSERT INTO dbo.Ciudad (Ciudad_ProvinciaId, Ciudad_Nombre) VALUES (@ProvId, N'Santo Domingo');
SELECT @CiudadId = Ciudad_ID FROM dbo.Ciudad WHERE Ciudad_ProvinciaId = @ProvId AND Ciudad_Nombre = N'Santo Domingo';

INSERT INTO dbo.Direccion (Direccion_CiudadId, Direccion_Descripcion)
VALUES (@CiudadId, N'Casa del cliente de prueba');
SET @DirId = SCOPE_IDENTITY();

INSERT INTO dbo.Acceso (Acceso_RolId, Acceso_Correo, Acceso_ContrasenaHash, Acceso_Activo)
VALUES (@RolCliId, N'cliente.test@newtalentloans.local',
        N'$2y$10$G/bSXxAAxwv3xCWAb/bXfuH8.CWgZdrQo3OmjkW6nk9jVI4z6h9KO', 1);
SET @CliAccId = SCOPE_IDENTITY();

INSERT INTO dbo.Usuario (Usuario_DireccionId, Usuario_AccesoId, Usuario_Nombre, Usuario_Apellido, Usuario_Cedula, Usuario_Sueldo)
VALUES (@DirId, @CliAccId, N'Cliente', N'Prueba', N'TEST-0001', 200000);
SET @CliUsrId = SCOPE_IDENTITY();

PRINT N'OK:   Cliente de prueba creado (Usuario_ID = ' + CAST(@CliUsrId AS NVARCHAR(10)) + N', sueldo = 200000).';
GO

DECLARE @CliUsrId INT = (SELECT Usuario_ID FROM dbo.Usuario WHERE Usuario_Cedula = N'TEST-0001');
DECLARE @CliSolId INT, @CliPresId INT, @TipoPerId INT;

SELECT @TipoPerId = TipoPrestamo_ID FROM dbo.TipoPrestamo WHERE TipoPrestamo_Nombre = N'Personal';

INSERT INTO dbo.Solicitud (Solicitud_UsuarioId, Solicitud_Monto, Solicitud_Plazo,
                           Solicitud_Motivo, Solicitud_Estado, Solicitud_TipoPrestamoId)
VALUES (@CliUsrId, 60000, 6, N'Prueba del trigger', N'Pendiente', @TipoPerId);
SET @CliSolId = SCOPE_IDENTITY();

EXEC dbo.sp_EvaluarSolicitud
     @SolicitudId = @CliSolId,
     @EvaluadorId = 1,
     @Decision    = N'Aprobada',
     @TipoPrestamoId = @TipoPerId;

SELECT TOP (1) @CliPresId = P.Prestamo_ID
FROM   dbo.Prestamo P
WHERE  P.Prestamo_SolicitudId = @CliSolId;

PRINT N'OK:   Solicitud aprobada. Prestamo creado (Prestamo_ID = ' + CAST(@CliPresId AS NVARCHAR(10)) + N').';

PRINT N'';
PRINT N'--- Tabla de amortizacion del prestamo de prueba ---';
SELECT  Cuota_Numero,
        Cuota_FechaVencimiento,
        Cuota_Monto,
        Cuota_Saldo,
        Cuota_Estado
FROM    dbo.Cuota
WHERE   Cuota_PrestamoId = @CliPresId
ORDER BY Cuota_Numero;
GO

PRINT N'';
PRINT N'=========================================================';
PRINT N'  2. CAPTURANDO ESTADO INICIAL DEL PRESTAMO';
PRINT N'=========================================================';

DECLARE @CliPresId INT, @SaldoInicial DECIMAL(18,2), @MontoCuota1 DECIMAL(18,2);

SELECT TOP (1) @CliPresId = P.Prestamo_ID
FROM   dbo.Usuario U
INNER JOIN dbo.Solicitud S ON S.Solicitud_UsuarioId = U.Usuario_ID
INNER JOIN dbo.Prestamo P ON P.Prestamo_SolicitudId = S.Solicitud_ID
INNER JOIN dbo.EstadoPrestamo E ON E.EstadoPrestamo_ID = P.Prestamo_EstadoPrestamoId
WHERE  U.Usuario_Cedula = N'TEST-0001' AND E.EstadoPrestamo_Nombre = N'Activo'
ORDER BY P.Prestamo_ID DESC;

SELECT @SaldoInicial = Prestamo_Saldo FROM dbo.Prestamo WHERE Prestamo_ID = @CliPresId;
SELECT @MontoCuota1  = Cuota_Monto     FROM dbo.Cuota
WHERE  Cuota_PrestamoId = @CliPresId AND Cuota_Numero = 1;

PRINT N'Prestamo de prueba ID : ' + CAST(@CliPresId AS NVARCHAR(10));
PRINT N'Saldo inicial         : ' + CAST(@SaldoInicial AS NVARCHAR(20));
PRINT N'Monto cuota #1        : ' + CAST(@MontoCuota1 AS NVARCHAR(20));
GO

PRINT N'';
PRINT N'=========================================================';
PRINT N'  T1. PAGO COMPLETO DE UNA CUOTA';
PRINT N'=========================================================';

DECLARE @T1_PresId INT, @T1_Monto DECIMAL(18,2), @T1_PagoId INT;
DECLARE @T1_SaldoAnt DECIMAL(18,2), @T1_SaldoDesp DECIMAL(18,2);
DECLARE @T1_EstadoCuota NVARCHAR(20), @T1_EstadoPres NVARCHAR(50);

SELECT TOP (1) @T1_PresId = P.Prestamo_ID
FROM   dbo.Usuario U
INNER JOIN dbo.Solicitud S ON S.Solicitud_UsuarioId = U.Usuario_ID
INNER JOIN dbo.Prestamo P ON P.Prestamo_SolicitudId = S.Solicitud_ID
INNER JOIN dbo.EstadoPrestamo E ON E.EstadoPrestamo_ID = P.Prestamo_EstadoPrestamoId
WHERE  U.Usuario_Cedula = N'TEST-0001' AND E.EstadoPrestamo_Nombre = N'Activo'
ORDER BY P.Prestamo_ID DESC;

SELECT @T1_Monto    = Cuota_Monto FROM dbo.Cuota
WHERE  Cuota_PrestamoId = @T1_PresId AND Cuota_Numero = 1;
SELECT @T1_SaldoAnt = Prestamo_Saldo FROM dbo.Prestamo WHERE Prestamo_ID = @T1_PresId;

PRINT N'  Prestamo_ID = ' + CAST(@T1_PresId AS NVARCHAR(10)) + N', Monto = ' + CAST(@T1_Monto AS NVARCHAR(20));

BEGIN TRY
    INSERT INTO dbo.Pago (Pago_PrestamoId, Pago_MetodoPagoId, Pago_Monto, Pago_UsuarioId, Pago_Referencia)
    VALUES (@T1_PresId, 1, @T1_Monto, 1, N'T1-PAGO-CUOTA1');
    SET @T1_PagoId = SCOPE_IDENTITY();

    SELECT @T1_SaldoDesp    = Prestamo_Saldo FROM dbo.Prestamo WHERE Prestamo_ID = @T1_PresId;
    SELECT @T1_EstadoCuota  = Cuota_Estado  FROM dbo.Cuota
    WHERE  Cuota_PrestamoId = @T1_PresId AND Cuota_Numero = 1;
    SELECT @T1_EstadoPres   = E.EstadoPrestamo_Nombre
    FROM   dbo.Prestamo P INNER JOIN dbo.EstadoPrestamo E ON E.EstadoPrestamo_ID = P.Prestamo_EstadoPrestamoId
    WHERE  P.Prestamo_ID = @T1_PresId;

    IF  @T1_EstadoCuota = N'Pagada'
        AND ABS(@T1_SaldoDesp - (@T1_SaldoAnt - @T1_Monto)) < 0.01
        AND @T1_EstadoPres = N'Activo'
    BEGIN
        INSERT INTO #Resultados VALUES (N'T1', N'Pago completo de una cuota', N'OK',
            N'Cuota #1=Pagada. Saldo: ' + CAST(@T1_SaldoAnt AS NVARCHAR(20)) + N' -> ' + CAST(@T1_SaldoDesp AS NVARCHAR(20)));
        PRINT N'OK:   Cuota #1 = Pagada. Saldo ' + CAST(@T1_SaldoAnt AS NVARCHAR(20)) + N' -> ' + CAST(@T1_SaldoDesp AS NVARCHAR(20));
    END
    ELSE BEGIN
        INSERT INTO #Resultados VALUES (N'T1', N'Pago completo de una cuota', N'FAIL',
            N'EstadoCuota=' + ISNULL(@T1_EstadoCuota, N'NULL') + N' EstadoPres=' + ISNULL(@T1_EstadoPres, N'NULL'));
        PRINT N'FAIL: ver tabla #Resultados.';
    END
END TRY
BEGIN CATCH
    INSERT INTO #Resultados VALUES (N'T1', N'Pago completo de una cuota', N'FAIL', N'Error: ' + ERROR_MESSAGE());
    PRINT N'FAIL: ' + ERROR_MESSAGE();
END CATCH
GO

PRINT N'';
PRINT N'=========================================================';
PRINT N'  T2. PAGO PARCIAL DE UNA CUOTA';
PRINT N'=========================================================';

DECLARE @T2_PresId INT, @T2_Monto DECIMAL(18,2), @T2_SaldoAnt DECIMAL(18,2), @T2_SaldoDesp DECIMAL(18,2);
DECLARE @T2_Estado NVARCHAR(20);

SELECT TOP (1) @T2_PresId = P.Prestamo_ID
FROM   dbo.Usuario U
INNER JOIN dbo.Solicitud S ON S.Solicitud_UsuarioId = U.Usuario_ID
INNER JOIN dbo.Prestamo P ON P.Prestamo_SolicitudId = S.Solicitud_ID
INNER JOIN dbo.EstadoPrestamo E ON E.EstadoPrestamo_ID = P.Prestamo_EstadoPrestamoId
WHERE  U.Usuario_Cedula = N'TEST-0001' AND E.EstadoPrestamo_Nombre = N'Activo'
ORDER BY P.Prestamo_ID DESC;

SELECT @T2_Monto    = Cuota_Monto / 2 FROM dbo.Cuota
WHERE  Cuota_PrestamoId = @T2_PresId AND Cuota_Numero = 2;
SELECT @T2_SaldoAnt = Prestamo_Saldo FROM dbo.Prestamo WHERE Prestamo_ID = @T2_PresId;

PRINT N'  Prestamo_ID = ' + CAST(@T2_PresId AS NVARCHAR(10)) + N', Monto = ' + CAST(@T2_Monto AS NVARCHAR(20));

BEGIN TRY
    INSERT INTO dbo.Pago (Pago_PrestamoId, Pago_MetodoPagoId, Pago_Monto, Pago_UsuarioId, Pago_Referencia)
    VALUES (@T2_PresId, 1, @T2_Monto, 1, N'T2-PAGO-PARCIAL');

    SELECT @T2_SaldoDesp = Prestamo_Saldo FROM dbo.Prestamo WHERE Prestamo_ID = @T2_PresId;
    SELECT @T2_Estado    = Cuota_Estado  FROM dbo.Cuota
    WHERE  Cuota_PrestamoId = @T2_PresId AND Cuota_Numero = 2;

    IF  @T2_Estado = N'Parcial'
        AND ABS(@T2_SaldoDesp - (@T2_SaldoAnt - @T2_Monto)) < 0.01
    BEGIN
        INSERT INTO #Resultados VALUES (N'T2', N'Pago parcial de una cuota', N'OK',
            N'Cuota #2=Parcial. Saldo: ' + CAST(@T2_SaldoAnt AS NVARCHAR(20)) + N' -> ' + CAST(@T2_SaldoDesp AS NVARCHAR(20)));
        PRINT N'OK:   Cuota #2 = Parcial. Saldo ' + CAST(@T2_SaldoAnt AS NVARCHAR(20)) + N' -> ' + CAST(@T2_SaldoDesp AS NVARCHAR(20));
    END
    ELSE BEGIN
        INSERT INTO #Resultados VALUES (N'T2', N'Pago parcial de una cuota', N'FAIL',
            N'EstadoCuota=' + ISNULL(@T2_Estado, N'NULL'));
        PRINT N'FAIL: ver #Resultados.';
    END
END TRY
BEGIN CATCH
    INSERT INTO #Resultados VALUES (N'T2', N'Pago parcial de una cuota', N'FAIL', N'Error: ' + ERROR_MESSAGE());
    PRINT N'FAIL: ' + ERROR_MESSAGE();
END CATCH
GO

PRINT N'';
PRINT N'=========================================================';
PRINT N'  T3. PAGO QUE CUBRE VARIAS CUOTAS';
PRINT N'=========================================================';

DECLARE @T3_PresId INT, @T3_SaldoRestanteCuota2 DECIMAL(18,2), @T3_MontoCuota3 DECIMAL(18,2);
DECLARE @T3_MontoTotal DECIMAL(18,2), @T3_SaldoAnt DECIMAL(18,2), @T3_SaldoDesp DECIMAL(18,2);
DECLARE @T3_EstC2 NVARCHAR(20), @T3_EstC3 NVARCHAR(20);
DECLARE @T3_CuotasAfectadas INT;

SELECT TOP (1) @T3_PresId = P.Prestamo_ID
FROM   dbo.Usuario U
INNER JOIN dbo.Solicitud S ON S.Solicitud_UsuarioId = U.Usuario_ID
INNER JOIN dbo.Prestamo P ON P.Prestamo_SolicitudId = S.Solicitud_ID
INNER JOIN dbo.EstadoPrestamo E ON E.EstadoPrestamo_ID = P.Prestamo_EstadoPrestamoId
WHERE  U.Usuario_Cedula = N'TEST-0001' AND E.EstadoPrestamo_Nombre = N'Activo'
ORDER BY P.Prestamo_ID DESC;

SELECT @T3_SaldoRestanteCuota2 = Cuota_Saldo FROM dbo.Cuota
WHERE  Cuota_PrestamoId = @T3_PresId AND Cuota_Numero = 2;
SELECT @T3_MontoCuota3  = Cuota_Saldo FROM dbo.Cuota
WHERE  Cuota_PrestamoId = @T3_PresId AND Cuota_Numero = 3;

SET @T3_MontoTotal = @T3_SaldoRestanteCuota2 + @T3_MontoCuota3;
SELECT @T3_SaldoAnt = Prestamo_Saldo FROM dbo.Prestamo WHERE Prestamo_ID = @T3_PresId;

PRINT N'  Prestamo_ID = ' + CAST(@T3_PresId AS NVARCHAR(10)) + N', Monto = ' + CAST(@T3_MontoTotal AS NVARCHAR(20));

BEGIN TRY
    INSERT INTO dbo.Pago (Pago_PrestamoId, Pago_MetodoPagoId, Pago_Monto, Pago_UsuarioId, Pago_Referencia)
    VALUES (@T3_PresId, 1, @T3_MontoTotal, 1, N'T3-PAGO-MULTI');

    SELECT @T3_EstC2 = Cuota_Estado FROM dbo.Cuota
    WHERE  Cuota_PrestamoId = @T3_PresId AND Cuota_Numero = 2;
    SELECT @T3_EstC3 = Cuota_Estado FROM dbo.Cuota
    WHERE  Cuota_PrestamoId = @T3_PresId AND Cuota_Numero = 3;
    SELECT @T3_SaldoDesp = Prestamo_Saldo FROM dbo.Prestamo WHERE Prestamo_ID = @T3_PresId;

    SELECT @T3_CuotasAfectadas = COUNT(*) FROM dbo.PagoCuota
    WHERE  PagoCuota_PagoId = SCOPE_IDENTITY();

    IF  @T3_EstC2 = N'Pagada' AND @T3_EstC3 = N'Pagada'
        AND @T3_CuotasAfectadas = 2
        AND ABS(@T3_SaldoDesp - (@T3_SaldoAnt - @T3_MontoTotal)) < 0.01
    BEGIN
        INSERT INTO #Resultados VALUES (N'T3', N'Pago que cubre varias cuotas', N'OK',
            N'Cuotas #2 y #3 = Pagada. PagoCuota = ' + CAST(@T3_CuotasAfectadas AS NVARCHAR(10)) + N' filas.');
        PRINT N'OK:   Cuotas #2 y #3 = Pagada. PagoCuota registro 2 filas.';
    END
    ELSE BEGIN
        INSERT INTO #Resultados VALUES (N'T3', N'Pago que cubre varias cuotas', N'FAIL',
            N'C2=' + ISNULL(@T3_EstC2, N'NULL') + N' C3=' + ISNULL(@T3_EstC3, N'NULL') + N' PagoCuota=' + CAST(@T3_CuotasAfectadas AS NVARCHAR(10)));
        PRINT N'FAIL: ver #Resultados.';
    END
END TRY
BEGIN CATCH
    INSERT INTO #Resultados VALUES (N'T3', N'Pago que cubre varias cuotas', N'FAIL', N'Error: ' + ERROR_MESSAGE());
    PRINT N'FAIL: ' + ERROR_MESSAGE();
END CATCH
GO

PRINT N'';
PRINT N'=========================================================';
PRINT N'  T4. PAGO QUE EXCEDE EL SALDO (debe fallar)';
PRINT N'=========================================================';

DECLARE @T4_PresId INT, @T4_SaldoActual DECIMAL(18,2), @T4_MontoExcesivo DECIMAL(18,2);
DECLARE @T4_ErrorCode INT, @T4_ErrorMsg NVARCHAR(500);

SELECT TOP (1) @T4_PresId = P.Prestamo_ID
FROM   dbo.Usuario U
INNER JOIN dbo.Solicitud S ON S.Solicitud_UsuarioId = U.Usuario_ID
INNER JOIN dbo.Prestamo P ON P.Prestamo_SolicitudId = S.Solicitud_ID
INNER JOIN dbo.EstadoPrestamo E ON E.EstadoPrestamo_ID = P.Prestamo_EstadoPrestamoId
WHERE  U.Usuario_Cedula = N'TEST-0001' AND E.EstadoPrestamo_Nombre = N'Activo'
ORDER BY P.Prestamo_ID DESC;

SELECT @T4_SaldoActual = Prestamo_Saldo FROM dbo.Prestamo WHERE Prestamo_ID = @T4_PresId;
SET @T4_MontoExcesivo = @T4_SaldoActual + 1000000;

PRINT N'  Prestamo_ID = ' + CAST(@T4_PresId AS NVARCHAR(10)) + N', Monto excesivo = ' + CAST(@T4_MontoExcesivo AS NVARCHAR(20));

BEGIN TRY
    INSERT INTO dbo.Pago (Pago_PrestamoId, Pago_MetodoPagoId, Pago_Monto, Pago_UsuarioId, Pago_Referencia)
    VALUES (@T4_PresId, 1, @T4_MontoExcesivo, 1, N'T4-PAGO-EXCESIVO');

    INSERT INTO #Resultados VALUES (N'T4', N'Pago excede saldo (debe fallar)', N'FAIL', N'El INSERT no debio prosperar.');
    PRINT N'FAIL: el pago excesivo NO debio registrarse.';
END TRY
BEGIN CATCH
    SET @T4_ErrorCode = ERROR_NUMBER();
    SET @T4_ErrorMsg  = ERROR_MESSAGE();

    IF @T4_ErrorCode = 50013
    BEGIN
        INSERT INTO #Resultados VALUES (N'T4', N'Pago excede saldo (debe fallar)', N'OK', N'THROW 50013: ' + @T4_ErrorMsg);
        PRINT N'OK:   El trigger rechazo con THROW 50013 como se esperaba.';
    END
    ELSE BEGIN
        INSERT INTO #Resultados VALUES (N'T4', N'Pago excede saldo (debe fallar)', N'FAIL',
            N'Codigo inesperado: ' + CAST(@T4_ErrorCode AS NVARCHAR(10)) + N' - ' + @T4_ErrorMsg);
        PRINT N'FAIL: codigo inesperado ' + CAST(@T4_ErrorCode AS NVARCHAR(10));
    END
END CATCH
GO

PRINT N'';
PRINT N'=========================================================';
PRINT N'  T5. PAGO A PRESTAMO FINALIZADO (debe fallar)';
PRINT N'=========================================================';

DECLARE @T5_TipoMicroId INT;
DECLARE @T5_CliId INT = (SELECT Usuario_ID FROM dbo.Usuario WHERE Usuario_Cedula = N'TEST-0001');
DECLARE @T5_SolId INT, @T5_PresId INT;
DECLARE @T5_ErrorCode INT, @T5_ErrorMsg NVARCHAR(500);

SELECT @T5_TipoMicroId = TipoPrestamo_ID FROM dbo.TipoPrestamo WHERE TipoPrestamo_Nombre = N'Microcredito';

PRINT N'  Usando tipo Microcredito (ID = ' + CAST(@T5_TipoMicroId AS NVARCHAR(10)) + N'), monto 1000.';

BEGIN TRY
    INSERT INTO dbo.Solicitud (Solicitud_UsuarioId, Solicitud_Monto, Solicitud_Plazo, Solicitud_Estado, Solicitud_TipoPrestamoId)
    VALUES (@T5_CliId, 1000, 1, N'Pendiente', @T5_TipoMicroId);
    SET @T5_SolId = SCOPE_IDENTITY();

    EXEC dbo.sp_EvaluarSolicitud @SolicitudId = @T5_SolId, @EvaluadorId = 1,
         @Decision = N'Aprobada', @TipoPrestamoId = @T5_TipoMicroId;

    SELECT @T5_PresId = Prestamo_ID FROM dbo.Prestamo WHERE Prestamo_SolicitudId = @T5_SolId;

    DECLARE @T5_MontoCuota DECIMAL(18,2);
    SELECT @T5_MontoCuota = Cuota_Monto FROM dbo.Cuota WHERE Cuota_PrestamoId = @T5_PresId;

    INSERT INTO dbo.Pago (Pago_PrestamoId, Pago_MetodoPagoId, Pago_Monto, Pago_UsuarioId, Pago_Referencia)
    VALUES (@T5_PresId, 1, @T5_MontoCuota, 1, N'T5-SETUP-FINALIZAR');

    PRINT N'  Prestamo ' + CAST(@T5_PresId AS NVARCHAR(10)) + N' finalizado. Probando pago adicional...';

    BEGIN TRY
        INSERT INTO dbo.Pago (Pago_PrestamoId, Pago_MetodoPagoId, Pago_Monto, Pago_UsuarioId, Pago_Referencia)
        VALUES (@T5_PresId, 1, 100, 1, N'T5-PAGO-A-FINALIZADO');

        INSERT INTO #Resultados VALUES (N'T5', N'Pago a prestamo finalizado (debe fallar)', N'FAIL', N'El INSERT no debio prosperar.');
        PRINT N'FAIL: el pago a finalizado NO debio registrarse.';
    END TRY
    BEGIN CATCH
        SET @T5_ErrorCode = ERROR_NUMBER();
        SET @T5_ErrorMsg  = ERROR_MESSAGE();

        IF @T5_ErrorCode = 50012
        BEGIN
            INSERT INTO #Resultados VALUES (N'T5', N'Pago a prestamo finalizado (debe fallar)', N'OK', N'THROW 50012: ' + @T5_ErrorMsg);
            PRINT N'OK:   El trigger rechazo con THROW 50012 como se esperaba.';
        END
        ELSE BEGIN
            INSERT INTO #Resultados VALUES (N'T5', N'Pago a prestamo finalizado (debe fallar)', N'FAIL',
                N'Codigo inesperado: ' + CAST(@T5_ErrorCode AS NVARCHAR(10)) + N' - ' + @T5_ErrorMsg);
            PRINT N'FAIL: codigo inesperado ' + CAST(@T5_ErrorCode AS NVARCHAR(10));
        END
    END CATCH
END TRY
BEGIN CATCH
    DECLARE @T5_MsgSetup NVARCHAR(500) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT INTO #Resultados VALUES (N'T5', N'Pago a prestamo finalizado (debe fallar)', N'FAIL', N'Error en setup: ' + @T5_MsgSetup);
    PRINT N'FAIL: error en setup de T5 - ' + @T5_MsgSetup;
END CATCH
GO

PRINT N'';
PRINT N'=========================================================';
PRINT N'  T6. PAGO FINAL QUE SALDA EL PRESTAMO';
PRINT N'=========================================================';

DECLARE @T6_PresId INT, @T6_SaldoFinal DECIMAL(18,2), @T6_EstadoFinal NVARCHAR(50);

SELECT TOP (1) @T6_PresId = P.Prestamo_ID
FROM   dbo.Usuario U
INNER JOIN dbo.Solicitud S ON S.Solicitud_UsuarioId = U.Usuario_ID
INNER JOIN dbo.Prestamo P ON P.Prestamo_SolicitudId = S.Solicitud_ID
INNER JOIN dbo.EstadoPrestamo E ON E.EstadoPrestamo_ID = P.Prestamo_EstadoPrestamoId
WHERE  U.Usuario_Cedula = N'TEST-0001' AND E.EstadoPrestamo_Nombre = N'Activo'
ORDER BY P.Prestamo_ID DESC;

SELECT @T6_SaldoFinal = Prestamo_Saldo FROM dbo.Prestamo WHERE Prestamo_ID = @T6_PresId;

PRINT N'  Prestamo_ID = ' + CAST(@T6_PresId AS NVARCHAR(10)) + N', Saldo final = ' + CAST(@T6_SaldoFinal AS NVARCHAR(20));

BEGIN TRY
    INSERT INTO dbo.Pago (Pago_PrestamoId, Pago_MetodoPagoId, Pago_Monto, Pago_UsuarioId, Pago_Referencia)
    VALUES (@T6_PresId, 1, @T6_SaldoFinal, 1, N'T6-PAGO-FINAL');

    SELECT @T6_EstadoFinal = E.EstadoPrestamo_Nombre
    FROM   dbo.Prestamo P INNER JOIN dbo.EstadoPrestamo E ON E.EstadoPrestamo_ID = P.Prestamo_EstadoPrestamoId
    WHERE  P.Prestamo_ID = @T6_PresId;
    SELECT @T6_SaldoFinal = Prestamo_Saldo FROM dbo.Prestamo WHERE Prestamo_ID = @T6_PresId;

    IF  @T6_EstadoFinal = N'Finalizado' AND @T6_SaldoFinal = 0
    BEGIN
        INSERT INTO #Resultados VALUES (N'T6', N'Pago final que sala el prestamo', N'OK', N'Estado=Finalizado. Saldo=0.');
        PRINT N'OK:   Prestamo Finalizado. Saldo = 0.';
    END
    ELSE BEGIN
        INSERT INTO #Resultados VALUES (N'T6', N'Pago final que sala el prestamo', N'FAIL',
            N'Estado=' + ISNULL(@T6_EstadoFinal, N'NULL') + N' Saldo=' + CAST(@T6_SaldoFinal AS NVARCHAR(20)));
        PRINT N'FAIL: ver #Resultados.';
    END
END TRY
BEGIN CATCH
    INSERT INTO #Resultados VALUES (N'T6', N'Pago final que sala el prestamo', N'FAIL', N'Error: ' + ERROR_MESSAGE());
    PRINT N'FAIL: ' + ERROR_MESSAGE();
END CATCH
GO

PRINT N'';
PRINT N'=========================================================';
PRINT N'  T7. VERIFICAR PagoCuota / Facturacion / Auditoria';
PRINT N'=========================================================';

DECLARE @T7_PresId INT;
SELECT TOP (1) @T7_PresId = P.Prestamo_ID
FROM   dbo.Usuario U
INNER JOIN dbo.Solicitud S ON S.Solicitud_UsuarioId = U.Usuario_ID
INNER JOIN dbo.Prestamo P ON P.Prestamo_SolicitudId = S.Solicitud_ID
WHERE  U.Usuario_Cedula = N'TEST-0001'
ORDER BY P.Prestamo_ID ASC;

DECLARE @T7_Pagos       INT, @T7_PagoCuota INT, @T7_Facturas INT, @T7_Auditoria INT;

SELECT @T7_Pagos       = COUNT(*) FROM dbo.Pago       WHERE Pago_PrestamoId  = @T7_PresId;
SELECT @T7_PagoCuota   = COUNT(*) FROM dbo.PagoCuota PC
       INNER JOIN dbo.Pago P ON P.Pago_ID = PC.PagoCuota_PagoId
       WHERE P.Pago_PrestamoId = @T7_PresId;
SELECT @T7_Facturas    = COUNT(*) FROM dbo.Facturacion F
       INNER JOIN dbo.Pago P ON P.Pago_ID = F.Facturacion_PagoId
       WHERE P.Pago_PrestamoId = @T7_PresId;
SELECT @T7_Auditoria   = COUNT(*) FROM dbo.Auditoria
       WHERE Auditoria_Tabla = N'Pago' AND Auditoria_RegistroId IN
             (SELECT Pago_ID FROM dbo.Pago WHERE Pago_PrestamoId = @T7_PresId);

PRINT N'Pagos registrados     : ' + CAST(@T7_Pagos     AS NVARCHAR(10));
PRINT N'Filas en PagoCuota    : ' + CAST(@T7_PagoCuota AS NVARCHAR(10));
PRINT N'Facturas emitidas     : ' + CAST(@T7_Facturas  AS NVARCHAR(10));
PRINT N'Registros en Auditoria: ' + CAST(@T7_Auditoria AS NVARCHAR(10));

IF  @T7_Facturas  = @T7_Pagos
    AND @T7_Auditoria = @T7_Pagos
    AND @T7_PagoCuota >= @T7_Pagos
    AND @T7_Pagos > 0
BEGIN
    INSERT INTO #Resultados VALUES (N'T7', N'Efectos colaterales (PagoCuota/Factura/Auditoria)', N'OK',
        N'Pagos=' + CAST(@T7_Pagos AS NVARCHAR(10)) + N' Facturas=' + CAST(@T7_Facturas AS NVARCHAR(10)) + N' Auditoria=' + CAST(@T7_Auditoria AS NVARCHAR(10)) + N' PagoCuota=' + CAST(@T7_PagoCuota AS NVARCHAR(10)));
    PRINT N'OK:   1 factura + 1 auditoria por cada pago.';
END
ELSE BEGIN
    INSERT INTO #Resultados VALUES (N'T7', N'Efectos colaterales (PagoCuota/Factura/Auditoria)', N'FAIL',
        N'Pagos=' + CAST(@T7_Pagos AS NVARCHAR(10)) + N' Facturas=' + CAST(@T7_Facturas AS NVARCHAR(10)) + N' Auditoria=' + CAST(@T7_Auditoria AS NVARCHAR(10)) + N' PagoCuota=' + CAST(@T7_PagoCuota AS NVARCHAR(10)));
    PRINT N'FAIL: ver #Resultados.';
END
GO

PRINT N'';
PRINT N'=========================================================';
PRINT N'  RESUMEN DE PRUEBAS';
PRINT N'=========================================================';

SELECT  Prueba,
        Descripcion,
        Resultado,
        Detalle
FROM    #Resultados
ORDER BY Prueba;

PRINT N'';
PRINT N'--- Conteo de resultados ---';
SELECT  Resultado, COUNT(*) AS Total
FROM    #Resultados
GROUP BY Resultado;

PRINT N'';
PRINT N'--- Estado final del prestamo de prueba ---';
SELECT  P.Prestamo_ID,
        P.Prestamo_Codigo,
        P.Prestamo_Saldo,
        E.EstadoPrestamo_Nombre AS Estado,
        (SELECT COUNT(*) FROM dbo.Cuota WHERE Cuota_PrestamoId = P.Prestamo_ID)               AS CuotasTotal,
        (SELECT COUNT(*) FROM dbo.Cuota WHERE Cuota_PrestamoId = P.Prestamo_ID AND Cuota_Estado = N'Pagada')    AS CuotasPagadas,
        (SELECT COUNT(*) FROM dbo.Pago WHERE Pago_PrestamoId = P.Prestamo_ID)                  AS PagosHechos,
        (SELECT COUNT(*) FROM dbo.Facturacion F INNER JOIN dbo.Pago P2 ON P2.Pago_ID = F.Facturacion_PagoId WHERE P2.Pago_PrestamoId = P.Prestamo_ID) AS FacturasEmitidas
FROM    dbo.Usuario U
INNER JOIN dbo.Solicitud S ON S.Solicitud_UsuarioId = U.Usuario_ID
INNER JOIN dbo.Prestamo P ON P.Prestamo_SolicitudId = S.Solicitud_ID
INNER JOIN dbo.EstadoPrestamo E ON E.EstadoPrestamo_ID = P.Prestamo_EstadoPrestamoId
WHERE   U.Usuario_Cedula = N'TEST-0001'
ORDER BY P.Prestamo_ID DESC;
GO

PRINT N'';
PRINT N'=========================================================';
PRINT N'  FIN DEL SCRIPT DE PRUEBAS';
PRINT N'=========================================================';
GO
