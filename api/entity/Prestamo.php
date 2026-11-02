<?php
final class Prestamo
{
    public static function desembolsar(PDO $db, array $valores): array
    {
        $q = $db->prepare('EXEC dbo.sp_RegistrarDesembolso @Prestamo_ID=?,@MetodoPago_ID=?,@Monto=?,@Acceso_ID=?,@Referencia=?,@Observacion=?');
        $q->execute($valores);
        return $q->fetch() ?: [];
    }

    public static function revertirDesembolso(PDO $db, array $valores): void
    {
        $q = $db->prepare('EXEC dbo.sp_RevertirDesembolso @Desembolso_ID=?,@Motivo=?,@Acceso_ID=?,@ReferenciaExterna=?');
        $q->execute($valores);
    }
}
