/* 03 - CREACION COMPLETA DE LA BASE NewTalentLoans. Ejecutar primero. */
IF DB_ID(N'NewTalentLoans') IS NULL
    CREATE DATABASE NewTalentLoans;
GO
USE NewTalentLoans;
GO
CREATE TABLE Direccion (
Direccion_ID INT IDENTITY(1, 1) PRIMARY KEY,
Direccion_Provincia NVARCHAR(100) NOT NULL,
Direccion_Ciudad NVARCHAR(100) NOT NULL,
Direccion_Calle NVARCHAR(150) NOT NULL,
Direccion_Numero NVARCHAR(20) NULL,
Direccion_Sector NVARCHAR(100) NULL,
Direccion_Descripcion NVARCHAR(500) NULL
);
CREATE TABLE Empresa (
Empresa_ID INT IDENTITY(1,1) PRIMARY KEY,
Direccion_ID INT NOT NULL,
Empresa_Nombre NVARCHAR(180) NOT NULL,
Empresa_RNC NVARCHAR(30) NOT NULL UNIQUE,
Empresa_Correo NVARCHAR(254) NOT NULL,
Empresa_Telefono NVARCHAR(30) NULL,
Empresa_Estado NVARCHAR(30) NOT NULL DEFAULT N'Activa',
Empresa_FechaRegistro DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
FOREIGN KEY (Direccion_ID) REFERENCES Direccion(Direccion_ID)
);
CREATE TABLE PuntoPago (
PuntoPago_ID INT IDENTITY(1,1) PRIMARY KEY,
Empresa_ID INT NULL,
PuntoPago_Nombre NVARCHAR(120) NOT NULL,
PuntoPago_Direccion NVARCHAR(300) NOT NULL,
PuntoPago_Horario NVARCHAR(150) NULL,
PuntoPago_Telefono NVARCHAR(30) NULL,
PuntoPago_Activo BIT NOT NULL DEFAULT 1,
FOREIGN KEY (Empresa_ID) REFERENCES Empresa(Empresa_ID)
);
CREATE TABLE Rol (
Rol_ID INT IDENTITY(1, 1) PRIMARY KEY,
Rol_Nombre NVARCHAR(50) NOT NULL UNIQUE
);
CREATE TABLE Departamento (
Departamento_ID INT IDENTITY(1, 1) PRIMARY KEY,
Departamento_Nombre NVARCHAR(80) NOT NULL UNIQUE,
Departamento_Descripcion NVARCHAR(250) NULL,
Departamento_Activo BIT NOT NULL DEFAULT 1
);
-- El backend asigna Rol_ID: el autoregistro solo crea clientes; las cuentas de empleado requieren alta autorizada por un administrador.
CREATE TABLE Acceso (
Acceso_ID INT IDENTITY(1, 1) PRIMARY KEY,
Rol_ID INT NOT NULL,
Empresa_ID INT NULL,
Acceso_Correo NVARCHAR(254) NOT NULL UNIQUE,
Acceso_ContrasenaHash NVARCHAR(255) NOT NULL,
Acceso_Activo BIT NOT NULL DEFAULT 1,
Acceso_FechaCreacion DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
FOREIGN KEY (Rol_ID) REFERENCES Rol(Rol_ID)
,
FOREIGN KEY (Empresa_ID) REFERENCES Empresa(Empresa_ID)
);
CREATE TABLE Cliente (
Cliente_ID INT IDENTITY(1, 1) PRIMARY KEY,
Direccion_ID INT NOT NULL,
Acceso_ID INT NOT NULL UNIQUE,
Empresa_ID INT NULL,
Cliente_Nombre NVARCHAR(100) NOT NULL,
Cliente_Apellido NVARCHAR(100) NOT NULL,
Cliente_Cedula NVARCHAR(30) NOT NULL UNIQUE,
Cliente_Sueldo DECIMAL(18, 2) NOT NULL DEFAULT 0 CHECK (Cliente_Sueldo >= 0),
Cliente_FechaRegistro DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
FOREIGN KEY (Direccion_ID) REFERENCES Direccion(Direccion_ID),
FOREIGN KEY (Acceso_ID) REFERENCES Acceso(Acceso_ID)
,
FOREIGN KEY (Empresa_ID) REFERENCES Empresa(Empresa_ID)
);
CREATE TABLE Empleado (
Empleado_ID INT IDENTITY(1, 1) PRIMARY KEY,
Direccion_ID INT NOT NULL,
Acceso_ID INT NOT NULL UNIQUE,
Departamento_ID INT NOT NULL,
Empresa_ID INT NULL,
Empleado_Nombre NVARCHAR(100) NOT NULL,
Empleado_Apellido NVARCHAR(100) NOT NULL,
Empleado_Cedula NVARCHAR(30) NOT NULL UNIQUE,
Empleado_Cargo NVARCHAR(100) NOT NULL,
Empleado_Estado NVARCHAR(30) NOT NULL DEFAULT N'Pendiente',
Empleado_FechaIngreso DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
FOREIGN KEY (Direccion_ID) REFERENCES Direccion(Direccion_ID),
FOREIGN KEY (Departamento_ID) REFERENCES Departamento(Departamento_ID),
FOREIGN KEY (Acceso_ID) REFERENCES Acceso(Acceso_ID)
,
FOREIGN KEY (Empresa_ID) REFERENCES Empresa(Empresa_ID)
);
CREATE TABLE Telefono (
Telefono_ID INT IDENTITY(1, 1) PRIMARY KEY,
Cliente_ID INT NOT NULL,
Telefono_Numero NVARCHAR(30) NOT NULL,
FOREIGN KEY (Cliente_ID) REFERENCES Cliente(Cliente_ID)
);
CREATE TABLE Correo (
Correo_ID INT IDENTITY(1, 1) PRIMARY KEY,
Cliente_ID INT NOT NULL,
Correo_Direccion NVARCHAR(254) NOT NULL,
FOREIGN KEY (Cliente_ID) REFERENCES Cliente(Cliente_ID)
);
CREATE TABLE TipoPrestamo (
TipoPrestamo_ID INT IDENTITY(1, 1) PRIMARY KEY,
TipoPrestamo_Nombre NVARCHAR(80) NOT NULL UNIQUE,
TipoPrestamo_TasaBase DECIMAL(5, 2) NOT NULL CHECK (TipoPrestamo_TasaBase BETWEEN 0 AND 100),
TipoPrestamo_MontoMinimo DECIMAL(18, 2) NOT NULL DEFAULT 1,
TipoPrestamo_MontoMaximo DECIMAL(18, 2) NOT NULL DEFAULT 1000000,
TipoPrestamo_PlazoMinimo INT NOT NULL DEFAULT 1,
TipoPrestamo_PlazoMaximo INT NOT NULL DEFAULT 120
);
CREATE TABLE EstadoPrestamo (
EstadoPrestamo_ID INT IDENTITY(1, 1) PRIMARY KEY,
EstadoPrestamo_Nombre NVARCHAR(40) NOT NULL UNIQUE
);
CREATE TABLE MetodoPago (
MetodoPago_ID INT IDENTITY(1, 1) PRIMARY KEY,
MetodoPago_Nombre NVARCHAR(80) NOT NULL UNIQUE,
MetodoPago_Descripcion NVARCHAR(250) NULL
);
CREATE TABLE Moneda (
Moneda_ID INT IDENTITY(1, 1) PRIMARY KEY,
Moneda_Codigo CHAR(3) NOT NULL UNIQUE,
Moneda_Nombre NVARCHAR(80) NOT NULL,
Moneda_Simbolo NVARCHAR(8) NULL,
Moneda_Activa BIT NOT NULL DEFAULT 1
);
-- El backend valida y administra los estados disponibles para las solicitudes.
CREATE TABLE EstadoSolicitud (
EstadoSolicitud_ID INT IDENTITY(1, 1) PRIMARY KEY,
EstadoSolicitud_Nombre NVARCHAR(40) NOT NULL UNIQUE
);
CREATE TABLE Solicitud (
Solicitud_ID INT IDENTITY(1, 1) PRIMARY KEY,
Cliente_ID INT NOT NULL,
TipoPrestamo_ID INT NULL,
MetodoPago_ID INT NULL,
Moneda_ID INT NOT NULL,
EstadoSolicitud_ID INT NOT NULL,
Solicitud_Fecha DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
Solicitud_Monto DECIMAL(18, 2) NOT NULL CHECK (Solicitud_Monto > 0),
Solicitud_Plazo INT NOT NULL CHECK (Solicitud_Plazo BETWEEN 1 AND 120),
Solicitud_Motivo NVARCHAR(500) NULL,
FOREIGN KEY (Cliente_ID) REFERENCES Cliente(Cliente_ID),
FOREIGN KEY (TipoPrestamo_ID) REFERENCES TipoPrestamo(TipoPrestamo_ID),
FOREIGN KEY (MetodoPago_ID) REFERENCES MetodoPago(MetodoPago_ID),
FOREIGN KEY (Moneda_ID) REFERENCES Moneda(Moneda_ID),
FOREIGN KEY (EstadoSolicitud_ID) REFERENCES EstadoSolicitud(EstadoSolicitud_ID)
);
CREATE TABLE Prestamo (
Prestamo_ID INT IDENTITY(1, 1) PRIMARY KEY,
Solicitud_ID INT NOT NULL UNIQUE,
TipoPrestamo_ID INT NOT NULL,
EstadoPrestamo_ID INT NOT NULL,
Prestamo_Monto DECIMAL(18, 2) NOT NULL CHECK (Prestamo_Monto > 0),
Prestamo_Tasa DECIMAL(5, 2) NOT NULL CHECK (Prestamo_Tasa BETWEEN 0 AND 100),
Prestamo_Plazo INT NOT NULL CHECK (Prestamo_Plazo BETWEEN 1 AND 120),
Prestamo_FechaDesembolso DATETIME2 NULL,
Prestamo_Saldo DECIMAL(18, 2) NOT NULL CHECK (Prestamo_Saldo >= 0),
FOREIGN KEY (Solicitud_ID) REFERENCES Solicitud(Solicitud_ID),
FOREIGN KEY (TipoPrestamo_ID) REFERENCES TipoPrestamo(TipoPrestamo_ID),
FOREIGN KEY (EstadoPrestamo_ID) REFERENCES EstadoPrestamo(EstadoPrestamo_ID)
);
CREATE TABLE TipoGarantia (
TipoGarantia_ID INT IDENTITY(1, 1) PRIMARY KEY,
TipoGarantia_Nombre NVARCHAR(80) NOT NULL UNIQUE,
TipoGarantia_Descripcion NVARCHAR(250) NULL,
TipoGarantia_Activa BIT NOT NULL DEFAULT 1
);
CREATE TABLE Garante (
Garante_ID INT IDENTITY(1, 1) PRIMARY KEY,
Prestamo_ID INT NOT NULL,
Acceso_ID INT NULL,
Garante_Nombre NVARCHAR(150) NOT NULL,
Garante_Cedula NVARCHAR(30) NOT NULL,
Garante_Telefono NVARCHAR(30) NOT NULL,
FOREIGN KEY (Prestamo_ID) REFERENCES Prestamo(Prestamo_ID),
FOREIGN KEY (Acceso_ID) REFERENCES Acceso(Acceso_ID)
);
CREATE TABLE Garantia (
Garantia_ID INT IDENTITY(1, 1) PRIMARY KEY,
Prestamo_ID INT NOT NULL,
TipoGarantia_ID INT NOT NULL,
Garantia_Descripcion NVARCHAR(500) NOT NULL,
Garantia_ValorEstimado DECIMAL(18, 2) NOT NULL CHECK (Garantia_ValorEstimado >= 0),
Garantia_Referencia NVARCHAR(100) NULL,
Garantia_Estado NVARCHAR(30) NOT NULL DEFAULT 'Pendiente',
Garantia_FechaRegistro DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
FOREIGN KEY (Prestamo_ID) REFERENCES Prestamo(Prestamo_ID),
FOREIGN KEY (TipoGarantia_ID) REFERENCES TipoGarantia(TipoGarantia_ID)
);
CREATE TABLE Cuota (
Cuota_ID INT IDENTITY(1, 1) PRIMARY KEY,
Prestamo_ID INT NOT NULL,
Cuota_Numero INT NOT NULL,
Cuota_FechaVencimiento DATE NOT NULL,
Cuota_Capital DECIMAL(18, 2) NOT NULL CHECK (Cuota_Capital >= 0),
Cuota_Interes DECIMAL(18, 2) NOT NULL CHECK (Cuota_Interes >= 0),
Cuota_Monto DECIMAL(18, 2) NOT NULL CHECK (Cuota_Monto > 0),
Cuota_Saldo DECIMAL(18, 2) NOT NULL CHECK (Cuota_Saldo >= 0),
Cuota_Estado NVARCHAR(30) NOT NULL DEFAULT 'Pendiente',
CONSTRAINT UQ_Cuota_Prestamo_Numero UNIQUE (Prestamo_ID, Cuota_Numero),
FOREIGN KEY (Prestamo_ID) REFERENCES Prestamo(Prestamo_ID)
);
CREATE TABLE Pago (
Pago_ID INT IDENTITY(1, 1) PRIMARY KEY,
Prestamo_ID INT NOT NULL,
MetodoPago_ID INT NOT NULL,
Cliente_ID INT NOT NULL,
Cuota_ID INT NULL,
Pago_Fecha DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
Pago_Monto DECIMAL(18, 2) NOT NULL CHECK (Pago_Monto > 0),
Pago_Estado NVARCHAR(20) NOT NULL DEFAULT N'Aplicado',
Pago_ReversadoFecha DATETIME2 NULL,
Pago_ReversionMotivo NVARCHAR(500) NULL,
Pago_Referencia NVARCHAR(100) NULL,
FOREIGN KEY (Prestamo_ID) REFERENCES Prestamo(Prestamo_ID),
FOREIGN KEY (MetodoPago_ID) REFERENCES MetodoPago(MetodoPago_ID),
FOREIGN KEY (Cliente_ID) REFERENCES Cliente(Cliente_ID),
FOREIGN KEY (Cuota_ID) REFERENCES Cuota(Cuota_ID)
);
CREATE TABLE Desembolso (
Desembolso_ID INT IDENTITY(1, 1) PRIMARY KEY,
Prestamo_ID INT NOT NULL,
MetodoPago_ID INT NOT NULL,
Empleado_ID INT NULL,
Desembolso_Fecha DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
Desembolso_Monto DECIMAL(18, 2) NOT NULL CHECK (Desembolso_Monto > 0),
Desembolso_Referencia NVARCHAR(100) NULL,
Desembolso_Estado NVARCHAR(30) NOT NULL DEFAULT 'Procesado',
Desembolso_Observacion NVARCHAR(500) NULL,
FOREIGN KEY (Prestamo_ID) REFERENCES Prestamo(Prestamo_ID),
FOREIGN KEY (MetodoPago_ID) REFERENCES MetodoPago(MetodoPago_ID),
FOREIGN KEY (Empleado_ID) REFERENCES Empleado(Empleado_ID)
);
CREATE TABLE HistorialSolicitud (
HistorialSolicitud_ID INT IDENTITY(1, 1) PRIMARY KEY,
Solicitud_ID INT NOT NULL,
EstadoSolicitud_ID INT NOT NULL,
Empleado_ID INT NULL,
HistorialSolicitud_Fecha DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
HistorialSolicitud_Comentario NVARCHAR(500) NULL,
FOREIGN KEY (Solicitud_ID) REFERENCES Solicitud(Solicitud_ID),
FOREIGN KEY (EstadoSolicitud_ID) REFERENCES EstadoSolicitud(EstadoSolicitud_ID),
FOREIGN KEY (Empleado_ID) REFERENCES Empleado(Empleado_ID)
);
CREATE TABLE Auditoria (
Auditoria_ID BIGINT IDENTITY(1, 1) PRIMARY KEY,
Acceso_ID INT NULL,
Auditoria_Entidad NVARCHAR(128) NOT NULL,
Auditoria_RegistroId NVARCHAR(100) NOT NULL,
Auditoria_Accion NVARCHAR(30) NOT NULL
CHECK (Auditoria_Accion IN ('INSERT', 'UPDATE', 'DELETE', 'LOGIN', 'LOGOUT')),
Auditoria_Fecha DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
Auditoria_Detalle NVARCHAR(MAX) NULL,
Auditoria_DireccionIP NVARCHAR(45) NULL,
FOREIGN KEY (Acceso_ID) REFERENCES Acceso(Acceso_ID)
);
CREATE TABLE MensajeContacto (
Mensaje_ID INT IDENTITY(1,1) PRIMARY KEY,
Mensaje_Nombre NVARCHAR(120) NOT NULL,
Mensaje_Correo NVARCHAR(254) NOT NULL,
Mensaje_Texto NVARCHAR(1000) NOT NULL,
Mensaje_Estado NVARCHAR(30) NOT NULL DEFAULT N'Pendiente',
Mensaje_Fecha DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);
CREATE TABLE DocumentoSolicitud (
DocumentoSolicitud_ID INT IDENTITY(1, 1) PRIMARY KEY,
Solicitud_ID INT NOT NULL,
DocumentoSolicitud_Tipo NVARCHAR(80) NOT NULL,
DocumentoSolicitud_NombreArchivo NVARCHAR(255) NOT NULL,
DocumentoSolicitud_Ubicacion NVARCHAR(1000) NOT NULL,
DocumentoSolicitud_FechaCarga DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
FOREIGN KEY (Solicitud_ID) REFERENCES Solicitud(Solicitud_ID)
);
CREATE INDEX IX_Solicitud_Cliente ON Solicitud(Cliente_ID);
CREATE INDEX IX_Garantia_Prestamo ON Garantia(Prestamo_ID);
CREATE INDEX IX_Desembolso_Prestamo ON Desembolso(Prestamo_ID);
CREATE INDEX IX_Auditoria_Entidad_Registro ON Auditoria(Auditoria_Entidad, Auditoria_RegistroId);
CREATE INDEX IX_Auditoria_Fecha ON Auditoria(Auditoria_Fecha);
CREATE INDEX IX_Solicitud_Estado ON Solicitud(EstadoSolicitud_ID);
CREATE INDEX IX_Prestamo_Estado ON Prestamo(EstadoPrestamo_ID);
CREATE INDEX IX_Cuota_Prestamo ON Cuota(Prestamo_ID);
CREATE INDEX IX_Cuota_FechaVencimiento ON Cuota(Cuota_FechaVencimiento);
CREATE INDEX IX_Pago_Prestamo ON Pago(Prestamo_ID);
CREATE INDEX IX_Pago_Cliente ON Pago(Cliente_ID);
CREATE INDEX IX_HistorialSolicitud_Solicitud ON HistorialSolicitud(Solicitud_ID);
CREATE INDEX IX_DocumentoSolicitud_Solicitud ON DocumentoSolicitud(Solicitud_ID);
GO
CREATE TABLE PagoCuota(
PagoCuota_ID INT IDENTITY PRIMARY KEY,
Pago_ID INT NOT NULL REFERENCES Pago(Pago_ID),
Cuota_ID INT NOT NULL REFERENCES Cuota(Cuota_ID),
PagoCuota_Monto DECIMAL(18, 2) NOT NULL CHECK(PagoCuota_Monto>0),
CONSTRAINT UQ_PagoCuota UNIQUE(Pago_ID, Cuota_ID)
);
CREATE TABLE ReversionPago(
ReversionPago_ID INT IDENTITY PRIMARY KEY,
Pago_ID INT NOT NULL UNIQUE REFERENCES Pago(Pago_ID),
Acceso_ID INT NULL REFERENCES Acceso(Acceso_ID),
ReversionPago_Monto DECIMAL(18, 2) NOT NULL CHECK(ReversionPago_Monto>0),
ReversionPago_Motivo NVARCHAR(500) NOT NULL,
ReversionPago_ReferenciaExterna NVARCHAR(100) NULL,
ReversionPago_Estado NVARCHAR(20) NOT NULL DEFAULT(N'Solicitada') CHECK(ReversionPago_Estado IN(N'Solicitada', N'Aplicada', N'Fallida')),
ReversionPago_Fecha DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);
CREATE TABLE ReversionDesembolso(
ReversionDesembolso_ID INT IDENTITY PRIMARY KEY,
Desembolso_ID INT NOT NULL UNIQUE REFERENCES Desembolso(Desembolso_ID),
Acceso_ID INT NULL REFERENCES Acceso(Acceso_ID),
ReversionDesembolso_Monto DECIMAL(18, 2) NOT NULL CHECK(ReversionDesembolso_Monto>0),
ReversionDesembolso_Motivo NVARCHAR(500) NOT NULL,
ReversionDesembolso_ReferenciaExterna NVARCHAR(100) NULL,
ReversionDesembolso_Estado NVARCHAR(20) NOT NULL DEFAULT(N'Aplicada') CHECK(ReversionDesembolso_Estado IN(N'Aplicada', N'Fallida')),
ReversionDesembolso_Fecha DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);
INSERT EstadoPrestamo(EstadoPrestamo_Nombre)
    VALUES(N'Cancelado');
GO
/* Catálogos base para probar los flujos del sistema. */
INSERT Rol(Rol_Nombre) VALUES(N'Cliente');
INSERT Rol(Rol_Nombre) VALUES(N'RRHH');
INSERT Rol(Rol_Nombre) VALUES(N'Contable');
INSERT Rol(Rol_Nombre) VALUES(N'Solicitudes');
INSERT Rol(Rol_Nombre) VALUES(N'Gerente');
INSERT Rol(Rol_Nombre) VALUES(N'Pendiente');
INSERT Rol(Rol_Nombre) VALUES(N'Dueño');
INSERT Departamento(Departamento_Nombre, Departamento_Descripcion) VALUES(N'Recursos Humanos', N'Gestión de empleados y expedientes');
INSERT Departamento(Departamento_Nombre, Departamento_Descripcion) VALUES(N'Contabilidad', N'Pagos, cuotas, recibos e impuestos');
INSERT Departamento(Departamento_Nombre, Departamento_Descripcion) VALUES(N'Solicitudes', N'Revisión y seguimiento de solicitudes');
INSERT Departamento(Departamento_Nombre, Departamento_Descripcion) VALUES(N'Gerencia', N'Control, revisión y métricas generales');
INSERT PuntoPago(PuntoPago_Nombre, PuntoPago_Direccion, PuntoPago_Horario, PuntoPago_Telefono)
VALUES(N'Oficina principal', N'Consultar dirección con servicio al cliente', N'Lunes a viernes, 8:00 a.m. a 5:00 p.m.', N'809-000-0000');
INSERT EstadoSolicitud(EstadoSolicitud_Nombre) VALUES(N'Pendiente');
INSERT EstadoSolicitud(EstadoSolicitud_Nombre) VALUES(N'Aprobada');
INSERT EstadoSolicitud(EstadoSolicitud_Nombre) VALUES(N'Rechazada');
INSERT EstadoPrestamo(EstadoPrestamo_Nombre) VALUES(N'Aprobado');
INSERT EstadoPrestamo(EstadoPrestamo_Nombre) VALUES(N'Activo');
INSERT EstadoPrestamo(EstadoPrestamo_Nombre) VALUES(N'Pagado');
INSERT EstadoPrestamo(EstadoPrestamo_Nombre) VALUES(N'Atrasado');
INSERT MetodoPago(MetodoPago_Nombre) VALUES(N'Efectivo');
INSERT MetodoPago(MetodoPago_Nombre) VALUES(N'Transferencia');
INSERT MetodoPago(MetodoPago_Nombre) VALUES(N'Tarjeta');
INSERT TipoPrestamo(TipoPrestamo_Nombre, TipoPrestamo_TasaBase) VALUES(N'Personal', 10);
INSERT TipoPrestamo(TipoPrestamo_Nombre, TipoPrestamo_TasaBase) VALUES(N'Educativo', 8);
INSERT TipoPrestamo(TipoPrestamo_Nombre, TipoPrestamo_TasaBase) VALUES(N'Emergencia', 12);
INSERT Moneda(Moneda_Codigo, Moneda_Nombre, Moneda_Simbolo) VALUES('DOP', N'Peso dominicano', N'RD$');
GO
