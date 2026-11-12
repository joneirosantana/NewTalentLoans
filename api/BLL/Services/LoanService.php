<?php
final class LoanService
{
    private const CATALOGS = [
        'tipos-prestamo' => ['vw_CatalogoTipoPrestamo', 'TipoPrestamo_ID', 'TipoPrestamo_Nombre'],
        'metodos-pago' => ['vw_CatalogoMetodoPago', 'MetodoPago_ID', 'MetodoPago_Nombre'],
        'monedas' => ['vw_CatalogoMoneda', 'Moneda_ID', 'Moneda_Codigo'],
    ];

    public static function catalogs(PDO $db, string $name): array
    {
        if (!isset(self::CATALOGS[$name])) {
            throw new InvalidArgumentException('Catálogo desconocido.');
        }

        [$table, $id, $label] = self::CATALOGS[$name];
        $columns = "[$id], [$label]";
        if ($name === 'tipos-prestamo') {
            $columns .= ', TipoPrestamo_TasaBase';
        }

        $filter = $name === 'monedas' ? ' WHERE Moneda_Activa = 1' : '';
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
                FROM vw_ClientesDetalle cl LEFT JOIN vw_SolicitudesDetalle s ON s.Cliente_ID=cl.Cliente_ID
                LEFT JOIN vw_PrestamosResumen p ON p.Solicitud_ID=s.Solicitud_ID
                LEFT JOIN vw_CuotasDetalle c ON c.Prestamo_ID=p.Prestamo_ID WHERE cl.Cliente_ID=?");
            $q->execute([$userId]);
            return $q->fetch() ?: [];
        }
        if (ApiSupport::companyId() !== null) {
            $q = $db->prepare('SELECT TOP 1 PrestamosActivos, SolicitudesPendientes, Deuda AS deuda, Mora AS mora FROM vw_DashboardEmpresa WHERE Empresa_ID=?');
            $q->execute([ApiSupport::companyId()]);
            return $q->fetch() ?: [];
        }
        $stats = $db->query('SELECT PrestamosActivos AS prestamosActivos, SolicitudesPendientes AS solicitudesPendientes, Deuda AS deuda, Mora AS mora FROM vw_DashboardGlobal')->fetch();
        return $stats ?: [];
    }

    public static function myLoans(PDO $db, int $clientId): array
    {
        $q = $db->prepare("SELECT Prestamo_ID, Prestamo_Monto, Prestamo_Tasa, Prestamo_Plazo,
            Prestamo_FechaDesembolso, Prestamo_Saldo, EstadoPrestamo_Nombre AS estado, mora
            FROM vw_PrestamosResumen WHERE Cliente_ID=? ORDER BY Prestamo_ID DESC");
        $q->execute([$clientId]); return $q->fetchAll();
    }

    public static function myInstallments(PDO $db, int $clientId): array
    {
        $q = $db->prepare("SELECT Cuota_ID,Prestamo_ID,Cuota_Numero,Cuota_FechaVencimiento,
            Cuota_Capital,Cuota_Interes,Cuota_Monto,Cuota_Saldo,Cuota_Estado
            FROM vw_CuotasDetalle WHERE Cliente_ID=? ORDER BY Cuota_FechaVencimiento");
        $q->execute([$clientId]); return $q->fetchAll();
    }

    private static function listarSolicitudes(PDO $db, int $clientId): array
    {
        $sql = 'SELECT Solicitud_ID, Solicitud_Fecha, Solicitud_Monto,
                       Solicitud_Plazo, Solicitud_Motivo, Solicitud_Estado
                FROM vw_SolicitudesDetalle';

        if (!ApiSupport::staff()) {
            $sql .= ' WHERE Cliente_ID = ?';
        }
        $sql .= ' ORDER BY s.Solicitud_Fecha DESC';

        $query = $db->prepare($sql);
        $query->execute(ApiSupport::staff() ? [] : [$clientId]);
        return $query->fetchAll();
    }
}

