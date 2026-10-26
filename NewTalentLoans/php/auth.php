<?php
require_once __DIR__ . '/config/database.php';

function iniciarSesionAplicacion()
{
    if (session_status() !== PHP_SESSION_ACTIVE) {
        session_start();
    }
}

function usuarioTieneSesion()
{
    iniciarSesionAplicacion();
    return isset($_SESSION['usuarioId']);
}

function usuarioEsAdministrador()
{
    iniciarSesionAplicacion();
    if (!isset($_SESSION['usuarioId'], $_SESSION['rolId'])) {
        return false;
    }
    if (MODO_DEMO_SIN_DB) {
        $rolAdministradorId = 1;
    } else {
        $configuracion = obtenerConfiguracionBaseDatos();
        $rolAdministradorId = $configuracion['rolAdministradorId'];
    }
    return $rolAdministradorId !== '' && (string)$_SESSION['rolId'] === (string)$rolAdministradorId;
}

function protegerPagina()
{
    iniciarSesionAplicacion();
    header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
    header('Pragma: no-cache');
    if (!isset($_SESSION['usuarioId'])) {
        header('Location: index.html', true, 302);
        exit;
    }
}

function protegerPaginaSolicitudesCliente()
{
    protegerPagina();
    if (usuarioEsAdministrador()) {
        header('Location: gestion-creditos.php?recurso=solicitudes', true, 302);
        exit;
    }
}
function protegerPaginaAdministrativa()
{
    protegerPagina();
    if (!usuarioEsAdministrador()) {
        header('Location: solicitudes.php', true, 302);
        exit;
    }
}

function redirigirSiYaInicioSesion()
{
    if (!usuarioTieneSesion()) {
        return;
    }
    if (usuarioEsAdministrador()) {
        header('Location: panel-servicios.php', true, 302);
    } else {
        header('Location: solicitudes.php', true, 302);
    }
    exit;
}