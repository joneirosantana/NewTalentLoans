<?php
/* Punto único de conexión heredado para archivos PHP antiguos. */
require_once __DIR__ . '/config/database.php';
$conexion = conectarBaseDatos();
