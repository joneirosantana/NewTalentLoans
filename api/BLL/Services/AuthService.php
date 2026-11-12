<?php
final class AuthService
{
    public static function register(PDO $db): array
    {
        $data = ApiSupport::input();
        $first = ApiSupport::text($data, 'nombre', 100);
        $last = ApiSupport::text($data, 'apellido', 100);
        $email = strtolower(ApiSupport::text($data, 'correo', 254));
        $password = (string)($data['contrasena'] ?? '');

        if (str_ends_with($email, '@newtalentloans.com')) {
            return EmployeeService::registerPending($db, $data, $email, $password);
        }

        if (!filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($password) < 8) {
            throw new InvalidArgumentException('Correo inválido o contraseña menor de 8 caracteres.');
        }

        $salary = filter_var($data['sueldo'] ?? 0, FILTER_VALIDATE_FLOAT);
        if ($salary === false || $salary < 0) {
            throw new InvalidArgumentException('El sueldo debe ser igual o mayor que cero.');
        }

        $clientId = Cliente::registrar($db, [
            $first,
            $last,
            ApiSupport::text($data, 'cedula', 30),
            $salary,
            ApiSupport::text($data, 'calle', 150),
            ApiSupport::text($data, 'numero', 20, false) ?: null,
            ApiSupport::text($data, 'sector', 100, false) ?: null,
            ApiSupport::text($data, 'referencia', 500, false) ?: null,
            ApiSupport::text($data, 'provincia', 100),
            ApiSupport::text($data, 'ciudad', 100),
            ApiSupport::text($data, 'telefono', 30),
            $email,
            password_hash($password, PASSWORD_DEFAULT),
        ]);

        $companyId = (int)($data['empresaId'] ?? 0);
        if ($companyId > 0) {
            $query = $db->prepare('UPDATE Cliente SET Empresa_ID=? WHERE Cliente_ID=?');
            $query->execute([$companyId, $clientId]);
            $query = $db->prepare('UPDATE Acceso SET Empresa_ID=? WHERE Acceso_ID=(SELECT Acceso_ID FROM Cliente WHERE Cliente_ID=?)');
            $query->execute([$companyId, $clientId]);
        }

        return [
            'id' => $clientId,
            'nombre' => $first,
            'apellido' => $last,
            'correo' => $email,
            'empresaId' => $companyId ?: null,
        ];
    }

    public static function login(PDO $db): array
    {
        $data = ApiSupport::input();
        $email = strtolower(trim((string)($data['correo'] ?? '')));
        $password = (string)($data['contrasena'] ?? '');

        $admin = admin_credentials();
        if (hash_equals($admin['email'], $email) && hash_equals($admin['password'], $password)) {
            session_regenerate_id(true);
            $_SESSION['acceso_id'] = 0;
            $_SESSION['rol'] = 'Administrador';
            $_SESSION['cliente_id'] = 0;
            $_SESSION['empleado_id'] = 0;
            $_SESSION['empresa_id'] = 0;
            $_SESSION['admin'] = true;
            ApiSupport::audit($db, 'AdministradorBackend', '0', 'LOGIN');
            return [
                'id' => 0,
                'nombre' => $admin['name'],
                'apellido' => '',
                'cargo' => 'Administrador del sistema',
                'rol' => 'Administrador',
                'empresaId' => null,
                'esAdministrador' => true,
            ];
        }

        $sql = 'SELECT Acceso_ID, Acceso_ContrasenaHash, Acceso_Activo,
                       Rol_Nombre, Cliente_ID, Cliente_Nombre, Cliente_Apellido,
                       Empleado_ID, Empleado_Nombre, Empleado_Apellido, Empleado_Cargo,
                       Empresa_ID
                FROM vw_AccesosUsuario
                WHERE Acceso_Correo = ?';
        $query = $db->prepare($sql);
        $query->execute([$email]);
        $user = $query->fetch();

        if (!$user || $user['Rol_Nombre'] === 'Administrador' || !$user['Acceso_Activo'] || !password_verify($password, $user['Acceso_ContrasenaHash'])) {
            if ($user && $user['Rol_Nombre'] === 'Pendiente') {
                throw new InvalidArgumentException('Su solicitud de empleado está pendiente de revisión por RRHH.');
            }
            throw new InvalidArgumentException('Correo o contraseña incorrectos.');
        }

        session_regenerate_id(true);
        $_SESSION['acceso_id'] = (int)$user['Acceso_ID'];
        $_SESSION['rol'] = $user['Rol_Nombre'];
        $_SESSION['cliente_id'] = $user['Cliente_ID'] ? (int)$user['Cliente_ID'] : 0;
        $_SESSION['empleado_id'] = $user['Empleado_ID'] ? (int)$user['Empleado_ID'] : 0;
        $_SESSION['empresa_id'] = $user['Empresa_ID'] ? (int)$user['Empresa_ID'] : 0;
        $_SESSION['admin'] = $user['Rol_Nombre'] === 'Administrador';

        ApiSupport::audit($db, 'Acceso', (string)$user['Acceso_ID'], 'LOGIN');

        return [
            'id' => $_SESSION['cliente_id'] ?: ($_SESSION['empleado_id'] ?: $_SESSION['acceso_id']),
            'nombre' => $user['Cliente_Nombre'] ?: ($user['Empleado_Nombre'] ?: $user['Rol_Nombre']),
            'apellido' => $user['Cliente_Apellido'] ?: ($user['Empleado_Apellido'] ?? ''),
            'cargo' => $user['Empleado_Cargo'] ?? null,
            'rol' => $user['Rol_Nombre'],
            'empresaId' => $_SESSION['empresa_id'] ?: null,
            'esAdministrador' => $_SESSION['admin'],
        ];
    }

    public static function changePassword(PDO $db): array
    {
        if (ApiSupport::admin()) throw new InvalidArgumentException('La cuenta administrativa se gestiona en el backend.');
        $data = ApiSupport::input();
        $identifier = strtolower(ApiSupport::text($data, 'identificador', 254));
        $current = (string)($data['passwordActual'] ?? '');
        $new = (string)($data['passwordNueva'] ?? '');
        if ($current === '' || strlen($new) < 8) throw new InvalidArgumentException('Complete las contraseñas correctamente.');
        $accessId = (int)($_SESSION['acceso_id'] ?? 0);
        if (!$accessId) throw new InvalidArgumentException('La sesión no tiene una cuenta válida.');
        $q = $db->prepare('SELECT Acceso_ID, Acceso_Correo, Acceso_ContrasenaHash, Cliente_Cedula, Empleado_Cedula FROM vw_AccesosUsuario WHERE Acceso_ID=?');
        $q->execute([$accessId]);
        $account = $q->fetch();
        $matches = $account && (strtolower((string)$account['Acceso_Correo']) === $identifier || strtolower((string)($account['Cliente_Cedula'] ?? '')) === $identifier || strtolower((string)($account['Empleado_Cedula'] ?? '')) === $identifier);
        if (!$matches || !password_verify($current, $account['Acceso_ContrasenaHash'])) throw new InvalidArgumentException('El identificador o la contraseña actual no son correctos.');
        $q = $db->prepare('UPDATE Acceso SET Acceso_ContrasenaHash=? WHERE Acceso_ID=?');
        $q->execute([password_hash($new, PASSWORD_DEFAULT), $accessId]);
        ApiSupport::audit($db, 'Acceso', (string)$accessId, 'UPDATE');
        return ['actualizado' => true];
    }
}

