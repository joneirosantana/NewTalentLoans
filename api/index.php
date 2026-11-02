<?php
declare(strict_types=1);

session_set_cookie_params([
    'httponly' => true,
    'samesite' => 'Lax',
    'secure' => !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off',
]);
session_start();

require_once __DIR__ . '/lib.php';
require_once __DIR__ . '/controllers/AuthController.php';
require_once __DIR__ . '/controllers/LoanController.php';
require_once __DIR__ . '/controllers/EntityController.php';
require_once __DIR__ . '/entity/Cliente.php';
require_once __DIR__ . '/entity/Solicitud.php';
require_once __DIR__ . '/entity/Pago.php';
require_once __DIR__ . '/entity/Prestamo.php';

header('Cache-Control: no-store');

$resource = trim((string)($_GET['recurso'] ?? ''));
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$id = filter_input(INPUT_GET, 'id', FILTER_VALIDATE_INT) ?: null;

try {
    $db = Lib::db();

    if ($resource === 'registro' && $method === 'POST') {
        Lib::out(201, [
            'success' => true,
            'usuario' => AuthController::register($db),
        ]);
    }

    if ($resource === 'sesion' && $method === 'POST') {
        Lib::out(200, [
            'success' => true,
            'usuario' => AuthController::login($db),
        ]);
    }

    if ($resource === 'cerrar-sesion' && $method === 'POST') {
        if (isset($_SESSION['acceso_id'])) {
            Lib::audit($db, 'Acceso', (string)$_SESSION['acceso_id'], 'LOGOUT');
        }
        $_SESSION = [];
        session_destroy();
        Lib::out(200, ['success' => true]);
    }

    if ($resource === 'identidad' && $method === 'GET') {
        Lib::requireUser();
        Lib::out(200, [
            'success' => true,
            'usuario' => ['esAdministrador' => Lib::admin()],
        ]);
    }

    if (in_array($resource, ['tipos-prestamo', 'metodos-pago', 'monedas'], true) && $method === 'GET') {
        Lib::out(200, [
            'success' => true,
            'datos' => LoanController::catalogs($db, $resource),
        ]);
    }

    if ($resource === 'mi-perfil' && $method === 'GET') {
        $clientId = Lib::requireUser();
        $query = $db->prepare(
            'SELECT Cliente_Sueldo sueldo, Cliente_Nombre nombre, Cliente_Apellido apellido
             FROM Cliente WHERE Cliente_ID = ?'
        );
        $query->execute([$clientId]);
        Lib::out(200, ['success' => true] + ($query->fetch() ?: []));
    }

    if ($resource === 'pago-cliente' && $method === 'POST') {
        $clientId = Lib::requireUser();
        if (Lib::admin()) {
            Lib::out(403, ['success' => false, 'message' => 'Esta operación es para clientes.']);
        }

        $data = Lib::input();
        $amount = filter_var($data['monto'] ?? null, FILTER_VALIDATE_FLOAT);
        $methodId = (int)($data['metodoPagoId'] ?? 0);
        if (!$amount || $amount <= 0 || !$methodId) {
            throw new InvalidArgumentException('Indique un monto y método de pago válidos.');
        }

        $payment = Pago::registrar($db, [
            $clientId,
            $amount,
            $methodId,
            isset($data['prestamoId']) ? (int)$data['prestamoId'] : null,
            isset($data['cuotaId']) ? (int)$data['cuotaId'] : null,
            Lib::text($data, 'referencia', 100, false) ?: null,
        ]);
        Lib::out(201, [
            'success' => true,
            'resultado' => [
                'pagoId' => $payment['Pago_ID'] ?? null,
                'saldo' => $payment['Saldo'] ?? null,
            ],
            'message' => 'Pago registrado y aplicado.',
        ]);
    }

    if ($resource === 'solicitudes') {
        Lib::out(200, [
            'success' => true,
            'datos' => LoanController::solicitudes($db, $method),
        ]);
    }

    Lib::requireUser();
    if (!Lib::admin()) {
        Lib::out(403, ['success' => false, 'message' => 'Esta operación requiere el rol administrativo.']);
    }

    if ($resource === 'resolver-solicitud' && $method === 'POST') {
        if (!$id) {
            throw new InvalidArgumentException('Indique la solicitud.');
        }
        $data = Lib::input();
        $result = Solicitud::resolver($db, [
            $id,
            Lib::text($data, 'decision', 20),
            isset($data['tipoPrestamoId']) ? (int)$data['tipoPrestamoId'] : null,
            null,
            Lib::text($data, 'garanteNombre', 150, false) ?: null,
            Lib::text($data, 'garanteCedula', 30, false) ?: null,
            Lib::text($data, 'garanteTelefono', 30, false) ?: null,
            Lib::text($data, 'comentario', 500, false) ?: null,
        ]);
        Lib::out(200, ['success' => true, 'resultado' => $result, 'message' => 'Solicitud resuelta.']);
    }

    if ($resource === 'registrar-desembolso' && $method === 'POST') {
        $data = Lib::input();
        $result = Prestamo::desembolsar($db, [
            (int)($data['prestamoId'] ?? 0),
            (int)($data['metodoPagoId'] ?? 0),
            (float)($data['monto'] ?? 0),
            $_SESSION['acceso_id'] ?? null,
            Lib::text($data, 'referencia', 100, false) ?: null,
            Lib::text($data, 'observacion', 500, false) ?: null,
        ]);
        Lib::out(201, ['success' => true, 'resultado' => $result, 'message' => 'Desembolso registrado.']);
    }

    if ($resource === 'revertir-pago' && $method === 'POST') {
        $data = Lib::input();
        Pago::revertir($db, [
            (int)($data['pagoId'] ?? 0),
            Lib::text($data, 'motivo', 500),
            $_SESSION['acceso_id'] ?? null,
            Lib::text($data, 'referenciaExterna', 100, false) ?: null,
        ]);
        Lib::out(200, ['success' => true, 'message' => 'Pago revertido dentro del sistema.']);
    }

    if ($resource === 'revertir-desembolso' && $method === 'POST') {
        $data = Lib::input();
        Prestamo::revertirDesembolso($db, [
            (int)($data['desembolsoId'] ?? 0),
            Lib::text($data, 'motivo', 500),
            $_SESSION['acceso_id'] ?? null,
            Lib::text($data, 'referenciaExterna', 100, false) ?: null,
        ]);
        Lib::out(200, ['success' => true, 'message' => 'Desembolso revertido dentro del sistema.']);
    }

    Lib::out(200, ['success' => true] + EntityController::run($db, $resource, $method, $id));
} catch (InvalidArgumentException $error) {
    Lib::out(400, ['success' => false, 'message' => $error->getMessage()]);
} catch (PDOException $error) {
    $message = Lib::databaseMessage($error);
    if ($message !== null) {
        Lib::out(409, ['success' => false, 'message' => $message]);
    }
    error_log('NewTalentLoans SQL: ' . $error->getMessage());
    Lib::out(500, ['success' => false, 'message' => 'No se pudo completar la operación en la base de datos.']);
} catch (Throwable $error) {
    error_log('NewTalentLoans: ' . $error->getMessage());
    $message = $error instanceof RuntimeException
        ? $error->getMessage()
        : 'Error al procesar la solicitud.';
    Lib::out(500, ['success' => false, 'message' => $message]);
}
