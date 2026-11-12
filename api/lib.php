<?php
declare(strict_types=1);

function lib_out(int $status, array $body): never
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($body, JSON_UNESCAPED_UNICODE);
    exit;
}

function lib_input(): array
{
    $data = json_decode(file_get_contents('php://input'), true);
    if (!is_array($data)) throw new InvalidArgumentException('Envíe un JSON válido.');
    return $data;
}

function lib_has_role(string ...$roles): bool
{
    return in_array((string)($_SESSION['rol'] ?? ''), $roles, true);
}

function lib_is_staff(): bool
{
    return lib_has_role('Administrador', 'RRHH', 'Contable', 'Solicitudes', 'Gerente');
}

function lib_require_user(): int
{
    if (empty($_SESSION['cliente_id']) && empty($_SESSION['empleado_id']) && empty($_SESSION['admin'])) {
        lib_out(401, ['success' => false, 'message' => 'Inicie sesión para continuar.']);
    }
    return (int)($_SESSION['cliente_id'] ?? 0);
}

function lib_dashboard(PDO $db, int $userId): array
{
    return LoanService::dashboard($db, $userId);
}

function lib_my_loans(PDO $db, int $clientId): array
{
    return LoanService::myLoans($db, $clientId);
}

function lib_my_installments(PDO $db, int $clientId): array
{
    return LoanService::myInstallments($db, $clientId);
}

function lib_catalogs(PDO $db, string $resource): array
{
    return LoanService::catalogs($db, $resource);
}

function lib_contact_message(PDO $db): array
{
    $data = lib_input();
    $name = trim((string)($data['nombre'] ?? ''));
    $email = strtolower(trim((string)($data['correo'] ?? '')));
    $message = trim((string)($data['mensaje'] ?? ''));
    if ($name === '' || !filter_var($email, FILTER_VALIDATE_EMAIL) || $message === '') {
        throw new InvalidArgumentException('Indique nombre, correo y mensaje válidos.');
    }
    if (mb_strlen($name) > 120 || mb_strlen($message) > 1000) throw new InvalidArgumentException('El mensaje excede el límite permitido.');
    $q = $db->prepare('INSERT INTO MensajeContacto(Mensaje_Nombre,Mensaje_Correo,Mensaje_Texto) VALUES(?,?,?)');
    $q->execute([$name, $email, $message]);
    return ['id' => (int)$db->query('SELECT SCOPE_IDENTITY()')->fetchColumn()];
}

function lib_requests(PDO $db, string $method): array
{
    return LoanService::solicitudes($db, $method);
}
