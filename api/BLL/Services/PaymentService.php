<?php
declare(strict_types=1);

final class PaymentService
{
    public static function registerInPerson(PDO $db): array
    {
        if (!ApiSupport::role('Administrador', 'Contable', 'Gerente')) {
            ApiSupport::out(403, ['success' => false, 'message' => 'Solo Contabilidad puede registrar pagos recibidos en persona.']);
        }
        $data = ApiSupport::input();
        $pointId = (int)($data['puntoPagoId'] ?? 0);
        $q = $db->prepare('SELECT Empresa_ID FROM PuntoPago WHERE PuntoPago_ID=? AND PuntoPago_Activo=1');
        $q->execute([$pointId]);
        if (!$q->fetch()) throw new InvalidArgumentException('Seleccione un punto de pago activo.');
        $result = Pago::registrar($db, [
            (int)($data['clienteId'] ?? 0),
            (float)($data['monto'] ?? 0),
            (int)($data['metodoPagoId'] ?? 0),
            isset($data['prestamoId']) ? (int)$data['prestamoId'] : null,
            isset($data['cuotaId']) ? (int)$data['cuotaId'] : null,
            ApiSupport::text($data, 'referencia', 100, false) ?: 'Pago presencial',
        ]);
        return ['pagoId' => $result['Pago_ID'] ?? null, 'saldo' => $result['Saldo'] ?? null, 'puntoPagoId' => $pointId];
    }
}
