<?php
declare(strict_types=1);

final class CompanyService
{
    public static function register(PDO $db): array
    {
        $data = ApiSupport::input();
        $email = strtolower(ApiSupport::text($data, 'rrhhCorreo', 254));
        $password = (string)($data['rrhhContrasena'] ?? '');
        if (!filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($password) < 8) throw new InvalidArgumentException('Correo o contraseña de RRHH inválidos.');
        $db->beginTransaction();
        try {
            $addressId = LocationEntity::createAddress($db, [
                'Provincia_Nombre' => ApiSupport::text($data, 'provincia', 100),
                'Ciudad_Nombre' => ApiSupport::text($data, 'ciudad', 100),
                'Direccion_Calle' => ApiSupport::text($data, 'calle', 150),
                'Direccion_Numero' => ApiSupport::text($data, 'numero', 20, false) ?: null,
                'Direccion_Sector' => ApiSupport::text($data, 'sector', 100, false) ?: null,
            ]);
            $q = $db->prepare('INSERT INTO Empresa(Direccion_ID,Empresa_Nombre,Empresa_RNC,Empresa_Correo,Empresa_Telefono) VALUES(?,?,?,?,?)');
            $q->execute([$addressId, ApiSupport::text($data, 'empresaNombre', 180), ApiSupport::text($data, 'rnc', 30), strtolower(ApiSupport::text($data, 'empresaCorreo', 254)), ApiSupport::text($data, 'empresaTelefono', 30, false) ?: null]);
            $companyId = (int)$db->query('SELECT SCOPE_IDENTITY()')->fetchColumn();
            $q = $db->prepare("INSERT INTO PuntoPago(Empresa_ID,PuntoPago_Nombre,PuntoPago_Direccion,PuntoPago_Horario,PuntoPago_Telefono) VALUES(?,?,?,?,?)");
            $q->execute([$companyId, 'Oficina principal', trim((string)$data['calle']), 'Definido por la empresa', $data['empresaTelefono'] ?? null]);
            $roleId = (int)$db->query("SELECT Rol_ID FROM Rol WHERE Rol_Nombre=N'RRHH'")->fetchColumn();
            $q = $db->prepare('INSERT INTO Acceso(Rol_ID,Empresa_ID,Acceso_Correo,Acceso_ContrasenaHash) VALUES(?,?,?,?)');
            $q->execute([$roleId, $companyId, $email, password_hash($password, PASSWORD_DEFAULT)]);
            $accessId = (int)$db->query('SELECT SCOPE_IDENTITY()')->fetchColumn();
            $deptId = (int)$db->query("SELECT Departamento_ID FROM Departamento WHERE Departamento_Nombre=N'Recursos Humanos'")->fetchColumn();
            $q = $db->prepare("INSERT INTO Empleado(Direccion_ID,Acceso_ID,Departamento_ID,Empresa_ID,Empleado_Nombre,Empleado_Apellido,Empleado_Cedula,Empleado_Cargo,Empleado_Estado) VALUES(?,?,?,?,?,?,?,N'Encargado de personal',N'Activo')");
            $q->execute([$addressId, $accessId, $deptId, $companyId, ApiSupport::text($data, 'rrhhNombre', 100), ApiSupport::text($data, 'rrhhApellido', 100), ApiSupport::text($data, 'rrhhCedula', 30)]);
            if (!empty($data['duenoCorreo'])) self::createOwner($db, $companyId, $data);
            $db->commit();
            return ['empresaId' => $companyId, 'rrhhCorreo' => $email, 'mensaje' => 'Empresa registrada. RRHH ya puede administrar la organización.'];
        } catch (Throwable $error) { if ($db->inTransaction()) $db->rollBack(); throw $error; }
    }

    private static function createOwner(PDO $db, int $companyId, array $data): void
    {
        $email = strtolower(ApiSupport::text($data, 'duenoCorreo', 254));
        $password = (string)($data['duenoContrasena'] ?? '');
        if (!filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($password) < 8) throw new InvalidArgumentException('Correo o contraseña del dueño inválidos.');
        $roleId = (int)$db->query("SELECT Rol_ID FROM Rol WHERE Rol_Nombre=N'Dueño'")->fetchColumn();
        $q = $db->prepare('INSERT INTO Acceso(Rol_ID,Empresa_ID,Acceso_Correo,Acceso_ContrasenaHash) VALUES(?,?,?,?)');
        $q->execute([$roleId, $companyId, $email, password_hash($password, PASSWORD_DEFAULT)]);
    }

    public static function list(PDO $db): array
    {
        if (!ApiSupport::admin()) ApiSupport::out(403, ['success' => false, 'message' => 'Solo el administrador puede consultar empresas.']);
        return $db->query("SELECT e.Empresa_ID,e.Empresa_Nombre,e.Empresa_RNC,e.Empresa_Correo,e.Empresa_Telefono,e.Empresa_Estado,
            COUNT(DISTINCT c.Cliente_ID) clientes, COUNT(DISTINCT p.Prestamo_ID) prestamos,
            COALESCE(SUM(p.Prestamo_Saldo),0) saldo
            FROM Empresa e LEFT JOIN Cliente c ON c.Empresa_ID=e.Empresa_ID
            LEFT JOIN Solicitud s ON s.Cliente_ID=c.Cliente_ID LEFT JOIN Prestamo p ON p.Solicitud_ID=s.Solicitud_ID
            GROUP BY e.Empresa_ID,e.Empresa_Nombre,e.Empresa_RNC,e.Empresa_Correo,e.Empresa_Telefono,e.Empresa_Estado")->fetchAll();
    }

    public static function paymentPoints(PDO $db): array
    {
        $companyId = ApiSupport::companyId();
        if ($companyId === null && !empty($_SESSION['cliente_id'])) {
            $q = $db->prepare('SELECT Empresa_ID FROM Cliente WHERE Cliente_ID=?');
            $q->execute([(int)$_SESSION['cliente_id']]);
            $companyId = $q->fetchColumn() ?: null;
        }
        $q = $db->prepare('SELECT PuntoPago_ID,PuntoPago_Nombre,PuntoPago_Direccion,PuntoPago_Horario,PuntoPago_Telefono FROM PuntoPago WHERE PuntoPago_Activo=1 AND (Empresa_ID IS NULL OR Empresa_ID=?) ORDER BY PuntoPago_Nombre');
        $q->execute([$companyId]); return $q->fetchAll();
    }

    public static function update(PDO $db): array
    {
        if (!ApiSupport::admin()) ApiSupport::out(403, ['success' => false, 'message' => 'Solo el administrador puede administrar empresas.']);
        $data = ApiSupport::input();
        $id = (int)($data['empresaId'] ?? 0);
        $status = ApiSupport::text($data, 'estado', 30);
        if (!$id || !in_array($status, ['Activa', 'Inactiva'], true)) throw new InvalidArgumentException('Empresa o estado inválido.');
        $q = $db->prepare('UPDATE Empresa SET Empresa_Estado=? WHERE Empresa_ID=?');
        $q->execute([$status, $id]);
        return ['empresaId' => $id, 'estado' => $status];
    }

    public static function publicList(PDO $db): array
    {
        return $db->query("SELECT Empresa_ID,Empresa_Nombre,Empresa_RNC FROM Empresa WHERE Empresa_Estado=N'Activa' ORDER BY Empresa_Nombre")->fetchAll();
    }
}
