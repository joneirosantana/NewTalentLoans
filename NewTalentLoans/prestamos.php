<?php
require_once __DIR__ . '/php/auth.php';
protegerPaginaAdministrativa();
header('Location: gestion-creditos.php?recurso=prestamos', true, 302);
exit;