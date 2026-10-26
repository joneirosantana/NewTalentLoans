<?php
require_once __DIR__ . '/php/auth.php';
protegerPaginaSolicitudesCliente();
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Mis préstamos | New Talent Loans</title>
    <link rel="icon" href="Imagenes/NewTalentLoans.png"><link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;500;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="estilos/solicitudes.css">
</head>
<body>
<header class="encabezado"><a href="index.html">New Talent Loans</a><nav><a href="index.html">Inicio</a></nav><span id="nombreUsuario">Usuario</span><a href="#" id="cerrarSesion">Cerrar sesión</a></header>
<main class="contenido">
    <section class="tarjeta">
        <h1>Solicitar un préstamo</h1><p>Elija el tipo, monto y plazo. Puede calcular una proyección antes de enviar su solicitud.</p>
        <p id="sueldoCliente" class="dato-sueldo">Cargando sueldo mensual…</p>
        <form id="formSolicitud">
            <label for="tipoPrestamo">Tipo de préstamo</label><select id="tipoPrestamo" required><option value="">Cargando tipos…</option></select>
            <label for="monto">Monto solicitado (RD$)</label><input id="monto" type="number" min="1" step="0.01" required>
            <label for="plazo">Plazo en meses</label><input id="plazo" type="number" min="1" max="120" required>
            <label for="metodoPago">Método de pago preferido</label><select id="metodoPago" required><option value="">Cargando métodos…</option></select>
            <div id="grupoGarante" class="grupo-garante" hidden>
                <h3>Se requiere un garante</h3><p>El monto supera su sueldo mensual. Complete los datos para continuar.</p>
                <label for="garanteNombre">Nombre completo del garante</label><input id="garanteNombre" type="text" maxlength="150">
                <label for="garanteCedula">Cédula del garante</label><input id="garanteCedula" type="text" maxlength="30">
                <label for="garanteTelefono">Teléfono del garante</label><input id="garanteTelefono" type="tel" maxlength="30">
            </div>
            <label for="motivo">Motivo de la solicitud</label><textarea id="motivo" rows="4" maxlength="500" required></textarea>
            <div class="acciones-formulario"><button id="btnProyeccion" type="button" class="secundario">Proyección de préstamo</button><button id="btnEnviar" type="submit">Enviar solicitud</button></div>
            <div id="resultadoProyeccion" class="proyeccion" role="status" hidden></div>
        </form><p id="mensaje" role="status"></p>
    </section>
    <section id="panelPrestamoActivo" class="tarjeta" hidden>
        <h2>Mi préstamo activo</h2><div id="resumenPrestamo" class="resumen-prestamo"></div>
        <form id="formPago"><h3>Registrar pago o adelanto</h3>
            <label for="tipoPago">Operación</label><select id="tipoPago"><option value="cuota">Pago</option><option value="adelanto">Adelanto a capital</option></select>
            <label for="montoPago">Monto (RD$)</label><input id="montoPago" type="number" min="0.01" step="0.01" required>
            <label for="metodoPagoActivo">Método de pago</label><select id="metodoPagoActivo" required></select>
            <button id="btnRegistrarPago" type="submit">Registrar operación</button>
        </form><p id="mensajePago" role="status"></p>
        <button id="btnContacto" type="button" class="secundario">Contactar soporte</button><div id="datosContacto" class="datos-contacto" hidden><a class="contacto" href="mailto:contacto@NuevoTalentoLoans.com">contacto@NuevoTalentoLoans.com</a><a class="contacto" href="tel:8091110000">8091110000</a></div>
    </section>
    <section class="tarjeta"><h2>Mis solicitudes</h2><div class="tabla-contenedor"><table><thead><tr><th>Fecha</th><th>Monto</th><th>Plazo</th><th>Motivo</th><th>Estado</th></tr></thead><tbody id="listaSolicitudes"><tr><td colspan="5">Cargando…</td></tr></tbody></table></div></section>
</main><script src="scripts/solicitudes.js"></script>
</body></html>
