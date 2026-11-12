<?php
declare(strict_types=1);

final class Cliente extends BaseEntity
{
    protected const TABLE = 'Cliente';
    protected const PRIMARY_KEY = 'Cliente_ID';
    protected const FIELDS = ['Cliente_ID', 'Direccion_ID', 'Acceso_ID', 'Cliente_Nombre', 'Cliente_Apellido', 'Cliente_Cedula', 'Cliente_Sueldo', 'Cliente_FechaRegistro'];
    public mixed $Cliente_ID = null;
    public mixed $Direccion_ID = null;
    public mixed $Acceso_ID = null;
    public mixed $Cliente_Nombre = null;
    public mixed $Cliente_Apellido = null;
    public mixed $Cliente_Cedula = null;
    public mixed $Cliente_Sueldo = null;
    public mixed $Cliente_FechaRegistro = null;

    public static function registrar(PDO $db, array $valores): int
    {
        $sql = 'EXEC dbo.sp_RegistrarCliente @Nombre=?,@Apellido=?,@Cedula=?,@Sueldo=?,@Calle=?,@Numero=?,@Sector=?,@Referencia=?,@Provincia=?,@Ciudad=?,@Telefono=?,@Correo=?,@ContrasenaHash=?';
        $q = $db->prepare($sql); $q->execute(array_values($valores)); return (int)$q->fetchColumn();
    }
}

