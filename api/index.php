<?php
declare(strict_types=1);

$allowedOrigins = ['http://newtalentloans.local', 'http://api.newtalentloans.local', 'http://localhost', 'http://127.0.0.1'];
$origin = (string)($_SERVER['HTTP_ORIGIN'] ?? '');
if (in_array($origin, $allowedOrigins, true)) {
    header('Access-Control-Allow-Origin: ' . $origin);
    header('Access-Control-Allow-Credentials: true');
    header('Vary: Origin');
}
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    http_response_code(204);
    exit;
}
session_set_cookie_params([
    'httponly' => true,
    'samesite' => 'Lax',
    'secure' => !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off',
]);
session_start();

require_once __DIR__ . '/ApiSupport.php';
require_once __DIR__ . '/lib.php';
require_once __DIR__ . '/admin.php';
require_once __DIR__ . '/DAL/DatabaseConnection.php';
require_once __DIR__ . '/DAL/DatabaseManager.php';
require_once __DIR__ . '/DAL/Entities/EntityInterface.php';
require_once __DIR__ . '/DAL/Entities/BaseEntity.php';
foreach (glob(__DIR__ . '/DAL/Entities/*.php') as $entityFile) {
    if (!in_array(basename($entityFile), ['EntityInterface.php', 'BaseEntity.php'], true)) require_once $entityFile;
}
foreach (glob(__DIR__ . '/BLL/Services/*.php') as $serviceFile) require_once $serviceFile;

header('Cache-Control: no-store');

$resource = trim((string)($_GET['recurso'] ?? ''));
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$id = filter_input(INPUT_GET, 'id', FILTER_VALIDATE_INT) ?: null;

try {
    $db = DatabaseConnection::get();

    if ($resource === 'contacto' && $method === 'POST') {
        ApiSupport::out(201, ['success' => true, 'resultado' => lib_contact_message($db), 'message' => 'Mensaje enviado a servicio al cliente.']);
    }

    if ($resource === 'registro' && $method === 'POST') {
        ApiSupport::out(201, [
            'success' => true,
            'usuario' => AuthService::register($db),
        ]);
    }

    if ($resource === 'registro-empresa' && $method === 'POST') {
        ApiSupport::out(201, ['success' => true, 'empresa' => CompanyService::register($db)]);
    }

    if ($resource === 'sesion' && $method === 'POST') {
        ApiSupport::out(200, [
            'success' => true,
            'usuario' => AuthService::login($db),
        ]);
    }

    if ($resource === 'cambiar-contrasena' && $method === 'POST') {
        ApiSupport::requireUser();
        ApiSupport::out(200, ['success' => true, 'resultado' => AuthService::changePassword($db), 'message' => 'Contraseña actualizada correctamente.']);
    }

    if ($resource === 'cerrar-sesion' && $method === 'POST') {
        if (isset($_SESSION['acceso_id'])) {
            ApiSupport::audit($db, 'Acceso', (string)$_SESSION['acceso_id'], 'LOGOUT');
        }
        $_SESSION = [];
        session_destroy();
        ApiSupport::out(200, ['success' => true]);
    }

    if ($resource === 'identidad' && $method === 'GET') {
        ApiSupport::requireUser();
        ApiSupport::out(200, [
            'success' => true,
            'usuario' => [
                'esAdministrador' => ApiSupport::admin(),
                'rol' => $_SESSION['rol'] ?? null,
                'clienteId' => $_SESSION['cliente_id'] ?? null,
                'empleadoId' => $_SESSION['empleado_id'] ?? null,
                'empresaId' => $_SESSION['empresa_id'] ?? null,
            ],
        ]);
    }

    if ($resource === 'empresas' && $method === 'GET') {
        ApiSupport::requireUser();
        ApiSupport::out(200, ['success' => true, 'datos' => CompanyService::list($db)]);
    }

    if ($resource === 'empresas-publicas' && $method === 'GET') {
        ApiSupport::out(200, ['success' => true, 'datos' => CompanyService::publicList($db)]);
    }

    if ($resource === 'actualizar-empresa' && $method === 'POST') {
        ApiSupport::requireUser();
        ApiSupport::out(200, ['success' => true, 'resultado' => CompanyService::update($db)]);
    }

    if ($resource === 'puntos-pago' && $method === 'GET') {
        ApiSupport::requireUser();
        ApiSupport::out(200, ['success' => true, 'datos' => CompanyService::paymentPoints($db)]);
    }

    if ($resource === 'dashboard' && $method === 'GET') {
        $userId = ApiSupport::requireUser();
        ApiSupport::out(200, ['success' => true, 'datos' => lib_dashboard($db, $userId)]);
    }

    if ($resource === 'empleados-pendientes' && $method === 'GET') {
        ApiSupport::requireUser();
        ApiSupport::out(200, ['success' => true, 'datos' => EmployeeService::pending($db)]);
    }

    if ($resource === 'asignar-rol-empleado' && $method === 'POST') {
        ApiSupport::requireUser();
        ApiSupport::out(200, ['success' => true, 'resultado' => EmployeeService::assignRole($db)]);
    }

    if (in_array($resource, ['mis-prestamos', 'mis-cuotas'], true) && $method === 'GET') {
        $clientId = ApiSupport::requireUser();
        if (!ApiSupport::role('Cliente')) ApiSupport::out(403, ['success' => false, 'message' => 'Solo el cliente puede consultar este resumen.']);
        $datos = $resource === 'mis-prestamos' ? lib_my_loans($db, $clientId) : lib_my_installments($db, $clientId);
        ApiSupport::out(200, ['success' => true, 'datos' => $datos]);
    }

    if (in_array($resource, ['tipos-prestamo', 'metodos-pago', 'monedas'], true) && $method === 'GET') {
        ApiSupport::out(200, [
            'success' => true,
            'datos' => lib_catalogs($db, $resource),
        ]);
    }

    if ($resource === 'mi-perfil' && $method === 'GET') {
        $clientId = ApiSupport::requireUser();
        $query = $db->prepare(
            'SELECT Cliente_Sueldo sueldo, Cliente_Nombre nombre, Cliente_Apellido apellido
             FROM Cliente WHERE Cliente_ID = ?'
        );
        $query->execute([$clientId]);
        ApiSupport::out(200, ['success' => true] + ($query->fetch() ?: []));
    }

    if ($resource === 'pago-cliente' && $method === 'POST') {
        ApiSupport::out(403, ['success' => false, 'message' => 'Los pagos se realizan personalmente en el punto de pago indicado.']);
    }

    if ($resource === 'registrar-pago-presencial' && $method === 'POST') {
        ApiSupport::requireUser();
        ApiSupport::out(201, ['success' => true, 'resultado' => PaymentService::registerInPerson($db), 'message' => 'Pago presencial registrado por el personal autorizado.']);
    }

    if ($resource === 'solicitudes') {
        ApiSupport::out(200, [
            'success' => true,
            'datos' => lib_requests($db, $method),
        ]);
    }

    ApiSupport::requireUser();
    if (ApiSupport::readOnlyCompany() && $method !== 'GET') {
        ApiSupport::out(403, ['success' => false, 'message' => 'Este perfil solo puede consultar resultados autorizados.']);
    }
    if (ApiSupport::role('Dueño') && !in_array($resource, ['identidad', 'dashboard'], true)) {
        ApiSupport::out(403, ['success' => false, 'message' => 'El perfil dueño solo puede consultar su resumen empresarial.']);
    }
    if (ApiSupport::role('Gerente') && !in_array($resource, ['identidad', 'dashboard', 'clientes'], true)) {
        ApiSupport::out(403, ['success' => false, 'message' => 'El perfil gerente solo puede consultar resultados empresariales autorizados.']);
    }
    if (!ApiSupport::staff() && !(ApiSupport::readOnlyCompany() && $method === 'GET')) {
        ApiSupport::out(403, ['success' => false, 'message' => 'Esta operación requiere un rol de empleado autorizado.']);
    }

    if ($resource === 'resolver-solicitud' && $method === 'POST') {
        if (!$id) {
            throw new InvalidArgumentException('Indique la solicitud.');
        }
        $data = ApiSupport::input();
        $result = Solicitud::resolver($db, [
            $id,
            ApiSupport::text($data, 'decision', 20),
            isset($data['tipoPrestamoId']) ? (int)$data['tipoPrestamoId'] : null,
            null,
            ApiSupport::text($data, 'garanteNombre', 150, false) ?: null,
            ApiSupport::text($data, 'garanteCedula', 30, false) ?: null,
            ApiSupport::text($data, 'garanteTelefono', 30, false) ?: null,
            ApiSupport::text($data, 'comentario', 500, false) ?: null,
        ]);
        ApiSupport::out(200, ['success' => true, 'resultado' => $result, 'message' => 'Solicitud resuelta.']);
    }

    if ($resource === 'registrar-desembolso' && $method === 'POST') {
        $data = ApiSupport::input();
        $result = Prestamo::desembolsar($db, [
            (int)($data['prestamoId'] ?? 0),
            (int)($data['metodoPagoId'] ?? 0),
            (float)($data['monto'] ?? 0),
            $_SESSION['acceso_id'] ?? null,
            ApiSupport::text($data, 'referencia', 100, false) ?: null,
            ApiSupport::text($data, 'observacion', 500, false) ?: null,
        ]);
        ApiSupport::out(201, ['success' => true, 'resultado' => $result, 'message' => 'Desembolso registrado.']);
    }

    if ($resource === 'revertir-pago' && $method === 'POST') {
        $data = ApiSupport::input();
        Pago::revertir($db, [
            (int)($data['pagoId'] ?? 0),
            ApiSupport::text($data, 'motivo', 500),
            $_SESSION['acceso_id'] ?? null,
            ApiSupport::text($data, 'referenciaExterna', 100, false) ?: null,
        ]);
        ApiSupport::out(200, ['success' => true, 'message' => 'Pago revertido dentro del sistema.']);
    }

    if ($resource === 'revertir-desembolso' && $method === 'POST') {
        $data = ApiSupport::input();
        Prestamo::revertirDesembolso($db, [
            (int)($data['desembolsoId'] ?? 0),
            ApiSupport::text($data, 'motivo', 500),
            $_SESSION['acceso_id'] ?? null,
            ApiSupport::text($data, 'referenciaExterna', 100, false) ?: null,
        ]);
        ApiSupport::out(200, ['success' => true, 'message' => 'Desembolso revertido dentro del sistema.']);
    }

    ApiSupport::out(200, ['success' => true] + EntityService::run($db, $resource, $method, $id));
} catch (InvalidArgumentException $error) {
    ApiSupport::out(400, ['success' => false, 'message' => $error->getMessage()]);
} catch (PDOException $error) {
    $message = ApiSupport::databaseMessage($error);
    if ($message !== null) {
        ApiSupport::out(409, ['success' => false, 'message' => $message]);
    }
    error_log('NewTalentLoans SQL: ' . $error->getMessage());
    ApiSupport::out(500, ['success' => false, 'message' => $resource === 'sesion'
        ? 'No se pudo validar el inicio de sesión. Verifique sus datos e intente nuevamente.'
        : 'No se pudo completar la operación. Intente nuevamente.']);
} catch (Throwable $error) {
    error_log('NewTalentLoans: ' . $error->getMessage());
    ApiSupport::out(500, ['success' => false, 'message' => 'No se pudo completar la operación. Intente nuevamente.']);
}




