<?php
require_once __DIR__ . '/php/auth.php';
protegerPaginaAdministrativa();
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Gestión de créditos | New Talent Loans</title>
    <link rel="icon" type="image/x-icon" href="Imagenes/NewTalentLoans.png">
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;500;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="estilos/gestionCreditos.css">
</head>
<body>
    <header class="encabezado"><a href="panel-principal.php">New Talent Loans</a><nav><a href="solicitudes.php">Solicitudes</a><a href="gestion-creditos.php?recurso=prestamos">Préstamos</a><a href="gestion-creditos.php?recurso=pagos">Pagos</a></nav><span id="usuarioActual">Administración</span><a href="#" id="cerrarSesion">Cerrar sesión</a></header>
    <main class="contenido">
        <section class="tarjeta">
            <h1>Gestión del ciclo de crédito</h1>
            <p>Seleccione una entidad para consultar sus registros y administrar sus datos. Los campos se envían con el prefijo de su tabla.</p>
            <label for="recurso">Entidad</label>
            <select id="recurso">
                <option value="solicitudes">Solicitudes</option>
                <option value="prestamos">Préstamos</option>
                <option value="tipos-prestamo">Tipos de préstamo</option>
                <option value="estados-prestamo">Estados del préstamo</option>
                <option value="cuotas">Cuotas</option>
                <option value="pagos">Pagos</option>
                <option value="metodos-pago">Métodos de pago</option>
                <option value="garantes">Garantes</option>
                <option value="facturacion">Facturación</option>
            </select>
            <p id="estado" role="status"></p>
        </section>
        <section class="tarjeta">
            <h2 id="tituloFormulario">Nuevo registro</h2>
            <form id="formularioRegistro"><div id="camposFormulario" class="campos"></div>
                <div class="acciones"><button type="submit" id="guardar">Crear registro</button><button type="button" class="secundario" id="cancelar">Limpiar</button></div>
            </form>
        </section>
        <section class="tarjeta">
            <h2>Registros</h2>
            <div class="tabla-contenedor"><table><thead id="encabezadoTabla"></thead><tbody id="cuerpoTabla"></tbody></table></div>
        </section>
    </main>
    <script src="scripts/gestionCreditos.js"></script>
</body>
</html>