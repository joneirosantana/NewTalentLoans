/* =====================================================================
   NEW TALENT LOANS - Base de datos del sistema de prestamos
   CONTENIDO (22 tablas)
   --- Ubicacion y usuarios ---
    1 Pais                 2 Provincia            3 Ciudad
    4 Direccion            5 Rol                  6 Acceso
    7 Usuario              8 Telefono             9 Correo
   --- Catalogos del credito ---
   10 TipoPrestamo        11 EstadoPrestamo      12 MetodoPago
   --- Ciclo del credito ---
   13 Solicitud           14 EvaluacionSolicitud 15 Prestamo
   16 Garante             17 Cuota               18 Pago
   19 PagoCuota           20 Mora                21 Facturacion
   --- Control ---
   22 Auditoria

   Convencion (la misma del backend PHP): tabla en CamelCase y columna
   NombreTabla_Campo. La logica de negocio de pagos vive en el trigger
   AFTER INSERT TR_Pago_AfterInsert. Las reglas de las solicitudes, la
   auditoria de prestamos y la proteccion de cuentas viven en los triggers
   AFTER UPDATE TR_Solicitud_AfterUpdate, TR_Prestamo_AfterUpdate y
   TR_Acceso_AfterUpdate (seccion 6.6).

   IMPORTANTE - SQL Server y OUTPUT:
   SQL Server prohibe INSERT ... OUTPUT INSERTED.x (sin INTO) en tablas
   que tengan triggers habilitados (error 334). Por eso:
     * sp_RegistrarPago usa SCOPE_IDENTITY() para devolver el ID.
     * El PHP que invoca directamente dbo.Pago debe usar
       OUTPUT ... INTO @tabla o leer el ID con SCOPE_IDENTITY()
       en una segunda consulta. NO usar OUTPUT suelto.
     * Solicitud, Prestamo y Acceso solo tienen triggers de UPDATE, asi
       que su INSERT ... OUTPUT INSERTED sigue funcionando sin cambio (el
       error 334 solo aplica a triggers de la misma accion que el OUTPUT).
       Dbo.Pago es la unica tabla con trigger de INSERT.
   Otros procesos clave (amortizacion, mora, evaluacion de
   solicitudes) siguen en procedimientos almacenados.
   ===================================================================== */

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

/* ---------------------------------------------------------------------
   0. BASE DE DATOS
   --------------------------------------------------------------------- */
IF DB_ID(N'NewTalentLoans') IS NULL
    CREATE DATABASE NewTalentLoans COLLATE Modern_Spanish_CI_AI;
GO
USE NewTalentLoans;
GO

/* =====================================================================
   1. UBICACION Y USUARIOS
   ===================================================================== */

/* 1. Pais */
IF OBJECT_ID(N'dbo.Pais', N'U') IS NULL
CREATE TABLE dbo.Pais (
    Pais_ID      INT IDENTITY(1,1) NOT NULL,
    Pais_Nombre  NVARCHAR(100)     NOT NULL,
    CONSTRAINT PK_Pais PRIMARY KEY (Pais_ID),
    CONSTRAINT UQ_Pais_Nombre UNIQUE (Pais_Nombre)
);
GO

/* 2. Provincia */
IF OBJECT_ID(N'dbo.Provincia', N'U') IS NULL
CREATE TABLE dbo.Provincia (
    Provincia_ID      INT IDENTITY(1,1) NOT NULL,
    Provincia_PaisId  INT               NOT NULL,
    Provincia_Nombre  NVARCHAR(100)     NOT NULL,
    CONSTRAINT PK_Provincia PRIMARY KEY (Provincia_ID),
    CONSTRAINT FK_Provincia_Pais FOREIGN KEY (Provincia_PaisId) REFERENCES dbo.Pais (Pais_ID),
    CONSTRAINT UQ_Provincia_Pais_Nombre UNIQUE (Provincia_PaisId, Provincia_Nombre)
);
GO

/* 3. Ciudad */
IF OBJECT_ID(N'dbo.Ciudad', N'U') IS NULL
CREATE TABLE dbo.Ciudad (
    Ciudad_ID          INT IDENTITY(1,1) NOT NULL,
    Ciudad_ProvinciaId INT               NOT NULL,
    Ciudad_Nombre      NVARCHAR(100)     NOT NULL,
    CONSTRAINT PK_Ciudad PRIMARY KEY (Ciudad_ID),
    CONSTRAINT FK_Ciudad_Provincia FOREIGN KEY (Ciudad_ProvinciaId) REFERENCES dbo.Provincia (Provincia_ID),
    CONSTRAINT UQ_Ciudad_Provincia_Nombre UNIQUE (Ciudad_ProvinciaId, Ciudad_Nombre)
);
GO

/* 4. Direccion */
IF OBJECT_ID(N'dbo.Direccion', N'U') IS NULL
CREATE TABLE dbo.Direccion (
    Direccion_ID          INT IDENTITY(1,1) NOT NULL,
    Direccion_CiudadId    INT               NOT NULL,
    Direccion_Descripcion NVARCHAR(250)     NOT NULL,
    CONSTRAINT PK_Direccion PRIMARY KEY (Direccion_ID),
    CONSTRAINT FK_Direccion_Ciudad FOREIGN KEY (Direccion_CiudadId) REFERENCES dbo.Ciudad (Ciudad_ID),
    INDEX IX_Direccion_CiudadId NONCLUSTERED (Direccion_CiudadId)
);
GO

/* 5. Rol */
IF OBJECT_ID(N'dbo.Rol', N'U') IS NULL
CREATE TABLE dbo.Rol (
    Rol_ID          INT IDENTITY(1,1) NOT NULL,
    Rol_Nombre      NVARCHAR(50)      NOT NULL,
    Rol_Descripcion NVARCHAR(200)     NULL,
    CONSTRAINT PK_Rol PRIMARY KEY (Rol_ID),
    CONSTRAINT UQ_Rol_Nombre UNIQUE (Rol_Nombre)
);
GO

/* 6. Acceso (credenciales de ingreso al sistema) */
IF OBJECT_ID(N'dbo.Acceso', N'U') IS NULL
CREATE TABLE dbo.Acceso (
    Acceso_ID             INT IDENTITY(1,1) NOT NULL,
    Acceso_RolId          INT               NOT NULL,
    Acceso_Correo         NVARCHAR(150)     NOT NULL,
    Acceso_ContrasenaHash NVARCHAR(255)     NOT NULL,
    Acceso_Activo         BIT               NOT NULL CONSTRAINT DF_Acceso_Activo DEFAULT (1),
    Acceso_UltimoIngreso  DATETIME2(0)      NULL,
    Acceso_FechaCreacion  DATETIME2(0)      NOT NULL CONSTRAINT DF_Acceso_FechaCreacion DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Acceso PRIMARY KEY (Acceso_ID),
    CONSTRAINT FK_Acceso_Rol FOREIGN KEY (Acceso_RolId) REFERENCES dbo.Rol (Rol_ID),
    CONSTRAINT UQ_Acceso_Correo UNIQUE (Acceso_Correo),
    INDEX IX_Acceso_RolId NONCLUSTERED (Acceso_RolId)
);
GO

/* 7. Usuario (clientes y personal; el rol lo define Acceso) */
IF OBJECT_ID(N'dbo.Usuario', N'U') IS NULL
CREATE TABLE dbo.Usuario (
    Usuario_ID            INT IDENTITY(1,1) NOT NULL,
    Usuario_DireccionId   INT               NOT NULL,
    Usuario_AccesoId      INT               NOT NULL,
    Usuario_Nombre        NVARCHAR(100)     NOT NULL,
    Usuario_Apellido      NVARCHAR(100)     NOT NULL,
    Usuario_Cedula        NVARCHAR(30)      NOT NULL,
    Usuario_Sueldo        DECIMAL(18,2)     NOT NULL CONSTRAINT DF_Usuario_Sueldo DEFAULT (0),
    Usuario_FechaRegistro DATETIME2(0)      NOT NULL CONSTRAINT DF_Usuario_FechaRegistro DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Usuario PRIMARY KEY (Usuario_ID),
    CONSTRAINT FK_Usuario_Direccion FOREIGN KEY (Usuario_DireccionId) REFERENCES dbo.Direccion (Direccion_ID),
    CONSTRAINT FK_Usuario_Acceso FOREIGN KEY (Usuario_AccesoId) REFERENCES dbo.Acceso (Acceso_ID),
    CONSTRAINT UQ_Usuario_Acceso UNIQUE (Usuario_AccesoId),
    CONSTRAINT UQ_Usuario_Cedula UNIQUE (Usuario_Cedula),
    CONSTRAINT CK_Usuario_Sueldo CHECK (Usuario_Sueldo >= 0),
    INDEX IX_Usuario_Apellido_Nombre NONCLUSTERED (Usuario_Apellido, Usuario_Nombre)
);
GO

/* 8. Telefono */
IF OBJECT_ID(N'dbo.Telefono', N'U') IS NULL
CREATE TABLE dbo.Telefono (
    Telefono_ID        INT IDENTITY(1,1) NOT NULL,
    Telefono_UsuarioId INT               NOT NULL,
    Telefono_Numero    NVARCHAR(30)      NOT NULL,
    CONSTRAINT PK_Telefono PRIMARY KEY (Telefono_ID),
    CONSTRAINT FK_Telefono_Usuario FOREIGN KEY (Telefono_UsuarioId) REFERENCES dbo.Usuario (Usuario_ID),
    INDEX IX_Telefono_UsuarioId NONCLUSTERED (Telefono_UsuarioId)
);
GO

/* 9. Correo */
IF OBJECT_ID(N'dbo.Correo', N'U') IS NULL
CREATE TABLE dbo.Correo (
    Correo_ID        INT IDENTITY(1,1) NOT NULL,
    Correo_UsuarioId INT               NOT NULL,
    Correo_Direccion NVARCHAR(150)     NOT NULL,
    CONSTRAINT PK_Correo PRIMARY KEY (Correo_ID),
    CONSTRAINT FK_Correo_Usuario FOREIGN KEY (Correo_UsuarioId) REFERENCES dbo.Usuario (Usuario_ID),
    INDEX IX_Correo_UsuarioId NONCLUSTERED (Correo_UsuarioId)
);
GO

/* =====================================================================
   2. CATALOGOS DEL CREDITO
   ===================================================================== */

/* 10. TipoPrestamo
   TasaBase y TasaMora son porcentajes: TasaBase anual, TasaMora mensual. */
IF OBJECT_ID(N'dbo.TipoPrestamo', N'U') IS NULL
CREATE TABLE dbo.TipoPrestamo (
    TipoPrestamo_ID          INT IDENTITY(1,1) NOT NULL,
    TipoPrestamo_Nombre      NVARCHAR(80)      NOT NULL,
    TipoPrestamo_TasaBase    DECIMAL(7,4)      NOT NULL,
    TipoPrestamo_TasaMora    DECIMAL(7,4)      NOT NULL CONSTRAINT DF_TipoPrestamo_TasaMora DEFAULT (5),
    TipoPrestamo_DiasGracia  INT               NOT NULL CONSTRAINT DF_TipoPrestamo_DiasGracia DEFAULT (0),
    TipoPrestamo_PlazoMinimo INT               NOT NULL CONSTRAINT DF_TipoPrestamo_PlazoMin DEFAULT (1),
    TipoPrestamo_PlazoMaximo INT               NOT NULL CONSTRAINT DF_TipoPrestamo_PlazoMax DEFAULT (36),
    TipoPrestamo_MontoMinimo DECIMAL(18,2)     NOT NULL CONSTRAINT DF_TipoPrestamo_MontoMin DEFAULT (1000),
    TipoPrestamo_MontoMaximo DECIMAL(18,2)     NOT NULL CONSTRAINT DF_TipoPrestamo_MontoMax DEFAULT (1000000),
    TipoPrestamo_Activo      BIT               NOT NULL CONSTRAINT DF_TipoPrestamo_Activo DEFAULT (1),
    CONSTRAINT PK_TipoPrestamo PRIMARY KEY (TipoPrestamo_ID),
    CONSTRAINT UQ_TipoPrestamo_Nombre UNIQUE (TipoPrestamo_Nombre),
    CONSTRAINT CK_TipoPrestamo_Tasas CHECK (TipoPrestamo_TasaBase >= 0 AND TipoPrestamo_TasaMora >= 0),
    CONSTRAINT CK_TipoPrestamo_Gracia CHECK (TipoPrestamo_DiasGracia >= 0),
    CONSTRAINT CK_TipoPrestamo_Plazos CHECK (TipoPrestamo_PlazoMinimo > 0 AND TipoPrestamo_PlazoMinimo <= TipoPrestamo_PlazoMaximo),
    CONSTRAINT CK_TipoPrestamo_Montos CHECK (TipoPrestamo_MontoMinimo > 0 AND TipoPrestamo_MontoMinimo <= TipoPrestamo_MontoMaximo)
);
GO

/* 11. EstadoPrestamo */
IF OBJECT_ID(N'dbo.EstadoPrestamo', N'U') IS NULL
CREATE TABLE dbo.EstadoPrestamo (
    EstadoPrestamo_ID     INT IDENTITY(1,1) NOT NULL,
    EstadoPrestamo_Nombre NVARCHAR(50)      NOT NULL,
    CONSTRAINT PK_EstadoPrestamo PRIMARY KEY (EstadoPrestamo_ID),
    CONSTRAINT UQ_EstadoPrestamo_Nombre UNIQUE (EstadoPrestamo_Nombre)
);
GO

/* 12. MetodoPago */
IF OBJECT_ID(N'dbo.MetodoPago', N'U') IS NULL
CREATE TABLE dbo.MetodoPago (
    MetodoPago_ID          INT IDENTITY(1,1) NOT NULL,
    MetodoPago_Nombre      NVARCHAR(60)      NOT NULL,
    MetodoPago_Descripcion NVARCHAR(200)     NULL,
    CONSTRAINT PK_MetodoPago PRIMARY KEY (MetodoPago_ID),
    CONSTRAINT UQ_MetodoPago_Nombre UNIQUE (MetodoPago_Nombre)
);
GO

/* =====================================================================
   3. CICLO DEL CREDITO
   ===================================================================== */

/* 13. Solicitud (nace en estado Pendiente) */
IF OBJECT_ID(N'dbo.Solicitud', N'U') IS NULL
CREATE TABLE dbo.Solicitud (
    Solicitud_ID              INT IDENTITY(1,1) NOT NULL,
    Solicitud_UsuarioId       INT               NOT NULL,
    Solicitud_Fecha           DATE              NOT NULL CONSTRAINT DF_Solicitud_Fecha DEFAULT (CAST(SYSDATETIME() AS DATE)),
    Solicitud_Monto           DECIMAL(18,2)     NOT NULL,
    Solicitud_Plazo           INT               NOT NULL,
    Solicitud_Motivo          NVARCHAR(300)     NULL,
    Solicitud_Estado          NVARCHAR(20)      NOT NULL CONSTRAINT DF_Solicitud_Estado DEFAULT (N'Pendiente'),
    Solicitud_TipoPrestamoId  INT               NULL,
    Solicitud_MetodoPagoId    INT               NULL,
    Solicitud_GaranteNombre   NVARCHAR(150)     NULL,
    Solicitud_GaranteCedula   NVARCHAR(30)      NULL,
    Solicitud_GaranteTelefono NVARCHAR(30)      NULL,
    CONSTRAINT PK_Solicitud PRIMARY KEY (Solicitud_ID),
    CONSTRAINT FK_Solicitud_Usuario FOREIGN KEY (Solicitud_UsuarioId) REFERENCES dbo.Usuario (Usuario_ID),
    CONSTRAINT FK_Solicitud_TipoPrestamo FOREIGN KEY (Solicitud_TipoPrestamoId) REFERENCES dbo.TipoPrestamo (TipoPrestamo_ID),
    CONSTRAINT FK_Solicitud_MetodoPago FOREIGN KEY (Solicitud_MetodoPagoId) REFERENCES dbo.MetodoPago (MetodoPago_ID),
    CONSTRAINT CK_Solicitud_Monto CHECK (Solicitud_Monto > 0),
    CONSTRAINT CK_Solicitud_Plazo CHECK (Solicitud_Plazo > 0),
    CONSTRAINT CK_Solicitud_Estado CHECK (Solicitud_Estado IN (N'Pendiente', N'Aprobada', N'Rechazada')),
    INDEX IX_Solicitud_UsuarioId NONCLUSTERED (Solicitud_UsuarioId),
    INDEX IX_Solicitud_Estado NONCLUSTERED (Solicitud_Estado, Solicitud_Fecha)
);
GO

/* 14. EvaluacionSolicitud (decision del asesor/comite sobre cada solicitud) */
IF OBJECT_ID(N'dbo.EvaluacionSolicitud', N'U') IS NULL
CREATE TABLE dbo.EvaluacionSolicitud (
    EvaluacionSolicitud_ID           INT IDENTITY(1,1) NOT NULL,
    EvaluacionSolicitud_SolicitudId  INT               NOT NULL,
    EvaluacionSolicitud_UsuarioId    INT               NOT NULL,
    EvaluacionSolicitud_Decision     NVARCHAR(20)      NOT NULL,
    EvaluacionSolicitud_Fecha        DATETIME2(0)      NOT NULL CONSTRAINT DF_EvaluacionSolicitud_Fecha DEFAULT (SYSDATETIME()),
    EvaluacionSolicitud_Comentario   NVARCHAR(300)     NULL,
    CONSTRAINT PK_EvaluacionSolicitud PRIMARY KEY (EvaluacionSolicitud_ID),
    CONSTRAINT FK_EvaluacionSolicitud_Solicitud FOREIGN KEY (EvaluacionSolicitud_SolicitudId) REFERENCES dbo.Solicitud (Solicitud_ID),
    CONSTRAINT FK_EvaluacionSolicitud_Usuario FOREIGN KEY (EvaluacionSolicitud_UsuarioId) REFERENCES dbo.Usuario (Usuario_ID),
    CONSTRAINT CK_EvaluacionSolicitud_Decision CHECK (EvaluacionSolicitud_Decision IN (N'Pendiente', N'Aprobada', N'Rechazada')),
    INDEX IX_EvaluacionSolicitud_SolicitudId NONCLUSTERED (EvaluacionSolicitud_SolicitudId)
);
GO

/* 15. Prestamo (contrato generado al aprobar una solicitud; 1 solicitud = 1 prestamo) */
IF OBJECT_ID(N'dbo.Prestamo', N'U') IS NULL
CREATE TABLE dbo.Prestamo (
    Prestamo_ID               INT IDENTITY(1,1) NOT NULL,
    Prestamo_SolicitudId      INT               NOT NULL,
    Prestamo_TipoPrestamoId   INT               NOT NULL,
    Prestamo_EstadoPrestamoId INT               NOT NULL,
    Prestamo_Monto            DECIMAL(18,2)     NOT NULL,
    Prestamo_Tasa             DECIMAL(7,4)      NOT NULL,
    Prestamo_Plazo            INT               NOT NULL,
    Prestamo_FechaDesembolso  DATETIME2(0)      NULL,
    Prestamo_Saldo            DECIMAL(18,2)     NOT NULL,
    Prestamo_FechaAprobacion  DATETIME2(0)      NOT NULL CONSTRAINT DF_Prestamo_FechaAprobacion DEFAULT (SYSDATETIME()),
    Prestamo_Codigo           AS (N'PRE-' + RIGHT(N'000000' + CAST(Prestamo_ID AS NVARCHAR(10)), 6)) PERSISTED,
    CONSTRAINT PK_Prestamo PRIMARY KEY (Prestamo_ID),
    CONSTRAINT UQ_Prestamo_Solicitud UNIQUE (Prestamo_SolicitudId),
    CONSTRAINT FK_Prestamo_Solicitud FOREIGN KEY (Prestamo_SolicitudId) REFERENCES dbo.Solicitud (Solicitud_ID),
    CONSTRAINT FK_Prestamo_TipoPrestamo FOREIGN KEY (Prestamo_TipoPrestamoId) REFERENCES dbo.TipoPrestamo (TipoPrestamo_ID),
    CONSTRAINT FK_Prestamo_EstadoPrestamo FOREIGN KEY (Prestamo_EstadoPrestamoId) REFERENCES dbo.EstadoPrestamo (EstadoPrestamo_ID),
    CONSTRAINT CK_Prestamo_Monto CHECK (Prestamo_Monto > 0),
    CONSTRAINT CK_Prestamo_Tasa CHECK (Prestamo_Tasa >= 0),
    CONSTRAINT CK_Prestamo_Plazo CHECK (Prestamo_Plazo > 0),
    CONSTRAINT CK_Prestamo_Saldo CHECK (Prestamo_Saldo >= 0),
    INDEX IX_Prestamo_Estado NONCLUSTERED (Prestamo_EstadoPrestamoId),
    INDEX IX_Prestamo_Tipo NONCLUSTERED (Prestamo_TipoPrestamoId)
);
GO

/* 16. Garante */
IF OBJECT_ID(N'dbo.Garante', N'U') IS NULL
CREATE TABLE dbo.Garante (
    Garante_ID         INT IDENTITY(1,1) NOT NULL,
    Garante_PrestamoId INT               NOT NULL,
    Garante_Nombre     NVARCHAR(150)     NOT NULL,
    Garante_Cedula     NVARCHAR(30)      NOT NULL,
    Garante_Telefono   NVARCHAR(30)      NULL,
    CONSTRAINT PK_Garante PRIMARY KEY (Garante_ID),
    CONSTRAINT FK_Garante_Prestamo FOREIGN KEY (Garante_PrestamoId) REFERENCES dbo.Prestamo (Prestamo_ID),
    INDEX IX_Garante_PrestamoId NONCLUSTERED (Garante_PrestamoId)
);
GO

/* 17. Cuota (tabla de amortizacion)
   Cuota_Saldo        = lo que falta por pagar de ESA cuota (pagos parciales).
   Cuota_SaldoCapital = capital pendiente del prestamo despues de la cuota.
   Cuota_Estado       = Pendiente / Parcial / Pagada / Vencida. */
IF OBJECT_ID(N'dbo.Cuota', N'U') IS NULL
CREATE TABLE dbo.Cuota (
    Cuota_ID               INT IDENTITY(1,1) NOT NULL,
    Cuota_PrestamoId       INT               NOT NULL,
    Cuota_Numero           INT               NULL,
    Cuota_FechaVencimiento DATE              NOT NULL,
    Cuota_Capital          DECIMAL(18,2)     NOT NULL,
    Cuota_Interes          DECIMAL(18,2)     NOT NULL,
    Cuota_Monto            DECIMAL(18,2)     NOT NULL,
    Cuota_Saldo            DECIMAL(18,2)     NOT NULL,
    Cuota_Estado           NVARCHAR(20)      NOT NULL CONSTRAINT DF_Cuota_Estado DEFAULT (N'Pendiente'),
    Cuota_SaldoCapital     DECIMAL(18,2)     NULL,
    Cuota_MontoPagado      DECIMAL(18,2)     NOT NULL CONSTRAINT DF_Cuota_MontoPagado DEFAULT (0),
    Cuota_FechaPago        DATE              NULL,
    CONSTRAINT PK_Cuota PRIMARY KEY (Cuota_ID),
    CONSTRAINT FK_Cuota_Prestamo FOREIGN KEY (Cuota_PrestamoId) REFERENCES dbo.Prestamo (Prestamo_ID),
    CONSTRAINT CK_Cuota_Valores CHECK (Cuota_Capital >= 0 AND Cuota_Interes >= 0 AND Cuota_Monto >= 0 AND Cuota_Saldo >= 0 AND Cuota_MontoPagado >= 0),
    INDEX UX_Cuota_PrestamoNumero UNIQUE NONCLUSTERED (Cuota_PrestamoId, Cuota_Numero) WHERE Cuota_Numero IS NOT NULL,
    INDEX IX_Cuota_Vencimiento NONCLUSTERED (Cuota_FechaVencimiento, Cuota_Estado)
);
GO

/* 18. Pago (cada abono/transaccion; Pago_UsuarioId = usuario que registra el pago) */
IF OBJECT_ID(N'dbo.Pago', N'U') IS NULL
CREATE TABLE dbo.Pago (
    Pago_ID           INT IDENTITY(1,1) NOT NULL,
    Pago_PrestamoId   INT               NOT NULL,
    Pago_MetodoPagoId INT               NOT NULL,
    Pago_Fecha        DATETIME2(0)      NOT NULL CONSTRAINT DF_Pago_Fecha DEFAULT (SYSDATETIME()),
    Pago_Monto        DECIMAL(18,2)     NOT NULL,
    Pago_UsuarioId    INT               NOT NULL,
    Pago_Referencia   NVARCHAR(60)      NULL,
    CONSTRAINT PK_Pago PRIMARY KEY (Pago_ID),
    CONSTRAINT FK_Pago_Prestamo FOREIGN KEY (Pago_PrestamoId) REFERENCES dbo.Prestamo (Prestamo_ID),
    CONSTRAINT FK_Pago_MetodoPago FOREIGN KEY (Pago_MetodoPagoId) REFERENCES dbo.MetodoPago (MetodoPago_ID),
    CONSTRAINT FK_Pago_Usuario FOREIGN KEY (Pago_UsuarioId) REFERENCES dbo.Usuario (Usuario_ID),
    CONSTRAINT CK_Pago_Monto CHECK (Pago_Monto > 0),
    INDEX IX_Pago_PrestamoId NONCLUSTERED (Pago_PrestamoId, Pago_Fecha)
);
GO

/* 19. PagoCuota (a que cuotas se aplico cada pago: permite pagos parciales y abonos a varias cuotas) */
IF OBJECT_ID(N'dbo.PagoCuota', N'U') IS NULL
CREATE TABLE dbo.PagoCuota (
    PagoCuota_ID      INT IDENTITY(1,1) NOT NULL,
    PagoCuota_PagoId  INT               NOT NULL,
    PagoCuota_CuotaId INT               NOT NULL,
    PagoCuota_Monto   DECIMAL(18,2)     NOT NULL,
    CONSTRAINT PK_PagoCuota PRIMARY KEY (PagoCuota_ID),
    CONSTRAINT FK_PagoCuota_Pago FOREIGN KEY (PagoCuota_PagoId) REFERENCES dbo.Pago (Pago_ID),
    CONSTRAINT FK_PagoCuota_Cuota FOREIGN KEY (PagoCuota_CuotaId) REFERENCES dbo.Cuota (Cuota_ID),
    CONSTRAINT UQ_PagoCuota UNIQUE (PagoCuota_PagoId, PagoCuota_CuotaId),
    CONSTRAINT CK_PagoCuota_Monto CHECK (PagoCuota_Monto > 0),
    INDEX IX_PagoCuota_CuotaId NONCLUSTERED (PagoCuota_CuotaId)
);
GO

/* 20. Mora (cargo por atraso; un registro por cuota)
   Activa = la cuota sigue sin pagar y el cargo crece; Cerrada = la cuota se pago
   con atraso (monto final); Condonada = perdonada por la gerencia. */
IF OBJECT_ID(N'dbo.Mora', N'U') IS NULL
CREATE TABLE dbo.Mora (
    Mora_ID           INT IDENTITY(1,1) NOT NULL,
    Mora_CuotaId      INT               NOT NULL,
    Mora_DiasAtraso   INT               NOT NULL,
    Mora_TasaAplicada DECIMAL(7,4)      NOT NULL,
    Mora_Monto        DECIMAL(18,2)     NOT NULL,
    Mora_FechaCalculo DATE              NOT NULL,
    Mora_Estado       NVARCHAR(20)      NOT NULL CONSTRAINT DF_Mora_Estado DEFAULT (N'Activa'),
    CONSTRAINT PK_Mora PRIMARY KEY (Mora_ID),
    CONSTRAINT FK_Mora_Cuota FOREIGN KEY (Mora_CuotaId) REFERENCES dbo.Cuota (Cuota_ID),
    CONSTRAINT UQ_Mora_Cuota UNIQUE (Mora_CuotaId),
    CONSTRAINT CK_Mora_Valores CHECK (Mora_DiasAtraso >= 0 AND Mora_Monto >= 0 AND Mora_TasaAplicada >= 0),
    CONSTRAINT CK_Mora_Estado CHECK (Mora_Estado IN (N'Activa', N'Cerrada', N'Condonada'))
);
GO

/* 21. Facturacion (comprobante emitido por cada pago) */
IF OBJECT_ID(N'dbo.Facturacion', N'U') IS NULL
CREATE TABLE dbo.Facturacion (
    Facturacion_ID           INT IDENTITY(1,1) NOT NULL,
    Facturacion_MetodoPagoId INT               NOT NULL,
    Facturacion_Fecha        DATETIME2(0)      NOT NULL CONSTRAINT DF_Facturacion_Fecha DEFAULT (SYSDATETIME()),
    Facturacion_Monto        DECIMAL(18,2)     NOT NULL,
    Facturacion_Descripcion  NVARCHAR(250)     NULL,
    Facturacion_Estado       NVARCHAR(20)      NOT NULL CONSTRAINT DF_Facturacion_Estado DEFAULT (N'Emitida'),
    Facturacion_PagoId       INT               NULL,
    Facturacion_Numero       AS (N'FAC-' + RIGHT(N'000000' + CAST(Facturacion_ID AS NVARCHAR(10)), 6)) PERSISTED,
    CONSTRAINT PK_Facturacion PRIMARY KEY (Facturacion_ID),
    CONSTRAINT FK_Facturacion_MetodoPago FOREIGN KEY (Facturacion_MetodoPagoId) REFERENCES dbo.MetodoPago (MetodoPago_ID),
    CONSTRAINT FK_Facturacion_Pago FOREIGN KEY (Facturacion_PagoId) REFERENCES dbo.Pago (Pago_ID),
    CONSTRAINT CK_Facturacion_Monto CHECK (Facturacion_Monto >= 0),
    INDEX IX_Facturacion_PagoId NONCLUSTERED (Facturacion_PagoId)
);
GO

/* =====================================================================
   4. CONTROL
   ===================================================================== */

/* 22. Auditoria (bitacora de operaciones importantes) */
IF OBJECT_ID(N'dbo.Auditoria', N'U') IS NULL
CREATE TABLE dbo.Auditoria (
    Auditoria_ID         INT IDENTITY(1,1) NOT NULL,
    Auditoria_UsuarioId  INT               NULL,
    Auditoria_Tabla      NVARCHAR(60)      NOT NULL,
    Auditoria_RegistroId INT               NULL,
    Auditoria_Accion     NVARCHAR(40)      NOT NULL,
    Auditoria_Detalle    NVARCHAR(500)     NULL,
    Auditoria_Fecha      DATETIME2(0)      NOT NULL CONSTRAINT DF_Auditoria_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Auditoria PRIMARY KEY (Auditoria_ID),
    CONSTRAINT FK_Auditoria_Usuario FOREIGN KEY (Auditoria_UsuarioId) REFERENCES dbo.Usuario (Usuario_ID),
    INDEX IX_Auditoria_Tabla NONCLUSTERED (Auditoria_Tabla, Auditoria_RegistroId)
);
GO

/* =====================================================================
   5. DATOS INICIALES
   ===================================================================== */

/* Roles: el orden fija Administrador = 1 y Cliente = 2 en una base nueva.
   Despues de crear la base configure las variables de entorno del backend:
   NTL_ADMIN_ROLE_ID = ID de 'Administrador' y NTL_CLIENT_ROLE_ID = ID de 'Cliente'. */
IF NOT EXISTS (SELECT 1 FROM dbo.Rol WHERE Rol_Nombre = N'Administrador')
    INSERT INTO dbo.Rol (Rol_Nombre, Rol_Descripcion) VALUES (N'Administrador', N'Acceso total: gestion de clientes, creditos, reportes y configuracion');
IF NOT EXISTS (SELECT 1 FROM dbo.Rol WHERE Rol_Nombre = N'Cliente')
    INSERT INTO dbo.Rol (Rol_Nombre, Rol_Descripcion) VALUES (N'Cliente', N'Solicita prestamos y consulta sus cuotas, pagos y saldo');
IF NOT EXISTS (SELECT 1 FROM dbo.Rol WHERE Rol_Nombre = N'Asesor de Credito')
    INSERT INTO dbo.Rol (Rol_Nombre, Rol_Descripcion) VALUES (N'Asesor de Credito', N'Registra clientes y solicitudes y las evalua');
IF NOT EXISTS (SELECT 1 FROM dbo.Rol WHERE Rol_Nombre = N'Cajero')
    INSERT INTO dbo.Rol (Rol_Nombre, Rol_Descripcion) VALUES (N'Cajero', N'Registra pagos y emite comprobantes');
IF NOT EXISTS (SELECT 1 FROM dbo.Rol WHERE Rol_Nombre = N'Cobrador')
    INSERT INTO dbo.Rol (Rol_Nombre, Rol_Descripcion) VALUES (N'Cobrador', N'Da seguimiento a cuotas vencidas y mora');
GO

/* Estados del prestamo (el backend busca 'Activo' o 'Aprobado' y 'Finalizado') */
IF NOT EXISTS (SELECT 1 FROM dbo.EstadoPrestamo WHERE EstadoPrestamo_Nombre = N'Pendiente')  INSERT INTO dbo.EstadoPrestamo (EstadoPrestamo_Nombre) VALUES (N'Pendiente');
IF NOT EXISTS (SELECT 1 FROM dbo.EstadoPrestamo WHERE EstadoPrestamo_Nombre = N'Aprobado')   INSERT INTO dbo.EstadoPrestamo (EstadoPrestamo_Nombre) VALUES (N'Aprobado');
IF NOT EXISTS (SELECT 1 FROM dbo.EstadoPrestamo WHERE EstadoPrestamo_Nombre = N'Rechazado')  INSERT INTO dbo.EstadoPrestamo (EstadoPrestamo_Nombre) VALUES (N'Rechazado');
IF NOT EXISTS (SELECT 1 FROM dbo.EstadoPrestamo WHERE EstadoPrestamo_Nombre = N'Activo')     INSERT INTO dbo.EstadoPrestamo (EstadoPrestamo_Nombre) VALUES (N'Activo');
IF NOT EXISTS (SELECT 1 FROM dbo.EstadoPrestamo WHERE EstadoPrestamo_Nombre = N'Finalizado') INSERT INTO dbo.EstadoPrestamo (EstadoPrestamo_Nombre) VALUES (N'Finalizado');
IF NOT EXISTS (SELECT 1 FROM dbo.EstadoPrestamo WHERE EstadoPrestamo_Nombre = N'Cancelado')  INSERT INTO dbo.EstadoPrestamo (EstadoPrestamo_Nombre) VALUES (N'Cancelado');
GO

/* Tipos de prestamo (TasaBase = % anual, TasaMora = % mensual) */
IF NOT EXISTS (SELECT 1 FROM dbo.TipoPrestamo WHERE TipoPrestamo_Nombre = N'Personal')
    INSERT INTO dbo.TipoPrestamo (TipoPrestamo_Nombre, TipoPrestamo_TasaBase, TipoPrestamo_TasaMora, TipoPrestamo_DiasGracia, TipoPrestamo_PlazoMinimo, TipoPrestamo_PlazoMaximo, TipoPrestamo_MontoMinimo, TipoPrestamo_MontoMaximo)
    VALUES (N'Personal', 12, 5, 3, 3, 36, 5000, 500000);
IF NOT EXISTS (SELECT 1 FROM dbo.TipoPrestamo WHERE TipoPrestamo_Nombre = N'Comercial')
    INSERT INTO dbo.TipoPrestamo (TipoPrestamo_Nombre, TipoPrestamo_TasaBase, TipoPrestamo_TasaMora, TipoPrestamo_DiasGracia, TipoPrestamo_PlazoMinimo, TipoPrestamo_PlazoMaximo, TipoPrestamo_MontoMinimo, TipoPrestamo_MontoMaximo)
    VALUES (N'Comercial', 15, 5, 3, 6, 36, 10000, 1000000);
IF NOT EXISTS (SELECT 1 FROM dbo.TipoPrestamo WHERE TipoPrestamo_Nombre = N'Microcredito')
    INSERT INTO dbo.TipoPrestamo (TipoPrestamo_Nombre, TipoPrestamo_TasaBase, TipoPrestamo_TasaMora, TipoPrestamo_DiasGracia, TipoPrestamo_PlazoMinimo, TipoPrestamo_PlazoMaximo, TipoPrestamo_MontoMinimo, TipoPrestamo_MontoMaximo)
    VALUES (N'Microcredito', 18, 6, 2, 1, 12, 1000, 50000);
GO

/* Metodos de pago */
IF NOT EXISTS (SELECT 1 FROM dbo.MetodoPago WHERE MetodoPago_Nombre = N'Efectivo')      INSERT INTO dbo.MetodoPago (MetodoPago_Nombre, MetodoPago_Descripcion) VALUES (N'Efectivo', N'Pago en efectivo');
IF NOT EXISTS (SELECT 1 FROM dbo.MetodoPago WHERE MetodoPago_Nombre = N'Transferencia') INSERT INTO dbo.MetodoPago (MetodoPago_Nombre, MetodoPago_Descripcion) VALUES (N'Transferencia', N'Transferencia bancaria');
IF NOT EXISTS (SELECT 1 FROM dbo.MetodoPago WHERE MetodoPago_Nombre = N'Deposito')      INSERT INTO dbo.MetodoPago (MetodoPago_Nombre, MetodoPago_Descripcion) VALUES (N'Deposito', N'Deposito en cuenta bancaria');
IF NOT EXISTS (SELECT 1 FROM dbo.MetodoPago WHERE MetodoPago_Nombre = N'Tarjeta')       INSERT INTO dbo.MetodoPago (MetodoPago_Nombre, MetodoPago_Descripcion) VALUES (N'Tarjeta', N'Tarjeta de debito o credito');
IF NOT EXISTS (SELECT 1 FROM dbo.MetodoPago WHERE MetodoPago_Nombre = N'Cheque')        INSERT INTO dbo.MetodoPago (MetodoPago_Nombre, MetodoPago_Descripcion) VALUES (N'Cheque', N'Pago con cheque');
GO

/* Ubicacion base */
IF NOT EXISTS (SELECT 1 FROM dbo.Pais WHERE Pais_Nombre = N'Republica Dominicana')
    INSERT INTO dbo.Pais (Pais_Nombre) VALUES (N'Republica Dominicana');
GO

/* Usuario administrador inicial.
   Correo: admin@newtalentloans.local   Contrasena: Demo1234!
   (hash bcrypt compatible con password_verify de PHP). CAMBIE LA CONTRASENA al publicar. */
IF NOT EXISTS (SELECT 1 FROM dbo.Acceso WHERE Acceso_Correo = N'admin@newtalentloans.local')
BEGIN
    DECLARE @PaisId INT, @ProvId INT, @CiudadId INT, @DirId INT, @RolId INT, @AccId INT, @UsrId INT;

    SELECT @PaisId = Pais_ID FROM dbo.Pais WHERE Pais_Nombre = N'Republica Dominicana';
    SELECT @RolId  = Rol_ID  FROM dbo.Rol  WHERE Rol_Nombre  = N'Administrador';

    IF NOT EXISTS (SELECT 1 FROM dbo.Provincia WHERE Provincia_PaisId = @PaisId AND Provincia_Nombre = N'Distrito Nacional')
        INSERT INTO dbo.Provincia (Provincia_PaisId, Provincia_Nombre) VALUES (@PaisId, N'Distrito Nacional');
    SELECT @ProvId = Provincia_ID FROM dbo.Provincia WHERE Provincia_PaisId = @PaisId AND Provincia_Nombre = N'Distrito Nacional';

    IF NOT EXISTS (SELECT 1 FROM dbo.Ciudad WHERE Ciudad_ProvinciaId = @ProvId AND Ciudad_Nombre = N'Santo Domingo')
        INSERT INTO dbo.Ciudad (Ciudad_ProvinciaId, Ciudad_Nombre) VALUES (@ProvId, N'Santo Domingo');
    SELECT @CiudadId = Ciudad_ID FROM dbo.Ciudad WHERE Ciudad_ProvinciaId = @ProvId AND Ciudad_Nombre = N'Santo Domingo';

    INSERT INTO dbo.Direccion (Direccion_CiudadId, Direccion_Descripcion) VALUES (@CiudadId, N'Oficina principal New Talent Loans');
    SET @DirId = SCOPE_IDENTITY();

    INSERT INTO dbo.Acceso (Acceso_RolId, Acceso_Correo, Acceso_ContrasenaHash, Acceso_Activo)
    VALUES (@RolId, N'admin@newtalentloans.local', N'$2y$10$G/bSXxAAxwv3xCWAb/bXfuH8.CWgZdrQo3OmjkW6nk9jVI4z6h9KO', 1);
    SET @AccId = SCOPE_IDENTITY();

    INSERT INTO dbo.Usuario (Usuario_DireccionId, Usuario_AccesoId, Usuario_Nombre, Usuario_Apellido, Usuario_Cedula, Usuario_Sueldo)
    VALUES (@DirId, @AccId, N'Administrador', N'Sistema', N'ADMIN-0001', 0);
    SET @UsrId = SCOPE_IDENTITY();

    INSERT INTO dbo.Telefono (Telefono_UsuarioId, Telefono_Numero) VALUES (@UsrId, N'8090000000');
    INSERT INTO dbo.Correo (Correo_UsuarioId, Correo_Direccion) VALUES (@UsrId, N'admin@newtalentloans.local');
END
GO

/* =====================================================================
   6. PROCEDIMIENTOS ALMACENADOS (reglas de negocio del documento)
   ===================================================================== */

/* 6.1 Tabla de amortizacion (sistema frances: cuota fija) - requerimiento 7.4 / 8.6
   Genera las cuotas de un prestamo. Primer vencimiento = 1 mes despues del desembolso. */
CREATE OR ALTER PROCEDURE dbo.sp_GenerarAmortizacion
    @PrestamoId     INT,
    @DevolverCuotas BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Monto DECIMAL(18,2), @Tasa DECIMAL(7,4), @Plazo INT, @Desembolso DATE;

    SELECT @Monto = Prestamo_Monto,
           @Tasa = Prestamo_Tasa,
           @Plazo = Prestamo_Plazo,
           @Desembolso = CAST(ISNULL(Prestamo_FechaDesembolso, SYSDATETIME()) AS DATE)
    FROM dbo.Prestamo
    WHERE Prestamo_ID = @PrestamoId;

    IF @Monto IS NULL THROW 50001, N'El prestamo indicado no existe.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Cuota WHERE Cuota_PrestamoId = @PrestamoId)
        THROW 50002, N'El prestamo ya tiene cuotas generadas.', 1;

    DECLARE @rf FLOAT = CAST(@Tasa AS FLOAT) / 1200.0;
    DECLARE @CuotaFija DECIMAL(18,2) =
        CASE WHEN @rf = 0 THEN CAST(ROUND(@Monto / @Plazo, 2) AS DECIMAL(18,2))
             ELSE CAST(ROUND(@Monto * @rf / (1 - POWER(1 + @rf, -@Plazo)), 2) AS DECIMAL(18,2)) END;

    DECLARE @n INT = 1,
            @SaldoCap DECIMAL(18,2) = @Monto,
            @Interes DECIMAL(18,2),
            @Capital DECIMAL(18,2),
            @MontoCuota DECIMAL(18,2);

    BEGIN TRANSACTION;

    WHILE @n <= @Plazo
    BEGIN
        SET @Interes = ROUND(@SaldoCap * @rf, 2);
        IF @n = @Plazo
            SET @Capital = @SaldoCap
        ELSE
            SET @Capital = @CuotaFija - @Interes;
        SET @MontoCuota = @Capital + @Interes;
        SET @SaldoCap = @SaldoCap - @Capital;

        INSERT INTO dbo.Cuota (Cuota_PrestamoId, Cuota_Numero, Cuota_FechaVencimiento, Cuota_Capital, Cuota_Interes,
                               Cuota_Monto, Cuota_Saldo, Cuota_Estado, Cuota_SaldoCapital, Cuota_MontoPagado)
        VALUES (@PrestamoId, @n, DATEADD(MONTH, @n, @Desembolso), @Capital, @Interes,
                @MontoCuota, @MontoCuota, N'Pendiente', @SaldoCap, 0);

        SET @n = @n + 1;
    END

    UPDATE dbo.Prestamo
    SET Prestamo_Saldo = (SELECT SUM(Cuota_Monto) FROM dbo.Cuota WHERE Cuota_PrestamoId = @PrestamoId)
    WHERE Prestamo_ID = @PrestamoId;

    INSERT INTO dbo.Auditoria (Auditoria_Tabla, Auditoria_RegistroId, Auditoria_Accion, Auditoria_Detalle)
    VALUES (N'Prestamo', @PrestamoId, N'AMORTIZACION', CONCAT(N'Se generaron ', @Plazo, N' cuotas.'));

    COMMIT TRANSACTION;

    IF @DevolverCuotas = 1
        SELECT Cuota_Numero, Cuota_FechaVencimiento, Cuota_Capital, Cuota_Interes, Cuota_Monto, Cuota_SaldoCapital, Cuota_Estado
        FROM dbo.Cuota
        WHERE Cuota_PrestamoId = @PrestamoId
        ORDER BY Cuota_Numero;
END
GO

/* 6.2 Control de mora - requerimiento 7.6 / 8.8
   Calcula el cargo por atraso: Monto de la cuota x TasaMora% mensual / 30 x dias de atraso
   (pasados los dias de gracia). Ejecutar diariamente (Agente de SQL Server) o por prestamo. */
CREATE OR ALTER PROCEDURE dbo.sp_ActualizarMora
    @PrestamoId  INT  = NULL,
    @FechaCorte  DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @FechaCorte = ISNULL(@FechaCorte, CAST(SYSDATETIME() AS DATE));

    IF OBJECT_ID(N'tempdb..#CalcMora') IS NOT NULL DROP TABLE #CalcMora;

    SELECT Y.CuotaId, Y.Dias, Y.Tasa, Y.Estado,
           CAST(ROUND(Y.MontoCuota * Y.Tasa / 100.0 / 30.0 * Y.Dias, 2) AS DECIMAL(18,2)) AS Monto
    INTO #CalcMora
    FROM (
        SELECT C.Cuota_ID AS CuotaId,
               C.Cuota_Monto AS MontoCuota,
               T.TipoPrestamo_TasaMora AS Tasa,
               T.TipoPrestamo_DiasGracia AS Gracia,
               CASE WHEN C.Cuota_Saldo > 0 THEN N'Activa' ELSE N'Cerrada' END AS Estado,
               DATEDIFF(DAY, C.Cuota_FechaVencimiento,
                        CASE WHEN C.Cuota_Saldo > 0 THEN @FechaCorte ELSE C.Cuota_FechaPago END) AS Dias
        FROM dbo.Cuota C
        INNER JOIN dbo.Prestamo P ON P.Prestamo_ID = C.Cuota_PrestamoId
        INNER JOIN dbo.TipoPrestamo T ON T.TipoPrestamo_ID = P.Prestamo_TipoPrestamoId
        WHERE (@PrestamoId IS NULL OR C.Cuota_PrestamoId = @PrestamoId)
    ) Y
    WHERE Y.Dias > Y.Gracia;

    UPDATE M
    SET M.Mora_DiasAtraso = K.Dias,
        M.Mora_TasaAplicada = K.Tasa,
        M.Mora_Monto = K.Monto,
        M.Mora_FechaCalculo = @FechaCorte,
        M.Mora_Estado = K.Estado
    FROM dbo.Mora M
    INNER JOIN #CalcMora K ON K.CuotaId = M.Mora_CuotaId
    WHERE M.Mora_Estado <> N'Condonada';

    INSERT INTO dbo.Mora (Mora_CuotaId, Mora_DiasAtraso, Mora_TasaAplicada, Mora_Monto, Mora_FechaCalculo, Mora_Estado)
    SELECT K.CuotaId, K.Dias, K.Tasa, K.Monto, @FechaCorte, K.Estado
    FROM #CalcMora K
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Mora M WHERE M.Mora_CuotaId = K.CuotaId);

    /* Las cuotas sin ningun pago y ya vencidas pasan a 'Vencida' */
    UPDATE dbo.Cuota
    SET Cuota_Estado = N'Vencida'
    WHERE Cuota_Saldo > 0
      AND Cuota_Estado = N'Pendiente'
      AND Cuota_FechaVencimiento < @FechaCorte
      AND (@PrestamoId IS NULL OR Cuota_PrestamoId = @PrestamoId);

    DROP TABLE #CalcMora;
END
GO

/* 6.3-bis Registro de pagos (WRAPPER DELGADO - compatible con trigger)
   ---------------------------------------------------------------
   IMPORTANTE: con el trigger TR_Pago_AfterInsert activo, este SP ya
   NO contiene la logica de negocio. Solo hace el INSERT en dbo.Pago;
   toda la cascada (validaciones, PagoCuota, Cuota, Prestamo,
   Facturacion, Auditoria, Mora) la ejecuta el trigger AFTER INSERT.

   NOTA SQL SERVER: NO se usa OUTPUT INSERTED sin INTO porque SQL
   Server lo prohibe cuando la tabla tiene triggers habilitados
   (error 334). Se usa SCOPE_IDENTITY() en su lugar. */
CREATE OR ALTER PROCEDURE dbo.sp_RegistrarPago
    @PrestamoId   INT,
    @MetodoPagoId INT,
    @Monto        DECIMAL(18,2),
    @UsuarioId    INT,
    @Referencia   NVARCHAR(60) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    INSERT INTO dbo.Pago
           (Pago_PrestamoId,
            Pago_MetodoPagoId,
            Pago_Monto,
            Pago_UsuarioId,
            Pago_Referencia)
    VALUES (@PrestamoId, @MetodoPagoId, @Monto, @UsuarioId, @Referencia);

    /* Devuelve el ID y la fecha del pago recien creado usando
       SCOPE_IDENTITY() (compatible con triggers). */
    SELECT  SCOPE_IDENTITY()            AS PagoId,
            P.Pago_Fecha                AS PagoFecha,
            P.Pago_Monto                AS Monto
    FROM    dbo.Pago P
    WHERE   P.Pago_ID = SCOPE_IDENTITY();
END
GO

/* 6.4 Evaluacion de solicitudes - requerimientos 7.3 / 8.4 / 8.5
   Registra la decision; si es Aprobada crea el prestamo (Activo), el garante y las cuotas. */
CREATE OR ALTER PROCEDURE dbo.sp_EvaluarSolicitud
    @SolicitudId    INT,
    @EvaluadorId    INT,
    @Decision       NVARCHAR(20),
    @TipoPrestamoId INT = NULL,
    @Comentario     NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Decision NOT IN (N'Aprobada', N'Rechazada') THROW 50020, N'La decision debe ser Aprobada o Rechazada.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE Usuario_ID = @EvaluadorId) THROW 50021, N'El evaluador indicado no existe.', 1;

    DECLARE @EstadoSol NVARCHAR(20), @Monto DECIMAL(18,2), @Plazo INT, @Sueldo DECIMAL(18,2), @TipoSol INT,
            @GNombre NVARCHAR(150), @GCedula NVARCHAR(30), @GTelefono NVARCHAR(30),
            @Tasa DECIMAL(7,4), @EstadoActivo INT, @PrestamoId INT = NULL;

    SELECT @EstadoSol = S.Solicitud_Estado, @Monto = S.Solicitud_Monto, @Plazo = S.Solicitud_Plazo,
           @Sueldo = U.Usuario_Sueldo, @TipoSol = S.Solicitud_TipoPrestamoId,
           @GNombre = S.Solicitud_GaranteNombre, @GCedula = S.Solicitud_GaranteCedula, @GTelefono = S.Solicitud_GaranteTelefono
    FROM dbo.Solicitud S
    INNER JOIN dbo.Usuario U ON U.Usuario_ID = S.Solicitud_UsuarioId
    WHERE S.Solicitud_ID = @SolicitudId;

    IF @EstadoSol IS NULL THROW 50022, N'La solicitud indicada no existe.', 1;
    IF @EstadoSol <> N'Pendiente' THROW 50023, N'Solo se pueden evaluar solicitudes pendientes.', 1;

    BEGIN TRANSACTION;

    INSERT INTO dbo.EvaluacionSolicitud (EvaluacionSolicitud_SolicitudId, EvaluacionSolicitud_UsuarioId, EvaluacionSolicitud_Decision, EvaluacionSolicitud_Comentario)
    VALUES (@SolicitudId, @EvaluadorId, @Decision, @Comentario);

    IF @Decision = N'Aprobada'
    BEGIN
        SET @TipoPrestamoId = ISNULL(@TipoPrestamoId, @TipoSol);
        IF @TipoPrestamoId IS NULL THROW 50024, N'Seleccione el tipo de prestamo para aprobar la solicitud.', 1;

        SELECT @Tasa = TipoPrestamo_TasaBase FROM dbo.TipoPrestamo WHERE TipoPrestamo_ID = @TipoPrestamoId;
        IF @Tasa IS NULL THROW 50025, N'El tipo de prestamo seleccionado no existe.', 1;

        /* Regla del sistema: si el monto supera el sueldo mensual se exige garante */
        IF @Monto > @Sueldo AND (LTRIM(RTRIM(ISNULL(@GNombre, N''))) = N'' OR LTRIM(RTRIM(ISNULL(@GCedula, N''))) = N'' OR LTRIM(RTRIM(ISNULL(@GTelefono, N''))) = N'')
            THROW 50026, N'La solicitud supera el sueldo mensual del cliente y requiere los datos de un garante.', 1;

        SELECT @EstadoActivo = EstadoPrestamo_ID FROM dbo.EstadoPrestamo WHERE EstadoPrestamo_Nombre = N'Activo';
        IF @EstadoActivo IS NULL THROW 50027, N'Falta el estado de prestamo Activo.', 1;

        INSERT INTO dbo.Prestamo (Prestamo_SolicitudId, Prestamo_TipoPrestamoId, Prestamo_EstadoPrestamoId, Prestamo_Monto, Prestamo_Tasa, Prestamo_Plazo, Prestamo_FechaDesembolso, Prestamo_Saldo)
        VALUES (@SolicitudId, @TipoPrestamoId, @EstadoActivo, @Monto, @Tasa, @Plazo, SYSDATETIME(), @Monto);
        SET @PrestamoId = SCOPE_IDENTITY();

        IF LTRIM(RTRIM(ISNULL(@GNombre, N''))) <> N''
            INSERT INTO dbo.Garante (Garante_PrestamoId, Garante_Nombre, Garante_Cedula, Garante_Telefono)
            VALUES (@PrestamoId, @GNombre, ISNULL(@GCedula, N''), @GTelefono);

        EXEC dbo.sp_GenerarAmortizacion @PrestamoId = @PrestamoId, @DevolverCuotas = 0;
    END

    UPDATE dbo.Solicitud SET Solicitud_Estado = @Decision WHERE Solicitud_ID = @SolicitudId;

    INSERT INTO dbo.Auditoria (Auditoria_UsuarioId, Auditoria_Tabla, Auditoria_RegistroId, Auditoria_Accion, Auditoria_Detalle)
    VALUES (@EvaluadorId, N'Solicitud', @SolicitudId, N'EVALUACION', CONCAT(N'Solicitud ', @Decision, N'.'));

    COMMIT TRANSACTION;

    SELECT @SolicitudId AS SolicitudId, @Decision AS Estado, @PrestamoId AS PrestamoId;
END
GO

/* =====================================================================
   6.5 TRIGGERS - Logica de negocio ejecutada por la base de datos
   ---------------------------------------------------------------------
   El backend PHP hace INSERT directo en dbo.Pago. Este trigger
   ejecuta TODA la cascada: validaciones, PagoCuota, Cuota, Prestamo,
   Facturacion, Auditoria y recalculo de mora. */

CREATE OR ALTER TRIGGER dbo.TR_Pago_AfterInsert
ON dbo.Pago
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /* Si no hubo filas insertadas, salir */
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    /* Variables del pago en curso */
    DECLARE @PagoId       INT,
            @PrestamoId   INT,
            @MetodoPagoId INT,
            @Monto        DECIMAL(18,2),
            @UsuarioId    INT,
            @Referencia   NVARCHAR(60);

    /* Variables de validacion y calculo */
    DECLARE @Saldo      DECIMAL(18,2),
            @Estado     NVARCHAR(50),
            @Codigo     NVARCHAR(20),
            @Restante   DECIMAL(18,2),
            @CuotaId    INT,
            @SaldoCuota DECIMAL(18,2),
            @Aplicar    DECIMAL(18,2),
            @NuevoSaldo DECIMAL(18,2),
            @Hoy        DATE = CAST(SYSDATETIME() AS DATE);

    /* Soporta INSERT multi-fila. Procesamos cada pago en orden. */
    DECLARE pagos_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT  Pago_ID,
                Pago_PrestamoId,
                Pago_MetodoPagoId,
                Pago_Monto,
                Pago_UsuarioId,
                Pago_Referencia
        FROM    inserted
        ORDER BY Pago_ID;

    OPEN pagos_cursor;
    FETCH NEXT FROM pagos_cursor
        INTO @PagoId, @PrestamoId, @MetodoPagoId, @Monto, @UsuarioId, @Referencia;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        /* ---------- 1. VALIDACIONES ---------- */

        SELECT  @Saldo  = P.Prestamo_Saldo,
                @Estado = E.EstadoPrestamo_Nombre,
                @Codigo = P.Prestamo_Codigo
        FROM    dbo.Prestamo P
        INNER JOIN dbo.EstadoPrestamo E
                ON E.EstadoPrestamo_ID = P.Prestamo_EstadoPrestamoId
        WHERE   P.Prestamo_ID = @PrestamoId;

        IF @Saldo IS NULL
            THROW 50011, N'El prestamo indicado no existe.', 1;

        IF @Monto IS NULL OR @Monto <= 0
            THROW 50010, N'El monto debe ser mayor que cero.', 1;

        IF @Estado NOT IN (N'Activo', N'Aprobado')
            THROW 50012, N'El prestamo no esta activo.', 1;

        IF @Monto > @Saldo
            THROW 50013, N'El monto supera el saldo pendiente del prestamo.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.MetodoPago WHERE MetodoPago_ID = @MetodoPagoId)
            THROW 50014, N'El metodo de pago no existe.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE Usuario_ID = @UsuarioId)
            THROW 50015, N'El usuario indicado no existe.', 1;

        /* ---------- 2. DISTRIBUIR EL PAGO A LAS CUOTAS ---------- */

        SET @Restante = @Monto;

        WHILE @Restante > 0
        BEGIN
            SET @CuotaId = NULL;

            SELECT TOP (1)
                   @CuotaId    = Cuota_ID,
                   @SaldoCuota = Cuota_Saldo
            FROM   dbo.Cuota
            WHERE  Cuota_PrestamoId = @PrestamoId
              AND  Cuota_Saldo > 0
            ORDER BY Cuota_FechaVencimiento, Cuota_ID;

            IF @CuotaId IS NULL BREAK;

            SET @Aplicar = CASE WHEN @Restante < @SaldoCuota
                                THEN @Restante ELSE @SaldoCuota END;

            UPDATE dbo.Cuota
            SET    Cuota_Saldo       = Cuota_Saldo - @Aplicar,
                   Cuota_MontoPagado = Cuota_MontoPagado + @Aplicar,
                   Cuota_Estado      = CASE
                                         WHEN Cuota_Saldo - @Aplicar <= 0
                                         THEN N'Pagada'
                                         ELSE N'Parcial'
                                       END,
                   Cuota_FechaPago   = CASE
                                         WHEN Cuota_Saldo - @Aplicar <= 0
                                         THEN @Hoy
                                         ELSE Cuota_FechaPago
                                       END
            WHERE  Cuota_ID = @CuotaId;

            INSERT INTO dbo.PagoCuota
                   (PagoCuota_PagoId, PagoCuota_CuotaId, PagoCuota_Monto)
            VALUES (@PagoId, @CuotaId, @Aplicar);

            SET @Restante = @Restante - @Aplicar;
        END

        /* ---------- 3. ACTUALIZAR SALDO Y ESTADO DEL PRESTAMO ---------- */

        IF EXISTS (SELECT 1 FROM dbo.Cuota WHERE Cuota_PrestamoId = @PrestamoId)
            SELECT @NuevoSaldo = SUM(Cuota_Saldo)
            FROM   dbo.Cuota
            WHERE  Cuota_PrestamoId = @PrestamoId;
        ELSE
            SET @NuevoSaldo = @Saldo - @Monto;

        IF @NuevoSaldo < 0 SET @NuevoSaldo = 0;

        UPDATE dbo.Prestamo
        SET    Prestamo_Saldo = @NuevoSaldo,
               Prestamo_EstadoPrestamoId =
                   CASE WHEN @NuevoSaldo = 0
                        THEN ISNULL(
                             (SELECT TOP (1) EstadoPrestamo_ID
                              FROM   dbo.EstadoPrestamo
                              WHERE  EstadoPrestamo_Nombre = N'Finalizado'),
                             Prestamo_EstadoPrestamoId)
                        ELSE Prestamo_EstadoPrestamoId
                   END
        WHERE  Prestamo_ID = @PrestamoId;

        /* ---------- 4. GENERAR COMPROBANTE (FACTURACION) ---------- */

        INSERT INTO dbo.Facturacion
               (Facturacion_MetodoPagoId,
                Facturacion_Monto,
                Facturacion_Descripcion,
                Facturacion_Estado,
                Facturacion_PagoId)
        VALUES (@MetodoPagoId,
                @Monto,
                CONCAT(N'Pago al prestamo ', @Codigo),
                N'Emitida',
                @PagoId);

        /* ---------- 5. AUDITORIA ---------- */

        INSERT INTO dbo.Auditoria
               (Auditoria_UsuarioId,
                Auditoria_Tabla,
                Auditoria_RegistroId,
                Auditoria_Accion,
                Auditoria_Detalle)
        VALUES (@UsuarioId,
                N'Pago',
                @PagoId,
                N'PAGO',
                CONCAT(N'Pago de ', @Monto,
                       N' al prestamo ', @Codigo,
                       N'. Saldo: ', @NuevoSaldo));

        /* ---------- 6. RECALCULAR MORA DEL PRESTAMO ---------- */

        EXEC dbo.sp_ActualizarMora @PrestamoId = @PrestamoId;

        FETCH NEXT FROM pagos_cursor
            INTO @PagoId, @PrestamoId, @MetodoPagoId, @Monto, @UsuarioId, @Referencia;
    END

    CLOSE pagos_cursor;
    DEALLOCATE pagos_cursor;
END
GO

PRINT N'TR_Pago_AfterInsert creado correctamente.';
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



/* =====================================================================
   7. VISTAS PARA CONSULTAS Y REPORTES - requerimientos 7.7 / 7.8
   ===================================================================== */

/* Prestamos con cliente, estado y conteo de cuotas */
CREATE OR ALTER VIEW dbo.vw_ResumenPrestamos
AS
SELECT P.Prestamo_ID,
       P.Prestamo_Codigo,
       U.Usuario_ID,
       U.Usuario_Cedula,
       U.Usuario_Nombre + N' ' + U.Usuario_Apellido AS Cliente,
       T.TipoPrestamo_Nombre,
       E.EstadoPrestamo_Nombre,
       P.Prestamo_Monto,
       P.Prestamo_Tasa,
       P.Prestamo_Plazo,
       P.Prestamo_FechaDesembolso,
       P.Prestamo_Saldo,
       ISNULL(Q.Total, 0)      AS CuotasTotal,
       ISNULL(Q.Pagadas, 0)    AS CuotasPagadas,
       ISNULL(Q.Pendientes, 0) AS CuotasPendientes,
       ISNULL(Q.Vencidas, 0)   AS CuotasVencidas,
       Q.ProximoVencimiento
FROM dbo.Prestamo P
INNER JOIN dbo.Solicitud S ON S.Solicitud_ID = P.Prestamo_SolicitudId
INNER JOIN dbo.Usuario U ON U.Usuario_ID = S.Solicitud_UsuarioId
INNER JOIN dbo.TipoPrestamo T ON T.TipoPrestamo_ID = P.Prestamo_TipoPrestamoId
INNER JOIN dbo.EstadoPrestamo E ON E.EstadoPrestamo_ID = P.Prestamo_EstadoPrestamoId
OUTER APPLY (
    SELECT COUNT(*) AS Total,
           SUM(CASE WHEN C.Cuota_Saldo <= 0 THEN 1 ELSE 0 END) AS Pagadas,
           SUM(CASE WHEN C.Cuota_Saldo > 0 THEN 1 ELSE 0 END) AS Pendientes,
           SUM(CASE WHEN C.Cuota_Saldo > 0 AND C.Cuota_FechaVencimiento < CAST(GETDATE() AS DATE) THEN 1 ELSE 0 END) AS Vencidas,
           MIN(CASE WHEN C.Cuota_Saldo > 0 THEN C.Cuota_FechaVencimiento END) AS ProximoVencimiento
    FROM dbo.Cuota C
    WHERE C.Cuota_PrestamoId = P.Prestamo_ID
) Q;
GO

/* Cuotas vencidas y sin pagar, con cliente, telefono y mora acumulada (para cobros) */
CREATE OR ALTER VIEW dbo.vw_CuotasVencidas
AS
SELECT C.Cuota_ID,
       P.Prestamo_ID,
       P.Prestamo_Codigo,
       U.Usuario_ID,
       U.Usuario_Cedula,
       U.Usuario_Nombre + N' ' + U.Usuario_Apellido AS Cliente,
       Tel.Telefono_Numero AS Telefono,
       C.Cuota_Numero,
       C.Cuota_FechaVencimiento,
       DATEDIFF(DAY, C.Cuota_FechaVencimiento, CAST(GETDATE() AS DATE)) AS DiasAtraso,
       C.Cuota_Monto,
       C.Cuota_Saldo AS SaldoVencido,
       ISNULL(M.Mora_Monto, 0) AS MoraAcumulada,
       C.Cuota_Estado
FROM dbo.Cuota C
INNER JOIN dbo.Prestamo P ON P.Prestamo_ID = C.Cuota_PrestamoId
INNER JOIN dbo.Solicitud S ON S.Solicitud_ID = P.Prestamo_SolicitudId
INNER JOIN dbo.Usuario U ON U.Usuario_ID = S.Solicitud_UsuarioId
LEFT JOIN dbo.Mora M ON M.Mora_CuotaId = C.Cuota_ID AND M.Mora_Estado = N'Activa'
OUTER APPLY (SELECT TOP (1) T.Telefono_Numero FROM dbo.Telefono T WHERE T.Telefono_UsuarioId = U.Usuario_ID ORDER BY T.Telefono_ID) Tel
WHERE C.Cuota_Saldo > 0
  AND C.Cuota_FechaVencimiento < CAST(GETDATE() AS DATE);
GO

/* Nivel de morosidad por cliente */
CREATE OR ALTER VIEW dbo.vw_MorosidadPorCliente
AS
SELECT Usuario_ID,
       Usuario_Cedula,
       Cliente,
       COUNT(*)            AS CuotasVencidas,
       SUM(SaldoVencido)   AS MontoVencido,
       SUM(MoraAcumulada)  AS MoraAcumulada,
       MAX(DiasAtraso)     AS MaxDiasAtraso
FROM dbo.vw_CuotasVencidas
GROUP BY Usuario_ID, Usuario_Cedula, Cliente;
GO

/* Historial de pagos con las cuotas a las que se aplico cada uno */
CREATE OR ALTER VIEW dbo.vw_HistorialPagos
AS
SELECT Pg.Pago_ID,
       Pg.Pago_Fecha,
       Pg.Pago_Monto,
       MP.MetodoPago_Nombre,
       P.Prestamo_ID,
       P.Prestamo_Codigo,
       U.Usuario_Nombre + N' ' + U.Usuario_Apellido AS Cliente,
       UR.Usuario_Nombre + N' ' + UR.Usuario_Apellido AS RegistradoPor,
       Ap.Cuotas AS CuotasAplicadas,
       F.Facturacion_Numero,
       Pg.Pago_Referencia
FROM dbo.Pago Pg
INNER JOIN dbo.MetodoPago MP ON MP.MetodoPago_ID = Pg.Pago_MetodoPagoId
INNER JOIN dbo.Prestamo P ON P.Prestamo_ID = Pg.Pago_PrestamoId
INNER JOIN dbo.Solicitud S ON S.Solicitud_ID = P.Prestamo_SolicitudId
INNER JOIN dbo.Usuario U ON U.Usuario_ID = S.Solicitud_UsuarioId
INNER JOIN dbo.Usuario UR ON UR.Usuario_ID = Pg.Pago_UsuarioId
LEFT JOIN dbo.Facturacion F ON F.Facturacion_PagoId = Pg.Pago_ID
OUTER APPLY (
    SELECT STRING_AGG(CAST(C.Cuota_Numero AS NVARCHAR(10)), N', ') AS Cuotas
    FROM dbo.PagoCuota PC
    INNER JOIN dbo.Cuota C ON C.Cuota_ID = PC.PagoCuota_CuotaId
    WHERE PC.PagoCuota_PagoId = Pg.Pago_ID
) Ap;
GO

/* Solicitudes con cliente, tipo, garante y prestamo generado */
CREATE OR ALTER VIEW dbo.vw_SolicitudesDetalle
AS
SELECT S.Solicitud_ID,
       S.Solicitud_Fecha,
       S.Solicitud_Estado,
       U.Usuario_ID,
       U.Usuario_Cedula,
       U.Usuario_Nombre + N' ' + U.Usuario_Apellido AS Cliente,
       U.Usuario_Sueldo,
       S.Solicitud_Monto,
       S.Solicitud_Plazo,
       S.Solicitud_Motivo,
       T.TipoPrestamo_Nombre,
       MP.MetodoPago_Nombre,
       S.Solicitud_GaranteNombre,
       P.Prestamo_ID,
       P.Prestamo_Codigo
FROM dbo.Solicitud S
INNER JOIN dbo.Usuario U ON U.Usuario_ID = S.Solicitud_UsuarioId
LEFT JOIN dbo.TipoPrestamo T ON T.TipoPrestamo_ID = S.Solicitud_TipoPrestamoId
LEFT JOIN dbo.MetodoPago MP ON MP.MetodoPago_ID = S.Solicitud_MetodoPagoId
LEFT JOIN dbo.Prestamo P ON P.Prestamo_SolicitudId = S.Solicitud_ID;
GO

PRINT N'Base de datos NewTalentLoans creada correctamente.';
GO

/* =====================================================================
   EJEMPLOS DE USO (descomentar para probar)
   ---------------------------------------------------------------------
   -- Evaluar una solicitud pendiente (aprueba, crea prestamo y cuotas):
   -- EXEC dbo.sp_EvaluarSolicitud @SolicitudId = 1, @EvaluadorId = 1, @Decision = N'Aprobada', @TipoPrestamoId = 1;

   -- Ver la tabla de amortizacion de un prestamo:
   -- SELECT * FROM dbo.Cuota WHERE Cuota_PrestamoId = 1 ORDER BY Cuota_Numero;

   -- Registrar un pago:
   -- EXEC dbo.sp_RegistrarPago @PrestamoId = 1, @MetodoPagoId = 1, @Monto = 2500, @UsuarioId = 1;

   -- Calcular mora de todos los prestamos (programar a diario):
   -- EXEC dbo.sp_ActualizarMora;

   -- Reportes:
   -- SELECT * FROM dbo.vw_ResumenPrestamos;
   -- SELECT * FROM dbo.vw_CuotasVencidas;
   -- SELECT * FROM dbo.vw_MorosidadPorCliente;
   ===================================================================== */
