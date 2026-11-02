<?php
final class Cliente
{
    public static function registrar(PDO $db, array $valores): int
    {
        $sql = 'EXEC dbo.sp_RegistrarCliente @Nombre=?,@Apellido=?,@Cedula=?,@Sueldo=?,@Calle=?,@Numero=?,@Sector=?,@Referencia=?,@Provincia=?,@Ciudad=?,@Telefono=?,@Correo=?,@ContrasenaHash=?';
        $q = $db->prepare($sql);
        $q->execute(array_values($valores));
        return (int)$q->fetchColumn();
    }
}
