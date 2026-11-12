<?php
declare(strict_types=1);

final class Pago extends BaseEntity
{
    protected const TABLE = 'Pago';
    protected const PRIMARY_KEY = 'Pago_ID';
    protected const FIELDS = ['Pago_ID', 'Prestamo_ID', 'MetodoPago_ID', 'Cliente_ID', 'Cuota_ID', 'Pago_Fecha', 'Pago_Monto', 'Pago_Estado', 'Pago_ReversadoFecha', 'Pago_ReversionMotivo', 'Pago_Referencia'];
    public mixed $Pago_ID = null;
    public mixed $Prestamo_ID = null;
    public mixed $MetodoPago_ID = null;
    public mixed $Cliente_ID = null;
    public mixed $Cuota_ID = null;
    public mixed $Pago_Fecha = null;
    public mixed $Pago_Monto = null;
    public mixed $Pago_Estado = null;
    public mixed $Pago_ReversadoFecha = null;
    public mixed $Pago_ReversionMotivo = null;
    public mixed $Pago_Referencia = null;

    public static function registrar(PDO $db, array $valores): array
    {
        $q = $db->prepare('EXEC dbo.sp_RegistrarPago @Cliente_ID=?,@Monto=?,@MetodoPago_ID=?,@Prestamo_ID=?,@Cuota_ID=?,@Referencia=?');
        $q->execute($valores); return $q->fetch() ?: [];
    }
    public static function revertir(PDO $db, array $valores): void
    {
        $q = $db->prepare('EXEC dbo.sp_RevertirPago @Pago_ID=?,@Motivo=?,@Acceso_ID=?,@ReferenciaExterna=?'); $q->execute($valores);
    }
}

