/* Vistas de lectura de NewTalentLoans. Ejecutar después de 03_creacion_base_datos.sql. */
USE NewTalentLoans;
GO

CREATE OR ALTER VIEW vw_ClienteEstadoFinanciero AS
SELECT c.Cliente_ID, c.Cliente_Nombre, c.Cliente_Apellido, c.Cliente_Sueldo,
       COALESCE(SUM(DISTINCT p.Prestamo_Saldo), 0) AS DeudaPendiente,
       COALESCE(SUM(CASE WHEN q.Cuota_Estado IN (N'Atrasada', N'Mora') THEN q.Cuota_Saldo ELSE 0 END), 0) AS Mora,
       COALESCE(SUM(q.Cuota_Interes), 0) AS Interes
FROM Cliente c
LEFT JOIN Solicitud s ON s.Cliente_ID=c.Cliente_ID
LEFT JOIN Prestamo p ON p.Solicitud_ID=s.Solicitud_ID
LEFT JOIN Cuota q ON q.Prestamo_ID=p.Prestamo_ID
GROUP BY c.Cliente_ID, c.Cliente_Nombre, c.Cliente_Apellido, c.Cliente_Sueldo;
GO


CREATE OR ALTER VIEW vw_AccesosUsuario AS
SELECT a.Acceso_ID, a.Acceso_Correo, a.Acceso_ContrasenaHash, a.Acceso_Activo, a.Acceso_FechaCreacion,
       a.Empresa_ID, r.Rol_Nombre,
       c.Cliente_ID, c.Cliente_Nombre, c.Cliente_Apellido,
       e.Empleado_ID, e.Empleado_Nombre, e.Empleado_Apellido, e.Empleado_Cedula, e.Empleado_Cargo,
       e.Empleado_Estado, e.Departamento_ID
FROM Acceso a
JOIN Rol r ON r.Rol_ID=a.Rol_ID
LEFT JOIN Cliente c ON c.Acceso_ID=a.Acceso_ID
LEFT JOIN Empleado e ON e.Acceso_ID=a.Acceso_ID;
GO

CREATE OR ALTER VIEW vw_ClientesDetalle AS
SELECT c.Cliente_ID, c.Acceso_ID, c.Cliente_Nombre, c.Cliente_Apellido, c.Cliente_Cedula,
       c.Cliente_Sueldo, c.Cliente_FechaRegistro, c.Empresa_ID,
       a.Acceso_Correo, a.Acceso_Activo,
       d.Direccion_Provincia, d.Direccion_Ciudad, d.Direccion_Calle,
       d.Direccion_Numero, d.Direccion_Sector, d.Direccion_Descripcion
FROM Cliente c
JOIN Acceso a ON a.Acceso_ID=c.Acceso_ID
JOIN Direccion d ON d.Direccion_ID=c.Direccion_ID;
GO

CREATE OR ALTER VIEW vw_EmpresasResumen AS
SELECT e.Empresa_ID, e.Empresa_Nombre, e.Empresa_RNC, e.Empresa_Correo,
       e.Empresa_Telefono, e.Empresa_Estado, e.Empresa_FechaRegistro,
       d.Direccion_Provincia, d.Direccion_Ciudad, d.Direccion_Calle,
       d.Direccion_Numero, d.Direccion_Sector,
       COUNT(DISTINCT c.Cliente_ID) AS clientes,
       COALESCE((SELECT SUM(c2.Cliente_Sueldo) FROM Cliente c2 WHERE c2.Empresa_ID=e.Empresa_ID), 0) AS sueldo_total,
       COUNT(DISTINCT p.Prestamo_ID) AS prestamos,
       COALESCE(SUM(DISTINCT p.Prestamo_Saldo), 0) AS deuda_total
FROM Empresa e
JOIN Direccion d ON d.Direccion_ID=e.Direccion_ID
LEFT JOIN Cliente c ON c.Empresa_ID=e.Empresa_ID
LEFT JOIN Solicitud s ON s.Cliente_ID=c.Cliente_ID
LEFT JOIN Prestamo p ON p.Solicitud_ID=s.Solicitud_ID
GROUP BY e.Empresa_ID, e.Empresa_Nombre, e.Empresa_RNC, e.Empresa_Correo,
         e.Empresa_Telefono, e.Empresa_Estado, e.Empresa_FechaRegistro,
         d.Direccion_Provincia, d.Direccion_Ciudad, d.Direccion_Calle,
         d.Direccion_Numero, d.Direccion_Sector;
GO

CREATE OR ALTER VIEW vw_EmpresasPublicas AS
SELECT Empresa_ID, Empresa_Nombre, Empresa_RNC
FROM Empresa
WHERE Empresa_Estado=N'Activa';
GO

CREATE OR ALTER VIEW vw_PuntosPagoActivos AS
SELECT PuntoPago_ID, Empresa_ID, PuntoPago_Nombre, PuntoPago_Direccion,
       PuntoPago_Horario, PuntoPago_Telefono
FROM PuntoPago
WHERE PuntoPago_Activo=1;
GO

CREATE OR ALTER VIEW vw_CatalogoTipoPrestamo AS
SELECT TipoPrestamo_ID, TipoPrestamo_Nombre, TipoPrestamo_TasaBase,
       TipoPrestamo_MontoMinimo, TipoPrestamo_MontoMaximo,
       TipoPrestamo_PlazoMinimo, TipoPrestamo_PlazoMaximo
FROM TipoPrestamo;
GO
CREATE OR ALTER VIEW vw_CatalogoEstadoPrestamo AS
SELECT EstadoPrestamo_ID, EstadoPrestamo_Nombre FROM EstadoPrestamo;
GO
CREATE OR ALTER VIEW vw_CatalogoMetodoPago AS
SELECT MetodoPago_ID, MetodoPago_Nombre, MetodoPago_Descripcion FROM MetodoPago;
GO
CREATE OR ALTER VIEW vw_CatalogoMoneda AS
SELECT Moneda_ID, Moneda_Codigo, Moneda_Nombre, Moneda_Simbolo, Moneda_Activa FROM Moneda;
GO
CREATE OR ALTER VIEW vw_CatalogoTipoGarantia AS
SELECT TipoGarantia_ID, TipoGarantia_Nombre, TipoGarantia_Descripcion, TipoGarantia_Activa FROM TipoGarantia;
GO
CREATE OR ALTER VIEW vw_CatalogoEstadoSolicitud AS
SELECT EstadoSolicitud_ID, EstadoSolicitud_Nombre FROM EstadoSolicitud;
GO
CREATE OR ALTER VIEW vw_EmpleadosPendientes AS
SELECT e.Empleado_ID, e.Empleado_Nombre, e.Empleado_Apellido,
       e.Empleado_Cedula, e.Empleado_Cargo, e.Empleado_Estado,
       e.Empleado_FechaIngreso, e.Empresa_ID, a.Acceso_ID,
       a.Acceso_Correo, d.Departamento_Nombre
FROM Empleado e
JOIN Acceso a ON a.Acceso_ID=e.Acceso_ID
JOIN Rol r ON r.Rol_ID=a.Rol_ID
JOIN Departamento d ON d.Departamento_ID=e.Departamento_ID
WHERE r.Rol_Nombre=N'Pendiente';
GO

CREATE OR ALTER VIEW vw_SolicitudesDetalle AS
SELECT s.Solicitud_ID, s.Cliente_ID, c.Cliente_Nombre, c.Cliente_Apellido,
       c.Cliente_Sueldo, c.Empresa_ID, s.TipoPrestamo_ID, tp.TipoPrestamo_Nombre,
       s.MetodoPago_ID, mp.MetodoPago_Nombre, s.Moneda_ID, m.Moneda_Codigo,
       s.EstadoSolicitud_ID, es.EstadoSolicitud_Nombre AS Solicitud_Estado,
       s.Solicitud_Fecha, s.Solicitud_Monto, s.Solicitud_Plazo,
       s.Solicitud_Motivo
FROM Solicitud s
JOIN Cliente c ON c.Cliente_ID=s.Cliente_ID
LEFT JOIN TipoPrestamo tp ON tp.TipoPrestamo_ID=s.TipoPrestamo_ID
LEFT JOIN MetodoPago mp ON mp.MetodoPago_ID=s.MetodoPago_ID
JOIN Moneda m ON m.Moneda_ID=s.Moneda_ID
JOIN EstadoSolicitud es ON es.EstadoSolicitud_ID=s.EstadoSolicitud_ID;
GO

CREATE OR ALTER VIEW vw_PrestamosResumen AS
SELECT p.Prestamo_ID, p.Solicitud_ID, s.Cliente_ID, c.Cliente_Nombre,
       c.Cliente_Apellido, c.Empresa_ID, p.TipoPrestamo_ID,
       tp.TipoPrestamo_Nombre, p.EstadoPrestamo_ID,
       ep.EstadoPrestamo_Nombre, p.Prestamo_Monto, p.Prestamo_Tasa,
       p.Prestamo_Plazo, p.Prestamo_FechaDesembolso, p.Prestamo_Saldo,
       (SELECT COUNT(*) FROM Cuota q WHERE q.Prestamo_ID=p.Prestamo_ID) AS TotalCuotas,
       (SELECT COUNT(*) FROM Cuota q WHERE q.Prestamo_ID=p.Prestamo_ID AND q.Cuota_Saldo=0) AS CuotasPagadas,
       (SELECT COALESCE(SUM(q.Cuota_Saldo),0) FROM Cuota q WHERE q.Prestamo_ID=p.Prestamo_ID) AS SaldoCuotas,
       (SELECT COALESCE(SUM(pg.Pago_Monto),0) FROM Pago pg WHERE pg.Prestamo_ID=p.Prestamo_ID AND pg.Pago_Estado=N'Aplicado') AS TotalPagado,
       (SELECT COALESCE(SUM(q.Cuota_Saldo),0) FROM Cuota q WHERE q.Prestamo_ID=p.Prestamo_ID AND q.Cuota_Estado IN(N'Atrasada',N'Mora')) AS mora
FROM Prestamo p
JOIN Solicitud s ON s.Solicitud_ID=p.Solicitud_ID
JOIN Cliente c ON c.Cliente_ID=s.Cliente_ID
JOIN TipoPrestamo tp ON tp.TipoPrestamo_ID=p.TipoPrestamo_ID
JOIN EstadoPrestamo ep ON ep.EstadoPrestamo_ID=p.EstadoPrestamo_ID;
GO

CREATE OR ALTER VIEW vw_CuotasDetalle AS
SELECT q.Cuota_ID, q.Prestamo_ID, p.Solicitud_ID, s.Cliente_ID,
       c.Cliente_Nombre, c.Cliente_Apellido, c.Empresa_ID,
       q.Cuota_Numero, q.Cuota_FechaVencimiento, q.Cuota_Capital,
       q.Cuota_Interes, q.Cuota_Monto, q.Cuota_Saldo, q.Cuota_Estado
FROM Cuota q
JOIN Prestamo p ON p.Prestamo_ID=q.Prestamo_ID
JOIN Solicitud s ON s.Solicitud_ID=p.Solicitud_ID
JOIN Cliente c ON c.Cliente_ID=s.Cliente_ID;
GO

CREATE OR ALTER VIEW vw_PagosDetalle AS
SELECT pg.Pago_ID, pg.Prestamo_ID, pg.Cliente_ID, c.Cliente_Nombre,
       c.Cliente_Apellido, c.Empresa_ID, pg.Cuota_ID, pg.Pago_Fecha,
       pg.Pago_Monto, pg.Pago_Estado, pg.Pago_Referencia,
       mp.MetodoPago_Nombre
FROM Pago pg
JOIN Cliente c ON c.Cliente_ID=pg.Cliente_ID
JOIN MetodoPago mp ON mp.MetodoPago_ID=pg.MetodoPago_ID;
GO

CREATE OR ALTER VIEW vw_GarantesDetalle AS
SELECT g.Garante_ID, g.Prestamo_ID, g.Acceso_ID, g.Garante_Nombre,
       g.Garante_Cedula, g.Garante_Telefono
FROM Garante g;
GO
CREATE OR ALTER VIEW vw_GarantiasDetalle AS
SELECT g.Garantia_ID, g.Prestamo_ID, g.TipoGarantia_ID,
       tg.TipoGarantia_Nombre, tg.TipoGarantia_Descripcion,
       g.Garantia_Descripcion, g.Garantia_ValorEstimado,
       g.Garantia_Referencia, g.Garantia_Estado, g.Garantia_FechaRegistro
FROM Garantia g
JOIN TipoGarantia tg ON tg.TipoGarantia_ID=g.TipoGarantia_ID;
GO
CREATE OR ALTER VIEW vw_DesembolsosDetalle AS
SELECT d.Desembolso_ID, d.Prestamo_ID, d.MetodoPago_ID,
       mp.MetodoPago_Nombre, d.Empleado_ID, d.Desembolso_Fecha,
       d.Desembolso_Monto, d.Desembolso_Referencia,
       d.Desembolso_Estado, d.Desembolso_Observacion
FROM Desembolso d
JOIN MetodoPago mp ON mp.MetodoPago_ID=d.MetodoPago_ID;
GO
CREATE OR ALTER VIEW vw_HistorialSolicitudesDetalle AS
SELECT h.HistorialSolicitud_ID, h.Solicitud_ID, h.EstadoSolicitud_ID,
       es.EstadoSolicitud_Nombre, h.Empleado_ID,
       h.HistorialSolicitud_Fecha, h.HistorialSolicitud_Comentario
FROM HistorialSolicitud h
JOIN EstadoSolicitud es ON es.EstadoSolicitud_ID=h.EstadoSolicitud_ID;
GO
CREATE OR ALTER VIEW vw_AuditoriaDetalle AS
SELECT a.Auditoria_ID, a.Acceso_ID, a.Auditoria_Entidad,
       a.Auditoria_RegistroId, a.Auditoria_Accion, a.Auditoria_Fecha,
       a.Auditoria_Detalle, a.Auditoria_DireccionIP
FROM Auditoria a;
GO

CREATE OR ALTER VIEW vw_DashboardGlobal AS
SELECT
    (SELECT COUNT(*) FROM Prestamo p JOIN EstadoPrestamo e ON e.EstadoPrestamo_ID=p.EstadoPrestamo_ID WHERE e.EstadoPrestamo_Nombre IN(N'Activo',N'Atrasado')) AS PrestamosActivos,
    (SELECT COUNT(*) FROM Solicitud s JOIN EstadoSolicitud e ON e.EstadoSolicitud_ID=s.EstadoSolicitud_ID WHERE e.EstadoSolicitud_Nombre=N'Pendiente') AS SolicitudesPendientes,
    (SELECT COALESCE(SUM(p.Prestamo_Saldo),0) FROM Prestamo p JOIN EstadoPrestamo e ON e.EstadoPrestamo_ID=p.EstadoPrestamo_ID WHERE e.EstadoPrestamo_Nombre IN(N'Activo',N'Atrasado')) AS Deuda,
    (SELECT COALESCE(SUM(q.Cuota_Saldo),0) FROM Cuota q WHERE q.Cuota_Estado IN(N'Atrasada',N'Mora')) AS Mora;
GO

CREATE OR ALTER VIEW vw_DashboardEmpresa AS
SELECT c.Empresa_ID,
       COUNT(DISTINCT CASE WHEN ep.EstadoPrestamo_Nombre IN(N'Activo',N'Atrasado') THEN p.Prestamo_ID END) AS PrestamosActivos,
       COUNT(DISTINCT CASE WHEN es.EstadoSolicitud_Nombre=N'Pendiente' THEN s.Solicitud_ID END) AS SolicitudesPendientes,
       COALESCE(SUM(DISTINCT CASE WHEN ep.EstadoPrestamo_Nombre IN(N'Activo',N'Atrasado') THEN p.Prestamo_Saldo END),0) AS Deuda,
       COALESCE(SUM(CASE WHEN q.Cuota_Estado IN(N'Atrasada',N'Mora') THEN q.Cuota_Saldo ELSE 0 END),0) AS Mora
FROM Cliente c
LEFT JOIN Solicitud s ON s.Cliente_ID=c.Cliente_ID
LEFT JOIN EstadoSolicitud es ON es.EstadoSolicitud_ID=s.EstadoSolicitud_ID
LEFT JOIN Prestamo p ON p.Solicitud_ID=s.Solicitud_ID
LEFT JOIN EstadoPrestamo ep ON ep.EstadoPrestamo_ID=p.EstadoPrestamo_ID
LEFT JOIN Cuota q ON q.Prestamo_ID=p.Prestamo_ID
GROUP BY c.Empresa_ID;
GO
