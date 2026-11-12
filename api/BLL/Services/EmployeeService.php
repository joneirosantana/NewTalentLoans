<?php
declare(strict_types=1);

final class EmployeeService
{
    public static function registerPending(PDO $db, array $data, string $email, string $password): array
    {
        $first = ApiSupport::text($data, 'nombre', 100);
        $last = ApiSupport::text($data, 'apellido', 100);
        if (strlen($password) < 8) throw new InvalidArgumentException('La contraseña debe tener al menos 8 caracteres.');
        $cedula = ApiSupport::text($data, 'cedula', 30);
        $query = $db->prepare('SELECT COUNT(*) FROM Acceso WHERE Acceso_Correo=?');
        $query->execute([$email]);
        if ($query->fetchColumn()) throw new InvalidArgumentException('El correo de selección de empleado ya tiene una solicitud.');
        $db->beginTransaction();
        try {
            $roleId = (int)$db->query("SELECT Rol_ID FROM Rol WHERE Rol_Nombre=N'Pendiente'")->fetchColumn();
            $query = $db->prepare('INSERT INTO Acceso(Rol_ID,Acceso_Correo,Acceso_ContrasenaHash,Acceso_Activo) VALUES(?,?,?,0)');
            $query->execute([$roleId, $email, password_hash($password, PASSWORD_DEFAULT)]);
            $accessId = (int)$db->query('SELECT SCOPE_IDENTITY()')->fetchColumn();
            $addressId = LocationEntity::createAddress($db, [
                'Provincia_Nombre' => ApiSupport::text($data, 'provincia', 100),
                'Ciudad_Nombre' => ApiSupport::text($data, 'ciudad', 100),
                'Direccion_Calle' => ApiSupport::text($data, 'calle', 150),
                'Direccion_Numero' => ApiSupport::text($data, 'numero', 20, false) ?: null,
                'Direccion_Sector' => ApiSupport::text($data, 'sector', 100, false) ?: null,
                'Direccion_Descripcion' => ApiSupport::text($data, 'referencia', 500, false) ?: null,
            ]);
            $departmentId = (int)$db->query("SELECT Departamento_ID FROM Departamento WHERE Departamento_Nombre=N'Recursos Humanos'")->fetchColumn();
            $query = $db->prepare("INSERT INTO Empleado(Direccion_ID,Acceso_ID,Departamento_ID,Empleado_Nombre,Empleado_Apellido,Empleado_Cedula,Empleado_Cargo,Empleado_Estado) VALUES(?,?,?,?,?,?,N'Solicitante',N'Pendiente')");
            $query->execute([$addressId, $accessId, $departmentId, $first, $last, $cedula]);
            $db->commit();
            return ['tipo' => 'empleado', 'correo' => $email, 'pendiente' => true];
        } catch (Throwable $error) {
            if ($db->inTransaction()) $db->rollBack();
            throw $error;
        }
    }
    public static function pending(PDO $db): array
    {
        if (!ApiSupport::role('Administrador', 'RRHH')) {
            ApiSupport::out(403, ['success' => false, 'message' => 'Solo RRHH puede revisar empleados pendientes.']);
        }
        $companyFilter = ApiSupport::admin() ? '' : ' AND Empresa_ID=' . (int)ApiSupport::companyId();
        return $db->query("SELECT * FROM vw_EmpleadosPendientes WHERE 1=1" . $companyFilter . " ORDER BY Empleado_FechaIngreso")->fetchAll();
    }

    public static function assignRole(PDO $db): array
    {
        if (!ApiSupport::role('Administrador', 'RRHH')) {
            ApiSupport::out(403, ['success' => false, 'message' => 'Solo RRHH puede asignar roles.']);
        }
        $data = ApiSupport::input();
        $employeeId = (int)($data['empleadoId'] ?? 0);
        $role = ApiSupport::text($data, 'rol', 50);
        if (!$employeeId || !in_array($role, ['RRHH', 'Contable', 'Solicitudes', 'Gerente'], true)) {
            throw new InvalidArgumentException('Empleado o rol inválido.');
        }
        $companyFilter = ApiSupport::admin() ? '' : ' AND a.Empresa_ID=' . (int)ApiSupport::companyId();
        $q = $db->prepare("UPDATE a SET a.Rol_ID=r.Rol_ID, a.Acceso_Activo=1
            FROM Acceso a JOIN Empleado e ON e.Acceso_ID=a.Acceso_ID
            JOIN Rol oldr ON oldr.Rol_ID=a.Rol_ID CROSS JOIN Rol r
            WHERE e.Empleado_ID=? AND r.Rol_Nombre=? AND oldr.Rol_Nombre=N'Pendiente'" . $companyFilter);
        $q->execute([$employeeId, $role]);
        if ($q->rowCount() === 0) throw new InvalidArgumentException('El empleado no está pendiente o no existe.');
        $q = $db->prepare("UPDATE Empleado SET Empleado_Estado=N'Activo' WHERE Empleado_ID=?");
        $q->execute([$employeeId]);
        ApiSupport::audit($db, 'Empleado', (string)$employeeId, 'UPDATE');
        return ['empleadoId' => $employeeId, 'rol' => $role, 'activo' => true];
    }
}
