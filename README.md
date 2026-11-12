# NewTalentLoans 2.0

El proyecto separa la GUI en `public/` y la API en `api/`. En local la GUI se sirve en `http://newtalentloans.local` y consume `http://api.newtalentloans.local/?recurso=...`. La configuración privada está en `api/.config.php`.

La versión 2.0 incorpora dashboard de cliente con solicitudes, préstamos, cuotas, deuda, interés y mora; dashboard interno por rol; y roles de empleado para RRHH, Contabilidad, Solicitudes y Gerencia. La tabla `Direccion` integra Provincia, Ciudad y los datos de calle/sector.

El registro clasifica automáticamente como empleado cualquier correo cuyo dominio termine en `@newtalentloans.com`; esas cuentas quedan pendientes y desactivadas hasta la revisión de RRHH. Todos los demás dominios se registran como clientes.

Para Apache, copie `apache-vhosts.conf` al archivo de VirtualHosts, habilite `mod_rewrite` y agregue al archivo hosts: `127.0.0.1 newtalentloans.local api.newtalentloans.local`.

## Puesta en marcha

1. Configure `server`, `database`, `username` y `password` en `api/.config.php`, o use `NTL_DB_SERVER`, `NTL_DB_NAME`, `NTL_DB_USER` y `NTL_DB_PASSWORD`.
2. Active PDO_SQLSRV en PHP y habilite `mod_rewrite` y `.htaccess` en Apache. Sirva la carpeta por HTTP.
3. En la primera solicitud a la API, si la base no existe o está vacía, el sistema instala el esquema completo, `vistas.sql`, los triggers, los procedimientos, roles, catálogos y registros ficticios. La cuenta administrativa se valida exclusivamente en `api/admin.php`; no se crea en `Rol`, `Acceso` ni `Empleado`.
4. Cambie las claves de prueba antes de compartir el entorno. Para producción use variables de entorno y un usuario SQL de permisos limitados.

Credenciales locales: administrador `admin@newtalentloans.local` / `Demo1234!`, definidas en `api/admin.php`; cliente de prueba `cliente@newtalentloans.local` / `Cliente123!`. No se crea un empleado demo.

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

## Entidades y acceso de datos

El CRUD usa `TableEntity` para tablas configuradas por el controlador, `CatalogEntity` para listas compartidas y `LocationEntity` para provincia, ciudad y dirección. `Cliente`, `Solicitud`, `Prestamo` y `Pago` conservan clases específicas porque tienen reglas y procedimientos de negocio propios. `EntityInterface` define las operaciones comunes (`getAll`, `getById`, `insert`, `update`, `delete`) y `DatabaseManager` arma las consultas parametrizadas con tabla y campos permitidos.

Cuando se usa `TableEntity` para insertar solicitud, préstamo, pago, desembolso, factura o garantía, se pueden pasar nombres o códigos configurados de catálogos en vez de IDs. Busca la opción y reutiliza su ID; si no existe, la crea con los datos requeridos dentro de la misma transacción. Los flujos actuales protegidos continúan usando sus procedimientos almacenados. `LocationEntity::createAddress` aplica el mismo patrón a provincia, ciudad y dirección. El registro de clientes existente resuelve esa ubicación desde `sp_RegistrarCliente`.

## Esquema de base de datos

El esquema de instalación y desarrollo se mantiene en `api/database/03_creacion_base_datos.sql`; los procedimientos y triggers permanecen en sus archivos SQL separados. Los cambios del esquema durante este desarrollo se editan ahí. No se agregó un sistema de migraciones ni historial de versiones.


## Organización por capas

- `public/`: GUI (HTML, CSS y JavaScript).
- `api/index.php`: entrada HTTP del backend; conserva las rutas que usa la GUI.
- `api/BLL/Services/`: servicios de autenticación, préstamos y operaciones CRUD con reglas de negocio.
- `api/DAL/`: conexión, instalación inicial, consultas parametrizadas y entidades agrupadas.
- `api/database/`: definición SQL, procedimientos y triggers.
- `api/ApiSupport.php`: utilidades de transporte HTTP, sesión y validación de entrada.

La GUI permanece en `public/`. El trabajo de interfaz puede avanzar después sin mover las reglas del BLL ni el acceso del DAL.

## Dominios y driver de datos

La GUI se publica en `http://newtalentloans.local` y consume `http://api.newtalentloans.local`. El API usa CORS con credenciales para esos orígenes y localhost de desarrollo. El VirtualHost del API apunta a `api/` y el principal a la raíz del proyecto.

El driver DAL es `DatabaseConnection`: mantiene una conexión PDO compartida, usa `pdo_sqlsrv` para SQL Server, carga sus parámetros desde `api/.config.php` y ejecuta la instalación inicial solo cuando la base no existe. `DatabaseManager` concentra las consultas parametrizadas CRUD. La lógica del driver Singleton del proyecto de referencia se adaptó a PDO y se conservaron consultas preparadas para no concatenar valores SQL.
