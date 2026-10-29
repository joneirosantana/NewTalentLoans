# Triggers adicionales - New Talent Loans

Para: Enrique Rodriguez Santana. De: Rousvet.

El proyecto pide 3 triggers como minimo. Con `TR_Pago_AfterInsert` ya eran 1; ahora son 4. Estan adaptados al script `NewTalentLoans_completo.sql` y a las pruebas `NewTalentLoans_Tests.sql` que ya teniamos.

## Archivos
| Archivo | Para que sirve |
|---|---|
| `NewTalentLoans_completo.sql` | Su script completo con la seccion 6.6 de triggers ya integrada (solo cambie el encabezado y se agrego la seccion; nada mas). |
| `NewTalentLoans_Triggers.sql` | Solo la seccion 6.6, para correrla sobre una base que ya existe. |
| `NewTalentLoans_Tests.sql` | Version 4 de las pruebas de pagos T1 a T7. Corrige T5, que usaba al administrador (sueldo 0) como cliente y fallaba con el error 3930 por la regla del garante. No tiene relacion con los triggers nuevos. |
| `NewTalentLoans_Tests_Triggers.sql` | 16 pruebas en el mismo estilo de `NewTalentLoans_Tests.sql` (tabla `#Resultados` con OK/FAIL). Borra lo que crea. |
| `php/repositories/CrudRepository.php` | Opcional. Ver "Sobre el PHP". |

## Los triggers
| Trigger | Tabla y evento | Que hace | Errores |
|---|---|---|---|
| `TR_Solicitud_AfterUpdate` | Solicitud, UPDATE | No deja volver a Pendiente una solicitud ya evaluada. No deja cambiar cliente, monto, plazo ni tipo de una solicitud evaluada. Si se edita el monto o el plazo, deben estar dentro de los limites del tipo de prestamo. | 50030 monto, 50031 plazo, 50032 estado, 50033 evaluada |
| `TR_Prestamo_AfterUpdate` | Prestamo, UPDATE | Guarda en Auditoria cada cambio real de estado (Activo -> Finalizado, etc.). No deja reabrir un prestamo Finalizado o Cancelado. | 50034 |
| `TR_Acceso_AfterUpdate` | Acceso, UPDATE | Guarda en Auditoria activar/desactivar cuenta, cambio de rol, de correo y de contrasena (sin guardar el hash). No deja desactivar ni quitarle el rol al ultimo administrador activo. | 50035 |

Los codigos 50030 a 50035 no chocan con los que ya existen (50001-50002, 50010-50015, 50020-50027, 50099).

## Por que son AFTER UPDATE y no AFTER INSERT
SQL Server rechaza `INSERT ... OUTPUT INSERTED.x` (error 334) solo cuando la tabla tiene un trigger habilitado para esa misma accion. El PHP usa `OUTPUT INSERTED` al crear solicitudes, prestamos, accesos y demas. Como los triggers nuevos son solo de UPDATE, ese codigo sigue funcionando igual, sin tocar el PHP. La unica tabla con trigger de INSERT es `Pago`, como antes.

Limite honesto: como no hay trigger de INSERT en Solicitud, los limites de monto y plazo se validan al editar la solicitud, no al crearla. Si quieren validar tambien al crear, se puede cambiar a `AFTER INSERT, UPDATE`, pero entonces el PHP debe usar `SCOPE_IDENTITY()` en lugar de `OUTPUT INSERTED` (el archivo de `php/` ya lo hace).

## Como probarlos (en este orden)
1. Ejecutar `NewTalentLoans_completo.sql` completo en SSMS. Si ya tienen la base creada, basta con ejecutar `NewTalentLoans_Triggers.sql`.
2. Ejecutar `NewTalentLoans_Tests.sql` v4, la que viene en esta carpeta (las pruebas T1 a T7 del trigger de pagos). Deben seguir dando OK: los triggers nuevos no cambian ese flujo. El de Prestamo solo agrega filas de auditoria con tabla `Prestamo`, y T7 cuenta solo las de tabla `Pago`.
3. Ejecutar `NewTalentLoans_Tests_Triggers.sql`. Al final muestra la tabla de resultados.

Resultado esperado del paso 2: 7 filas, T1 a T7, todas `OK`.

Resultado esperado del paso 3: 16 filas, todas `OK`. TA5 y TA6 dan `SKIP` si la base tiene mas de un administrador activo (necesitan exactamente uno).

Si TP3 da `FAIL`, revisen que en el servidor este activa la opcion `nested triggers` (viene activa por defecto), porque esa prueba depende de que el trigger de Prestamo se dispare dentro del de Pago.

## Sobre el PHP (para cuando lo integres)
- `CrudRepository.php`: el CRUD generico inserta con `OUTPUT INSERTED`. Con `TR_Pago_AfterInsert` eso falla para el recurso `pagos`. El archivo incluido usa `SCOPE_IDENTITY()` y arregla todas las tablas a la vez.
- `PrestamoClienteService.php`: inserta el pago y despues actualiza saldo y estado del prestamo por su cuenta. Con `TR_Pago_AfterInsert` el trigger ya hace eso, asi que esas lineas sobran y conviene quitarlas.

## Importante
El codigo se reviso de forma estatica (nombres de columnas, bloques BEGIN/END y TRY/CATCH, codigos de error sin choques) y se comparo contra el script y las pruebas existentes, pero **todavia no se ha ejecutado en un SQL Server real**. Hay que correr los tres pasos de arriba y confirmar los resultados. Si algo falla, copien la tabla `#Resultados` o el mensaje de error completo para corregirlo.
