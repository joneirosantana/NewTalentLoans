/* =====================================================================
   NEW TALENT LOANS - Triggers adicionales (seccion 6.6 del script completo)
   Autor : Rousvet (para revision de Enrique Rodriguez Santana)
   Uso   : ejecutar sobre una base NewTalentLoans que ya tenga las tablas y
           TR_Pago_AfterInsert. Es seguro correrlo varias veces
           (CREATE OR ALTER). Si se parte de cero, usar
           NewTalentLoans_completo.sql, que ya lo incluye.
   ===================================================================== */
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

USE NewTalentLoans;
GO

/* =====================================================================
   6.6 TRIGGERS ADICIONALES - reglas de negocio y auditoria
   ---------------------------------------------------------------------
   Junto con TR_Pago_AfterInsert (6.5) el sistema queda con 4 triggers:

     TR_Pago_AfterInsert      Pago      INSERT  cascada de pagos (ya existente)
     TR_Solicitud_AfterUpdate Solicitud UPDATE  reglas de la solicitud (50030-50033)
     TR_Prestamo_AfterUpdate  Prestamo  UPDATE  auditoria de estado y no reabrir (50034)
     TR_Acceso_AfterUpdate    Acceso    UPDATE  auditoria de cuentas y ultimo admin (50035)

   COMPATIBILIDAD CON EL CODIGO EXISTENTE (error 334 de SQL Server):
   SQL Server rechaza INSERT ... OUTPUT INSERTED.x (sin INTO) solo cuando
   la tabla tiene un trigger habilitado para ESA MISMA accion. Como los tres
   triggers nuevos son AFTER UPDATE, no afectan a los INSERT ... OUTPUT
   INSERTED que hace el PHP sobre Solicitud, Prestamo y Acceso: ese codigo
   sigue funcionando sin cambios. Ningun trigger nuevo usa INSERT.

   Codigos de error nuevos (los existentes son 50001-50002, 50010-50015 y
   50020-50027): 50030 monto, 50031 plazo, 50032 estado, 50033 solicitud
   evaluada, 50034 prestamo cerrado, 50035 ultimo administrador.
   ===================================================================== */

/* 6.6.1 Reglas de la solicitud - requerimientos 7.2 / 7.3 */
CREATE OR ALTER TRIGGER dbo.TR_Solicitud_AfterUpdate
ON dbo.Solicitud
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    /* Regla 1: una solicitud ya evaluada no puede volver a Pendiente */
    IF UPDATE(Solicitud_Estado)
    BEGIN
        IF EXISTS (SELECT 1
                   FROM inserted i
                   INNER JOIN deleted d ON d.Solicitud_ID = i.Solicitud_ID
                   WHERE d.Solicitud_Estado IN (N'Aprobada', N'Rechazada')
                     AND i.Solicitud_Estado = N'Pendiente')
        BEGIN
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            THROW 50032, N'Una solicitud ya evaluada no puede volver al estado Pendiente.', 1;
        END
    END

    IF UPDATE(Solicitud_Monto) OR UPDATE(Solicitud_Plazo)
       OR UPDATE(Solicitud_TipoPrestamoId) OR UPDATE(Solicitud_UsuarioId)
    BEGIN
        /* Regla 2: una solicitud evaluada no cambia de cliente, monto, plazo ni tipo.
           Solo se comparan valores realmente distintos: un UPDATE que reenvia los
           mismos datos (por ejemplo, el PUT generico de la API) se permite. */
        IF EXISTS (SELECT 1
                   FROM inserted i
                   INNER JOIN deleted d ON d.Solicitud_ID = i.Solicitud_ID
                   WHERE d.Solicitud_Estado IN (N'Aprobada', N'Rechazada')
                     AND (   i.Solicitud_Monto     <> d.Solicitud_Monto
                          OR i.Solicitud_Plazo     <> d.Solicitud_Plazo
                          OR i.Solicitud_UsuarioId <> d.Solicitud_UsuarioId
                          OR ISNULL(i.Solicitud_TipoPrestamoId, 0) <> ISNULL(d.Solicitud_TipoPrestamoId, 0)))
        BEGIN
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            THROW 50033, N'Una solicitud ya evaluada no puede cambiar su cliente, monto, plazo ni tipo de prestamo.', 1;
        END

        /* Regla 3: el monto debe estar dentro de los limites del tipo de prestamo */
        IF EXISTS (SELECT 1
                   FROM inserted i
                   INNER JOIN deleted d      ON d.Solicitud_ID = i.Solicitud_ID
                   INNER JOIN dbo.TipoPrestamo t ON t.TipoPrestamo_ID = i.Solicitud_TipoPrestamoId
                   WHERE (   i.Solicitud_Monto <> d.Solicitud_Monto
                          OR ISNULL(i.Solicitud_TipoPrestamoId, 0) <> ISNULL(d.Solicitud_TipoPrestamoId, 0))
                     AND (i.Solicitud_Monto < t.TipoPrestamo_MontoMinimo OR i.Solicitud_Monto > t.TipoPrestamo_MontoMaximo))
        BEGIN
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            THROW 50030, N'El monto de la solicitud esta fuera del rango permitido para el tipo de prestamo.', 1;
        END

        /* Regla 4: el plazo debe estar dentro de los limites del tipo de prestamo */
        IF EXISTS (SELECT 1
                   FROM inserted i
                   INNER JOIN deleted d      ON d.Solicitud_ID = i.Solicitud_ID
                   INNER JOIN dbo.TipoPrestamo t ON t.TipoPrestamo_ID = i.Solicitud_TipoPrestamoId
                   WHERE (   i.Solicitud_Plazo <> d.Solicitud_Plazo
                          OR ISNULL(i.Solicitud_TipoPrestamoId, 0) <> ISNULL(d.Solicitud_TipoPrestamoId, 0))
                     AND (i.Solicitud_Plazo < t.TipoPrestamo_PlazoMinimo OR i.Solicitud_Plazo > t.TipoPrestamo_PlazoMaximo))
        BEGIN
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            THROW 50031, N'El plazo de la solicitud esta fuera del rango permitido para el tipo de prestamo.', 1;
        END
    END
END
GO

/* 6.6.2 Auditoria de estado del prestamo - requerimientos 7.3 / 7.7 */
CREATE OR ALTER TRIGGER dbo.TR_Prestamo_AfterUpdate
ON dbo.Prestamo
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    /* UPDATE() es verdadero cuando la columna aparece en el SET, aunque el valor
       no cambie (TR_Pago_AfterInsert la incluye siempre); por eso abajo se
       compara el valor nuevo contra el anterior. */
    IF UPDATE(Prestamo_EstadoPrestamoId)
    BEGIN
        /* Regla: un prestamo Finalizado o Cancelado no se reabre */
        IF EXISTS (SELECT 1
                   FROM inserted i
                   INNER JOIN deleted d ON d.Prestamo_ID = i.Prestamo_ID
                   INNER JOIN dbo.EstadoPrestamo eo ON eo.EstadoPrestamo_ID = d.Prestamo_EstadoPrestamoId
                   INNER JOIN dbo.EstadoPrestamo en ON en.EstadoPrestamo_ID = i.Prestamo_EstadoPrestamoId
                   WHERE i.Prestamo_EstadoPrestamoId <> d.Prestamo_EstadoPrestamoId
                     AND eo.EstadoPrestamo_Nombre IN (N'Finalizado', N'Cancelado')
                     AND en.EstadoPrestamo_Nombre IN (N'Pendiente', N'Aprobado', N'Activo'))
        BEGIN
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            THROW 50034, N'Un prestamo Finalizado o Cancelado no puede volver a abrirse.', 1;
        END

        /* Auditoria de cada cambio real de estado */
        INSERT INTO dbo.Auditoria (Auditoria_Tabla, Auditoria_RegistroId, Auditoria_Accion, Auditoria_Detalle)
        SELECT N'Prestamo', i.Prestamo_ID, N'CAMBIO_ESTADO',
               CONCAT(N'Estado del prestamo ', i.Prestamo_Codigo, N': ',
                      eo.EstadoPrestamo_Nombre, N' -> ', en.EstadoPrestamo_Nombre)
        FROM inserted i
        INNER JOIN deleted d ON d.Prestamo_ID = i.Prestamo_ID
        INNER JOIN dbo.EstadoPrestamo eo ON eo.EstadoPrestamo_ID = d.Prestamo_EstadoPrestamoId
        INNER JOIN dbo.EstadoPrestamo en ON en.EstadoPrestamo_ID = i.Prestamo_EstadoPrestamoId
        WHERE i.Prestamo_EstadoPrestamoId <> d.Prestamo_EstadoPrestamoId;
    END
END
GO

/* 6.6.3 Auditoria y proteccion de cuentas de acceso - requerimiento 7.1 */
CREATE OR ALTER TRIGGER dbo.TR_Acceso_AfterUpdate
ON dbo.Acceso
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    /* Regla: el sistema no puede quedarse sin un administrador activo.
       En un trigger AFTER la tabla ya tiene el cambio aplicado: si antes habia
       un administrador activo entre las filas modificadas y ahora no queda
       ninguno en toda la tabla, se rechaza. */
    IF UPDATE(Acceso_Activo) OR UPDATE(Acceso_RolId)
    BEGIN
        IF EXISTS (SELECT 1
                   FROM deleted d
                   INNER JOIN dbo.Rol r ON r.Rol_ID = d.Acceso_RolId
                   WHERE r.Rol_Nombre = N'Administrador' AND d.Acceso_Activo = 1)
           AND NOT EXISTS (SELECT 1
                           FROM dbo.Acceso a
                           INNER JOIN dbo.Rol r2 ON r2.Rol_ID = a.Acceso_RolId
                           WHERE r2.Rol_Nombre = N'Administrador' AND a.Acceso_Activo = 1)
        BEGIN
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            THROW 50035, N'No se puede desactivar ni cambiar el rol del ultimo administrador activo.', 1;
        END
    END

    /* Cuenta activada o desactivada */
    INSERT INTO dbo.Auditoria (Auditoria_Tabla, Auditoria_RegistroId, Auditoria_Accion, Auditoria_Detalle)
    SELECT N'Acceso', i.Acceso_ID,
           CASE WHEN i.Acceso_Activo = 1 THEN N'ACTIVACION' ELSE N'DESACTIVACION' END,
           CONCAT(N'Cuenta ', i.Acceso_Correo,
                  CASE WHEN i.Acceso_Activo = 1 THEN N' activada.' ELSE N' desactivada.' END)
    FROM inserted i
    INNER JOIN deleted d ON d.Acceso_ID = i.Acceso_ID
    WHERE i.Acceso_Activo <> d.Acceso_Activo;

    /* Cambio de rol */
    INSERT INTO dbo.Auditoria (Auditoria_Tabla, Auditoria_RegistroId, Auditoria_Accion, Auditoria_Detalle)
    SELECT N'Acceso', i.Acceso_ID, N'CAMBIO_ROL',
           CONCAT(N'Rol de ', i.Acceso_Correo, N': ', ro.Rol_Nombre, N' -> ', rn.Rol_Nombre)
    FROM inserted i
    INNER JOIN deleted d ON d.Acceso_ID = i.Acceso_ID
    INNER JOIN dbo.Rol ro ON ro.Rol_ID = d.Acceso_RolId
    INNER JOIN dbo.Rol rn ON rn.Rol_ID = i.Acceso_RolId
    WHERE i.Acceso_RolId <> d.Acceso_RolId;

    /* Cambio de correo de acceso */
    INSERT INTO dbo.Auditoria (Auditoria_Tabla, Auditoria_RegistroId, Auditoria_Accion, Auditoria_Detalle)
    SELECT N'Acceso', i.Acceso_ID, N'CAMBIO_CORREO',
           CONCAT(N'Correo de acceso: ', d.Acceso_Correo, N' -> ', i.Acceso_Correo)
    FROM inserted i
    INNER JOIN deleted d ON d.Acceso_ID = i.Acceso_ID
    WHERE i.Acceso_Correo <> d.Acceso_Correo;

    /* Cambio de contrasena (nunca se guarda el hash en la bitacora) */
    INSERT INTO dbo.Auditoria (Auditoria_Tabla, Auditoria_RegistroId, Auditoria_Accion, Auditoria_Detalle)
    SELECT N'Acceso', i.Acceso_ID, N'CAMBIO_CONTRASENA',
           CONCAT(N'Se cambio la contrasena de ', i.Acceso_Correo, N'.')
    FROM inserted i
    INNER JOIN deleted d ON d.Acceso_ID = i.Acceso_ID
    WHERE i.Acceso_ContrasenaHash <> d.Acceso_ContrasenaHash;
END
GO

PRINT N'Triggers adicionales creados correctamente (TR_Solicitud_AfterUpdate, TR_Prestamo_AfterUpdate, TR_Acceso_AfterUpdate).';
GO

