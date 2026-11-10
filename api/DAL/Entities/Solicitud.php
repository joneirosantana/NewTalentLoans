<?php
declare(strict_types=1);

final class Solicitud extends BaseEntity
{
    protected const TABLE = 'Solicitud';
    protected const PRIMARY_KEY = 'Solicitud_ID';
    protected const FIELDS = ['Solicitud_ID', 'Cliente_ID', 'TipoPrestamo_ID', 'MetodoPago_ID', 'Moneda_ID', 'EstadoSolicitud_ID', 'Solicitud_Fecha', 'Solicitud_Monto', 'Solicitud_Plazo', 'Solicitud_Motivo'];
    public mixed $Solicitud_ID = null;
    public mixed $Cliente_ID = null;
    public mixed $TipoPrestamo_ID = null;
    public mixed $MetodoPago_ID = null;
    public mixed $Moneda_ID = null;
    public mixed $EstadoSolicitud_ID = null;
    public mixed $Solicitud_Fecha = null;
    public mixed $Solicitud_Monto = null;
    public mixed $Solicitud_Plazo = null;
    public mixed $Solicitud_Motivo = null;

    public static function crear(PDO $db, array $valores): int
    {
        $q = $db->prepare('EXEC dbo.sp_CrearSolicitud @Cliente_ID=?,@TipoPrestamo_ID=?,@MetodoPago_ID=?,@Monto=?,@Plazo=?,@Motivo=?,@Moneda_ID=?,@Acceso_ID=?');
        $q->execute($valores); return (int)$q->fetchColumn();
    }
    public static function resolver(PDO $db, array $valores): array
    {
        $q = $db->prepare('EXEC dbo.sp_ResolverSolicitud @Solicitud_ID=?,@Decision=?,@TipoPrestamo_ID=?,@Empleado_ID=?,@Garante_Nombre=?,@Garante_Cedula=?,@Garante_Telefono=?,@Comentario=?');
        $q->execute($valores); return $q->fetch() ?: [];
    }
}

