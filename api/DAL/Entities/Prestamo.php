<?php
declare(strict_types=1);

final class Prestamo extends BaseEntity
{
    protected const TABLE = 'Prestamo';
    protected const PRIMARY_KEY = 'Prestamo_ID';
    protected const FIELDS = ['Prestamo_ID', 'Solicitud_ID', 'TipoPrestamo_ID', 'EstadoPrestamo_ID', 'Prestamo_Monto', 'Prestamo_Tasa', 'Prestamo_Plazo', 'Prestamo_FechaDesembolso', 'Prestamo_Saldo'];
    public mixed $Prestamo_ID = null;
    public mixed $Solicitud_ID = null;
    public mixed $TipoPrestamo_ID = null;
    public mixed $EstadoPrestamo_ID = null;
    public mixed $Prestamo_Monto = null;
    public mixed $Prestamo_Tasa = null;
    public mixed $Prestamo_Plazo = null;
    public mixed $Prestamo_FechaDesembolso = null;
    public mixed $Prestamo_Saldo = null;

    public static function desembolsar(PDO $db, array $valores): array
    {
        $q = $db->prepare('EXEC dbo.sp_RegistrarDesembolso @Prestamo_ID=?,@MetodoPago_ID=?,@Monto=?,@Acceso_ID=?,@Referencia=?,@Observacion=?');
        $q->execute($valores); return $q->fetch() ?: [];
    }
    public static function revertirDesembolso(PDO $db, array $valores): void
    {
        $q = $db->prepare('EXEC dbo.sp_RevertirDesembolso @Desembolso_ID=?,@Motivo=?,@Acceso_ID=?,@ReferenciaExterna=?'); $q->execute($valores);
    }
}

