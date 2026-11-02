<?php
final class Pago
{
    public static function registrar(PDO $db, array $valores): array
    {
        $q = $db->prepare('EXEC dbo.sp_RegistrarPago @Cliente_ID=?,@Monto=?,@MetodoPago_ID=?,@Prestamo_ID=?,@Cuota_ID=?,@Referencia=?');
        $q->execute($valores);
        return $q->fetch() ?: [];
    }

    public static function revertir(PDO $db, array $valores): void
    {
        $q = $db->prepare('EXEC dbo.sp_RevertirPago @Pago_ID=?,@Motivo=?,@Acceso_ID=?,@ReferenciaExterna=?');
        $q->execute($valores);
    }
}
