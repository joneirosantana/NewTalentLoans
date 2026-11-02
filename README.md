# NewTalentLoans

El proyecto queda separado en `public/` (solo HTML, CSS y JavaScript) y `api/` (PHP, router, controladores, modelos en `entity/`, configuración, SQL y archivos internos). Los logotipos se entregan desde un endpoint de `api/`; no hay PHP ni imágenes sueltas en `public/`. El router recibe `api/?recurso=...` y la configuración privada está en `api/.config.php`.

## Puesta en marcha

1. Configure `server`, `database`, `username` y `password` en `api/.config.php`, o use `NTL_DB_SERVER`, `NTL_DB_NAME`, `NTL_DB_USER` y `NTL_DB_PASSWORD`.
2. Active PDO_SQLSRV en PHP y habilite `mod_rewrite` y `.htaccess` en Apache. Sirva la carpeta por HTTP.
3. En la primera solicitud a la API, si la base no existe, el sistema la crea e instala el esquema completo, los triggers, los procedimientos, roles, catálogos y registros ficticios. La API no ejecuta migraciones ni elimina o modifica bases existentes. El usuario SQL necesita permisos `CREATE DATABASE`, `CREATE TABLE`, `CREATE TRIGGER` y `CREATE PROCEDURE`.
4. Cambie las claves de prueba antes de compartir el entorno. Para producción use variables de entorno y un usuario SQL de permisos limitados.

Credenciales locales configurables: administrador `admin@newtalentloans.local` / `Demo1234!`; cliente de prueba `cliente@newtalentloans.local` / `Cliente123!`; empleado de prueba `empleado@newtalentloans.local` / `Empleado123!`. Se pueden sustituir por variables `NTL_ADMIN_*`, `NTL_DEMO_CLIENT_*` y `NTL_DEMO_EMPLOYEE_*`.

## Flujos conectados

- Registro de clientes guarda acceso con hash, dirección normalizada en Provincia/Ciudad/Direccion, datos de Cliente, teléfono y correo dentro de una transacción.
- Inicio/cierre de sesión usa roles de la tabla `Rol`; la API asigna al usuario el cliente de la sesión y no acepta un `Cliente_ID` enviado por el navegador.
- Catálogos de préstamos y métodos de pago, perfil de cliente y envío/listado de solicitudes utilizan las tablas de `tablas.sql`.
- El administrador tiene CRUD de listas permitidas para entidades financieras en `EntityController`; SQL usa consultas preparadas y la lista de tablas/campos no viene del cliente.
- La instalación usa `api/database/03_creacion_base_datos.sql`, `api/database/02_triggers.sql` y `api/database/01_stored_procedures.sql`, en ese orden. El script de creación no elimina bases existentes; si necesita empezar desde cero, elimine la base manualmente desde SQL Server antes de ejecutarlo. Los cambios a bases existentes también se aplican manualmente. El backend pasa valores enlazados; la contraseña se hashea en PHP y SQL controla roles, claves foráneas, límites, estados y transacciones.
- Se adaptaron `TR_Solicitud_AfterUpdate` (ahora valida también en alta), `TR_Prestamo_AfterUpdate`, `TR_Acceso_AfterUpdate` y la aplicación de pagos/cuotas. Los movimientos de pago y desembolso no se pueden borrar ni editar en sus valores contables.
- El alta de cliente, solicitud, pago y desembolso del router ahora invoca los procedimientos. Las solicitudes se aprueban por `sp_ResolverSolicitud`; los préstamos quedan `Aprobado` sin fecha de desembolso hasta que `sp_RegistrarDesembolso` los activa. El trigger de pago solo acepta préstamos activos, así evita registrar pagos antes del desembolso.

Rutas JSON de esos flujos: `POST api/?recurso=solicitudes` recibe `tipoPrestamoId`, `metodoPagoId`, `monto`, `plazo` y `motivo`; `POST api/?recurso=resolver-solicitud&id=ID` recibe `decision`, `tipoPrestamoId` y, si se necesita, `garanteNombre`, `garanteCedula` y `garanteTelefono`; `POST api/?recurso=registrar-desembolso` recibe `prestamoId`, `metodoPagoId`, `monto`, `referencia` y `observacion`; `POST api/?recurso=pago-cliente` recibe `monto`, `metodoPagoId` y opcionalmente `prestamoId`, `cuotaId` y `referencia`. Cliente y acceso se obtienen de la sesión del servidor.

## Pagos, reversión y cancelación bancaria

`TR_Pago_AfterInsert` valida y aplica cada pago en una transacción SQL, distribuye el importe entre cuotas y crea recibo/auditoría. La relación `PagoCuota` conserva cómo se distribuyó, para que una reversión restaure los saldos correctos. `sp_RevertirPago` cambia el pago a `Revertido`, anula el recibo y deja una fila inmutable en `ReversionPago`; no borra el pago.

Solo un administrador puede llamar `POST api/?recurso=revertir-pago` con `{ "pagoId": 12, "motivo": "Transferencia cancelada", "referenciaExterna": "opcional" }`. Para revertir un desembolso sin pagos aplicados: `POST api/?recurso=revertir-desembolso` con `{ "desembolsoId": 5, "motivo": "Transferencia bancaria rechazada", "referenciaExterna": "opcional" }`. Esto revierte el estado interno y conserva el motivo/referencia; no devuelve dinero al banco ni confirma una operación bancaria. Cuando exista una pasarela, su confirmación deberá preceder a estas rutas y coordinarse como una operación separada.

Las pantallas para registrar desembolsos, capturar datos de garante al aprobar y solicitar reversión aún deben añadirse al front. Sus operaciones están disponibles en la API; la edición CRUD genérica de préstamos, cuotas, pagos, desembolsos, recibos y decisiones de solicitud está bloqueada para que los cambios pasen por los procedimientos.

## Pantallas que requieren trabajo manual

La interfaz antigua incluía pantallas de reportes, panel, pagos, configuración y gestión avanzada basadas en un API distinto. Hay que completarles su front conectado al nuevo router para: aprobar/rechazar solicitudes y generar préstamo/cuotas; registrar pagos y aplicar saldo; procesar desembolsos; administrar documentos de solicitud, garantías y garantes; consultar auditoría y generar reportes. El esquema no guarda garante en una solicitud, así que sus datos deben solicitarse tras aprobar el préstamo. También falta una pantalla de administración de catálogos y usuarios/empleados. El CRUD de API es una base para esas pantallas, no sustituye esos flujos.
