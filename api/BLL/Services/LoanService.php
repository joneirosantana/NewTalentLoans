<?php
final class LoanService
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
        $clientId = ApiSupport::requireUser();

        if ($method === 'GET') {
            return self::listarSolicitudes($db, $clientId);
        }

        if ($method !== 'POST' || ApiSupport::admin()) {
            throw new InvalidArgumentException('Operación no permitida.');
        }

        $data = ApiSupport::input();
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

        $reason = ApiSupport::text($data, 'motivo', 500, false)
            ?: ApiSupport::text($data, 'Solicitud_Motivo', 500, false);
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

    public static function dashboard(PDO $db, int $userId): array
    {
        if (ApiSupport::role('Cliente')) {
            $q = $db->prepare("SELECT COUNT(DISTINCT s.Solicitud_ID) solicitudes, COALESCE(SUM(DISTINCT p.Prestamo_Saldo),0) deuda,
                COALESCE(SUM(CASE WHEN c.Cuota_Estado IN(N'Atrasada',N'Mora') THEN c.Cuota_Saldo ELSE 0 END),0) mora,
                COALESCE(SUM(c.Cuota_Interes),0) interes
                FROM Cliente cl LEFT JOIN Solicitud s ON s.Cliente_ID=cl.Cliente_ID
                LEFT JOIN Prestamo p ON p.Solicitud_ID=s.Solicitud_ID
                LEFT JOIN Cuota c ON c.Prestamo_ID=p.Prestamo_ID WHERE cl.Cliente_ID=?");
            $q->execute([$userId]);
            return $q->fetch() ?: [];
        }
        if (ApiSupport::companyId() !== null) {
            $q = $db->prepare("SELECT COUNT(DISTINCT p.Prestamo_ID) prestamosActivos, COALESCE(SUM(p.Prestamo_Saldo),0) deuda,
                (SELECT COUNT(*) FROM Solicitud ss JOIN EstadoSolicitud ee ON ee.EstadoSolicitud_ID=ss.EstadoSolicitud_ID JOIN Cliente cc ON cc.Cliente_ID=ss.Cliente_ID WHERE cc.Empresa_ID=? AND ee.EstadoSolicitud_Nombre=N'Pendiente') solicitudesPendientes,
                COALESCE(SUM(CASE WHEN c.Cuota_Estado IN(N'Atrasada',N'Mora') THEN c.Cuota_Saldo ELSE 0 END),0) mora
                FROM Prestamo p JOIN Solicitud s ON s.Solicitud_ID=p.Solicitud_ID JOIN Cliente cl ON cl.Cliente_ID=s.Cliente_ID
                JOIN EstadoPrestamo e ON e.EstadoPrestamo_ID=p.EstadoPrestamo_ID LEFT JOIN Cuota c ON c.Prestamo_ID=p.Prestamo_ID
                WHERE cl.Empresa_ID=? AND e.EstadoPrestamo_Nombre IN(N'Activo',N'Atrasado')");
            $q->execute([ApiSupport::companyId(), ApiSupport::companyId()]);
            return $q->fetch() ?: [];
        }
        $stats = $db->query("SELECT COUNT(*) prestamosActivos, COALESCE(SUM(Prestamo_Saldo),0) deuda,
            (SELECT COUNT(*) FROM Solicitud s JOIN EstadoSolicitud e ON e.EstadoSolicitud_ID=s.EstadoSolicitud_ID WHERE e.EstadoSolicitud_Nombre=N'Pendiente') solicitudesPendientes,
            (SELECT COALESCE(SUM(Cuota_Saldo),0) FROM Cuota WHERE Cuota_Estado IN(N'Atrasada',N'Mora')) mora FROM Prestamo p JOIN EstadoPrestamo e ON e.EstadoPrestamo_ID=p.EstadoPrestamo_ID WHERE e.EstadoPrestamo_Nombre IN(N'Activo',N'Atrasado')")->fetch();
        return $stats ?: [];
    }

    public static function myLoans(PDO $db, int $clientId): array
    {
        $q = $db->prepare("SELECT p.Prestamo_ID, p.Prestamo_Monto, p.Prestamo_Tasa, p.Prestamo_Plazo,
            p.Prestamo_FechaDesembolso, p.Prestamo_Saldo, e.EstadoPrestamo_Nombre estado,
            COALESCE(SUM(CASE WHEN c.Cuota_Estado IN(N'Atrasada',N'Mora') THEN c.Cuota_Saldo ELSE 0 END),0) mora
            FROM Prestamo p JOIN Solicitud s ON s.Solicitud_ID=p.Solicitud_ID
            JOIN EstadoPrestamo e ON e.EstadoPrestamo_ID=p.EstadoPrestamo_ID
            LEFT JOIN Cuota c ON c.Prestamo_ID=p.Prestamo_ID WHERE s.Cliente_ID=?
            GROUP BY p.Prestamo_ID,p.Prestamo_Monto,p.Prestamo_Tasa,p.Prestamo_Plazo,p.Prestamo_FechaDesembolso,p.Prestamo_Saldo,e.EstadoPrestamo_Nombre ORDER BY p.Prestamo_ID DESC");
        $q->execute([$clientId]); return $q->fetchAll();
    }

    public static function myInstallments(PDO $db, int $clientId): array
    {
        $q = $db->prepare("SELECT c.Cuota_ID,c.Prestamo_ID,c.Cuota_Numero,c.Cuota_FechaVencimiento,
            c.Cuota_Capital,c.Cuota_Interes,c.Cuota_Monto,c.Cuota_Saldo,c.Cuota_Estado
            FROM Cuota c JOIN Prestamo p ON p.Prestamo_ID=c.Prestamo_ID JOIN Solicitud s ON s.Solicitud_ID=p.Solicitud_ID
            WHERE s.Cliente_ID=? ORDER BY c.Cuota_FechaVencimiento");
        $q->execute([$clientId]); return $q->fetchAll();
    }

    private static function listarSolicitudes(PDO $db, int $clientId): array
    {
        $sql = 'SELECT s.Solicitud_ID, s.Solicitud_Fecha, s.Solicitud_Monto,
                       s.Solicitud_Plazo, s.Solicitud_Motivo,
                       e.EstadoSolicitud_Nombre AS Solicitud_Estado
                FROM Solicitud s
                JOIN EstadoSolicitud e ON e.EstadoSolicitud_ID = s.EstadoSolicitud_ID';

        if (!ApiSupport::staff()) {
            $sql .= ' WHERE s.Cliente_ID = ?';
        }
        $sql .= ' ORDER BY s.Solicitud_Fecha DESC';

        $query = $db->prepare($sql);
        $query->execute(ApiSupport::staff() ? [] : [$clientId]);
        return $query->fetchAll();
    }
}

