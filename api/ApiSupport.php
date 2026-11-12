<?php
declare(strict_types=1);

final class ApiSupport
{
    public static function out(int $status, array $body): never
    {
        lib_out($status, $body);
    }

    public static function input(): array
    {
        return lib_input();
    }

    public static function text(array $data, string $key, int $max, bool $required = true): string
    {
        $value = trim((string)($data[$key] ?? ''));
        if (($required && $value === '') || mb_strlen($value) > $max) {
            throw new InvalidArgumentException('Revise el campo ' . $key . '.');
        }
        return $value;
    }

    public static function admin(): bool
    {
        return ($_SESSION['rol'] ?? null) === 'Administrador';
    }

    public static function role(string ...$roles): bool
    {
        return lib_has_role(...$roles);
    }

    public static function staff(): bool
    {
        return lib_is_staff();
    }

    public static function companyId(): ?int
    {
        return !empty($_SESSION['empresa_id']) ? (int)$_SESSION['empresa_id'] : null;
    }

    public static function readOnlyCompany(): bool
    {
        return self::role('Dueño', 'Gerente');
    }

    public static function requireUser(): int
    {
        return lib_require_user();
    }

    public static function audit(PDO $db, string $entity, string $id, string $action): void
    {
        try {
            $query = $db->prepare(
                'INSERT INTO Auditoria(Acceso_ID, Auditoria_Entidad, Auditoria_RegistroId,
                                      Auditoria_Accion, Auditoria_DireccionIP)
                 VALUES (?, ?, ?, ?, ?)'
            );
            $query->execute([
                $_SESSION['acceso_id'] ?? null,
                $entity,
                $id,
                $action,
                $_SERVER['REMOTE_ADDR'] ?? null,
            ]);
        } catch (Throwable $error) {
            error_log('Auditoría: ' . $error->getMessage());
        }
    }

    public static function databaseMessage(PDOException $error): ?string
    {
        $code = (int)($error->errorInfo[1] ?? 0);
        return self::databaseMessages()[$code] ?? null;
    }

    private static function databaseMessages(): array
    {
        return [
            2601 => 'El correo o documento ya está registrado.',
            2627 => 'El correo o documento ya está registrado.',
            50100 => 'Faltan datos obligatorios del cliente.',
            50101 => 'El sueldo debe ser mayor o igual a cero.',
            50102 => 'No existe el rol Cliente.',
            50103 => 'El correo o la cédula ya están registrados.',
            50110 => 'Monto, tipo, método o plazo inválido.',
            50111 => 'Cliente no encontrado.',
            50112 => 'Tipo de préstamo no encontrado.',
            50113 => 'Método de pago no encontrado.',
            50114 => 'Moneda inválida o inactiva.',
            50115 => 'Falta el estado Pendiente.',
            50116 => 'La cuenta no corresponde al cliente.',
            50120 => 'La decisión de solicitud no es válida.',
            50121 => 'Solicitud no encontrada.',
            50122 => 'La solicitud ya fue resuelta.',
            50123 => 'No existe el estado solicitado.',
            50124 => 'Seleccione el tipo de préstamo.',
            50125 => 'Tipo de préstamo no encontrado.',
            50126 => 'El monto requiere los datos completos del garante.',
            50127 => 'La solicitud ya tiene un préstamo.',
            50128 => 'Falta el estado Aprobado.',
            50130 => 'El monto debe ser mayor que cero.',
            50131 => 'Cliente no encontrado.',
            50132 => 'Método de pago no encontrado.',
            50133 => 'No existe un préstamo activo para el cliente.',
            50134 => 'El monto supera el saldo pendiente.',
            50135 => 'La cuota no pertenece al préstamo o ya fue pagada.',
            50140 => 'El monto del desembolso debe ser mayor que cero.',
            50141 => 'Préstamo no encontrado.',
            50142 => 'Solo se desembolsan préstamos aprobados.',
            50143 => 'El desembolso debe coincidir con el monto aprobado.',
            50144 => 'Método de pago no encontrado.',
            50145 => 'El préstamo ya tiene un desembolso procesado.',
            50146 => 'Falta el estado Activo.',
            50010 => 'El préstamo no existe.',
            50011 => 'El pago supera el saldo o tiene un monto inválido.',
            50012 => 'El préstamo no está desembolsado o activo.',
            50013 => 'El pago no corresponde al cliente del préstamo.',
            50014 => 'Método de pago inválido.',
            50015 => 'No se pudo distribuir el pago entre las cuotas.',
            50016 => 'Use la operación de reversión para cancelar el pago.',
            50017 => 'Un pago nuevo debe iniciar como aplicado.',
            50018 => 'Los datos contables de un pago no se pueden editar.',
            50019 => 'Transición de pago no permitida.',
            50020 => 'Los pagos no se borran; use la reversión.',
            50021 => 'Los desembolsos no se borran.',
            50022 => 'Use la operación de reversión para cancelar el desembolso.',
            50023 => 'La reversión requiere el procedimiento autorizado.',
            50024 => 'Un desembolso nuevo debe iniciar como procesado.',
            50025 => 'La cuota no está pendiente en este préstamo.',
            50030 => 'Una solicitud evaluada no puede volver a Pendiente.',
            50031 => 'Una solicitud evaluada no puede cambiar de cliente, monto, plazo o tipo.',
            50032 => 'Monto fuera del rango permitido.',
            50033 => 'Plazo fuera del rango permitido.',
            50034 => 'Un préstamo cerrado no puede reabrirse manualmente.',
            50035 => 'No se puede desactivar al último administrador activo.',
            50040 => 'Indique el motivo de la reversión.',
            50041 => 'Pago no encontrado.',
            50042 => 'Solo se puede revertir un pago aplicado.',
            50043 => 'Indique el motivo de la reversión del desembolso.',
            50044 => 'Desembolso no encontrado.',
            50045 => 'Solo se puede revertir un desembolso procesado.',
            50046 => 'Revierta primero los pagos aplicados al préstamo.',
            50047 => 'Falta el estado Cancelado.',
        ];
    }

}


