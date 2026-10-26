# Backend de New Talent Loans

## Organización

- `config/database.php`: conexión PDO para SQL Server.
- `entities/Entidades.php`: catálogo de las tablas del ciclo crediticio.
- `entities/Usuario.php`: nombres de columnas usados para acceso y registro.
- `repositories/CrudRepository.php`: operaciones CRUD parametrizadas y lista blanca de campos.
- `services/RegistroService.php`: registro transaccional de ubicación, usuario, acceso y contactos.
- `services/AuthService.php`: inicio de sesión, verificación de contraseña y carga del rol.
- `api.php`: rutas HTTP JSON para POST, GET, PUT y DELETE.

## Usar sin base de datos

En `config/database.php`, deja `MODO_DEMO_SIN_DB` en `true`. El sistema usa almacenamiento local en `php/storage/datos_demo.json` y crea los datos iniciales la primera vez. El registro, las sesiones, las solicitudes y el CRUD financiero funcionan en este modo sin cargar el controlador SQL Server. La carpeta de almacenamiento está protegida por `.htaccess`.

Cuenta administrativa inicial: `admin@newtalentloans.local` / `Demo1234!`. Cambia la contraseña antes de usar el sitio fuera de una demostración. Para reiniciar los datos demo, elimina `php/storage/datos_demo.json` con Apache detenido.

## Conectar SQL Server

Para cambiar al modo real, pon `MODO_DEMO_SIN_DB` en `false`. Desde ese momento cada petición abrirá la conexión PDO de SQL Server y requerirá `pdo_sqlsrv` y las variables de conexión de esta guía.

Activa las extensiones PHP `pdo_sqlsrv` y `sqlsrv` compatibles con la versión de PHP de XAMPP. Configura estas variables de entorno para Apache y reinícialo:

- `NTL_DB_SERVER`: servidor o instancia, por ejemplo `localhost` o `localhost\\SQLEXPRESS`.
- `NTL_DB_NAME`: nombre de la base de datos.
- `NTL_DB_USER` y `NTL_DB_PASSWORD`: credenciales de SQL Server.
- `NTL_CLIENT_ROLE_ID`: ID del rol Cliente que ya exista en `Rol`.
- `NTL_ADMIN_ROLE_ID`: ID del rol administrativo que ya exista en `Rol`.

El usuario SQL Server debe tener permisos limitados a la base del proyecto. El proyecto no crea la base de datos.

## Entidades incluidas del modelo de crédito

La API ya tiene catálogo CRUD para todas estas entidades del diagrama:

- `Solicitud`: `Solicitud_UsuarioId`, fecha, monto, plazo, motivo y estado.
- `Prestamo`: `Prestamo_SolicitudId`, tipo, estado, monto, tasa, plazo, desembolso y saldo.
- `TipoPrestamo` y `EstadoPrestamo`.
- `Cuota`: préstamo, vencimiento, capital, interés, monto, saldo y estado.
- `Pago`: préstamo, método, fecha, monto y usuario que procesa el pago.
- `MetodoPago`, `Garante` y `Facturacion`.

Además se incluyen `Pais`, `Provincia`, `Ciudad`, `Direccion`, `Usuario`, `Acceso`, `Rol`, `Telefono` y `Correo` para el registro y acceso.

Las tablas usan CamelCase y las columnas el prefijo de su tabla, por ejemplo `Solicitud_Monto` y `Prestamo_SolicitudId`. El PPTX de la página 13 no especifica tipos, nulabilidad ni todas las columnas. Los nombres/tipos adicionales del catálogo son una propuesta: alinea `entities/Entidades.php` y `entities/Usuario.php` con tu script SQL final. Las columnas de ID deben ser autogeneradas.

## Rutas

Todas las rutas se llaman desde `php/api.php?recurso=...` y reciben o devuelven JSON:

- `POST ?recurso=registro`: crea ubicación, acceso, usuario, teléfono y correo; requiere `nombre`, `apellido`, `cedula`, `direccion`, `pais`, `provincia`, `ciudad`, `telefono`, `correo` y `contrasena`.
- `POST ?recurso=sesion`: inicia sesión con `correo` y `contrasena`; crea una sesión PHP.
- `POST ?recurso=cerrar-sesion`: termina la sesión.
- CRUD administrativo: `solicitudes`, `prestamos`, `cuotas`, `pagos`, `tipos-prestamo`, `estados-prestamo`, `metodos-pago`, `garantes` y `facturacion`.
- El ID se envía con `?recurso=pagos&id=15`.

Los usuarios autenticados solo consultan sus propias solicitudes. Para los recursos financieros y las operaciones de aprobación/edición de solicitudes, la API exige el ID configurado en `NTL_ADMIN_ROLE_ID`.

Ejemplo para crear una solicitud (los campos mantienen el prefijo de tabla):

```js
fetch('php/api.php?recurso=solicitudes', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    Solicitud_Fecha: '2026-10-26',
    Solicitud_Monto: 15000,
    Solicitud_Plazo: 12,
    Solicitud_Motivo: 'Capital de trabajo',
    Solicitud_Estado: 'Pendiente'
  })
});
```

La API obtiene `Solicitud_UsuarioId` de la sesión, no del formulario. Las pantallas `solicitudes.php` y `gestion-creditos.php` permiten registrar/consultar solicitudes y administrar las entidades financieras (para el rol administrativo). Las pantallas se abren desde `http://localhost/html/NewTalentLoans/`, no con `file://`.

## Acceso a páginas

`index.html` es la portada pública. `iniciar-sesion.php` y `registro.php` son rutas públicas; si ya hay una sesión, ambas redirigen al área del usuario. La creación de una cuenta propia es pública por diseño. La administración interna de clientes requiere rol administrativo.

Las páginas privadas están en PHP para validar la sesión antes de mostrar contenido. Los administradores acceden a los paneles y a la gestión de créditos; los clientes acceden a sus solicitudes. Sin sesión, la página redirige a `index.html`; un cliente que abre una ruta administrativa vuelve a `solicitudes.php`.

Abre el proyecto con `http://localhost/html/NewTalentLoans/` en XAMPP. Las copias anteriores dentro de `Sistemas de Prestamos` están bloqueadas por `.htaccess`.
## Flujo de solicitudes y clientes

- El cliente inicia sesión y crea sus solicitudes desde `solicitudes.php`; el administrador no puede usar ese formulario.
- El administrador abre `Revisar Solicitudes` en `panel-servicios.php` o el recurso Solicitudes de `gestion-creditos.php`.
- Para aprobar una solicitud, selecciona un `TipoPrestamo`. La API cambia el estado a Aprobada y crea el registro `Prestamo` enlazado por `Prestamo_SolicitudId`. El estado del préstamo debe existir como `Activo` o `Aprobado` en `EstadoPrestamo`. Rechazar solo cambia el estado a Rechazada.
- `clientes.php` lista los clientes activos desde la API. El administrador puede crear una cuenta, editar sus datos y desactivarla; desactivar evita el acceso sin borrar el historial.
