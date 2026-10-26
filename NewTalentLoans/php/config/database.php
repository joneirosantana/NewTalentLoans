<?php
/* true = modo local sin SQL Server; false = intentar conexión SQL Server. */
define('MODO_DEMO_SIN_DB', true);
function obtenerConfiguracionBaseDatos()
{
    return array(
        'servidor' => getenv('NTL_DB_SERVER') ?: 'localhost',
        'baseDatos' => getenv('NTL_DB_NAME') ?: 'NewTalentLoans',
        'usuario' => getenv('NTL_DB_USER') ?: '',
        'contrasena' => getenv('NTL_DB_PASSWORD') ?: '',
        'rolClienteId' => getenv('NTL_CLIENT_ROLE_ID') ?: '',
        'rolAdministradorId' => getenv('NTL_ADMIN_ROLE_ID') ?: ''
    );
}

function conectarBaseDatos()
{
    $configuracion = obtenerConfiguracionBaseDatos();
    $dsn = 'sqlsrv:Server=' . $configuracion['servidor'] . ';Database=' . $configuracion['baseDatos'] . ';TrustServerCertificate=1';
    try {
        return new PDO($dsn, $configuracion['usuario'], $configuracion['contrasena'], array(
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::SQLSRV_ATTR_ENCODING => PDO::SQLSRV_ENCODING_UTF8
        ));
    } catch (PDOException $error) {
        error_log('No se pudo conectar a SQL Server: ' . $error->getMessage());
        throw new RuntimeException('No fue posible conectar con SQL Server. Revise la configuración y la extensión PDO_SQLSRV.');
    }
}