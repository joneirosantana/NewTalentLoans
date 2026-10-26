<?php
$host = 'localhost';
$user = 'root';
$password = '';
$database = 'sin_asignar';

$conexion = new mysqli($host, $user, $password, $database);

if ($conexion->connect_error) {
	die ("Error de Conexion" . $conexion->connect_error);
}

$conexion->set_charset("utf8");
?>