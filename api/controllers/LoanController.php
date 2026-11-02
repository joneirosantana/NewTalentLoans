<?php
final class LoanController
{
    private const CATALOGS = [
        'tipos-prestamo' => ['TipoPrestamo', 'TipoPrestamo_ID', 'TipoPrestamo_Nombre'],
        'metodos-pago' => ['MetodoPago', 'MetodoPago_ID', 'MetodoPago_Nombre'],
        'monedas' => ['Moneda', 'Moneda_ID', 'Moneda_Codigo'],
    ];

    public static function catalogs(PDO $db, string $name): array
    {
        if (!isset(self::CATALOGS[$name])) {
            throw new InvalidArgumentException('Catálogo desconocido.');
        }

        [$table, $id, $label] = self::CATALOGS[$name];
        $columns = "[$id], [$label]";
        if ($table === 'TipoPrestamo') {
            $columns .= ', TipoPrestamo_TasaBase';
        }

        $filter = $table === 'Moneda' ? ' WHERE Moneda_Activa = 1' : '';
        $sql = "SELECT $columns FROM [$table]$filter ORDER BY 2";
        return $db->query($sql)->fetchAll();
    }

    public static function solicitudes(PDO $db, string $method): array
    {
        $clientId = Lib::requireUser();

        if ($method === 'GET') {
            return self::listarSolicitudes($db, $clientId);
        }

        if ($method !== 'POST' || Lib::admin()) {
            throw new InvalidArgumentException('Operación no permitida.');
        }

        $data = Lib::input();
        $amount = filter_var($data['monto'] ?? $data['Solicitud_Monto'] ?? null, FILTER_VALIDATE_FLOAT);
        $term = filter_var($data['plazo'] ?? $data['Solicitud_Plazo'] ?? null, FILTER_VALIDATE_INT);

        if (!$amount || $amount <= 0 || !$term || $term < 1 || $term > 120) {
            throw new InvalidArgumentException('Monto o plazo inválido.');
        }

        $typeId = (int)($data['tipoPrestamoId'] ?? $data['Solicitud_TipoPrestamoId'] ?? 0);
        $methodId = (int)($data['metodoPagoId'] ?? $data['Solicitud_MetodoPagoId'] ?? 0);
        if (!$typeId || !$methodId) {
            throw new InvalidArgumentException('Seleccione tipo de préstamo y método de pago.');
        }

        $reason = Lib::text($data, 'motivo', 500, false)
            ?: Lib::text($data, 'Solicitud_Motivo', 500, false);
        $requestId = Solicitud::crear($db, [
            $clientId,
            $typeId,
            $methodId,
            $amount,
            $term,
            $reason ?: null,
            isset($data['monedaId']) ? (int)$data['monedaId'] : null,
            $_SESSION['acceso_id'] ?? null,
        ]);

        return ['id' => $requestId];
    }

    private static function listarSolicitudes(PDO $db, int $clientId): array
    {
        $sql = 'SELECT s.Solicitud_ID, s.Solicitud_Fecha, s.Solicitud_Monto,
                       s.Solicitud_Plazo, s.Solicitud_Motivo,
                       e.EstadoSolicitud_Nombre AS Solicitud_Estado
                FROM Solicitud s
                JOIN EstadoSolicitud e ON e.EstadoSolicitud_ID = s.EstadoSolicitud_ID';

        if (!Lib::admin()) {
            $sql .= ' WHERE s.Cliente_ID = ?';
        }
        $sql .= ' ORDER BY s.Solicitud_Fecha DESC';

        $query = $db->prepare($sql);
        $query->execute(Lib::admin() ? [] : [$clientId]);
        return $query->fetchAll();
    }
}
