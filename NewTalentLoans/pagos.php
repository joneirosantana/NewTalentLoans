<?php
require_once __DIR__ . '/php/auth.php';
protegerPaginaAdministrativa();
header('Location: gestion-creditos.php?recurso=pagos', true, 302);
exit;