<?php
final class Solicitud
{
    public static function crear(PDO $db, array $valores): int
    {
        $q = $db->prepare('EXEC dbo.sp_CrearSolicitud @Cliente_ID=?,@TipoPrestamo_ID=?,@MetodoPago_ID=?,@Monto=?,@Plazo=?,@Motivo=?,@Moneda_ID=?,@Acceso_ID=?');
        $q->execute($valores);
        return (int)$q->fetchColumn();
    }

    public static function resolver(PDO $db, array $valores): array
    {
        $q = $db->prepare('EXEC dbo.sp_ResolverSolicitud @Solicitud_ID=?,@Decision=?,@TipoPrestamo_ID=?,@Empleado_ID=?,@Garante_Nombre=?,@Garante_Cedula=?,@Garante_Telefono=?,@Comentario=?');
        $q->execute($valores);
        return $q->fetch() ?: [];
    }
}
