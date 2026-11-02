<?php
final class AuthController
{
    public static function register(PDO $db): array
    {
        $data = Lib::input();
        $first = Lib::text($data, 'nombre', 100);
        $last = Lib::text($data, 'apellido', 100);
        $email = strtolower(Lib::text($data, 'correo', 254));
        $password = (string)($data['contrasena'] ?? '');

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
            Lib::text($data, 'cedula', 30),
            $salary,
            Lib::text($data, 'calle', 150),
            Lib::text($data, 'numero', 20, false) ?: null,
            Lib::text($data, 'sector', 100, false) ?: null,
            Lib::text($data, 'referencia', 500, false) ?: null,
            Lib::text($data, 'provincia', 100),
            Lib::text($data, 'ciudad', 100),
            Lib::text($data, 'telefono', 30),
            $email,
            password_hash($password, PASSWORD_DEFAULT),
        ]);

        return [
            'id' => $clientId,
            'nombre' => $first,
            'apellido' => $last,
            'correo' => $email,
        ];
    }

    public static function login(PDO $db): array
    {
        Lib::seedAdmin($db);
        $data = Lib::input();
        $email = strtolower(trim((string)($data['correo'] ?? '')));
        $password = (string)($data['contrasena'] ?? '');

        $sql = 'SELECT a.Acceso_ID, a.Acceso_ContrasenaHash, a.Acceso_Activo,
                       r.Rol_Nombre, c.Cliente_ID, c.Cliente_Nombre, c.Cliente_Apellido
                FROM Acceso a
                JOIN Rol r ON r.Rol_ID = a.Rol_ID
                LEFT JOIN Cliente c ON c.Acceso_ID = a.Acceso_ID
                WHERE a.Acceso_Correo = ?';
        $query = $db->prepare($sql);
        $query->execute([$email]);
        $user = $query->fetch();

        if (!$user || !$user['Acceso_Activo'] || !password_verify($password, $user['Acceso_ContrasenaHash'])) {
            throw new InvalidArgumentException('Correo o contraseña incorrectos.');
        }

        session_regenerate_id(true);
        $_SESSION['acceso_id'] = (int)$user['Acceso_ID'];
        $_SESSION['rol'] = $user['Rol_Nombre'];
        $_SESSION['cliente_id'] = $user['Cliente_ID'] ? (int)$user['Cliente_ID'] : 0;
        $_SESSION['admin'] = $user['Rol_Nombre'] === 'Administrador';

        Lib::audit($db, 'Acceso', (string)$user['Acceso_ID'], 'LOGIN');

        return [
            'id' => $_SESSION['cliente_id'] ?: $_SESSION['acceso_id'],
            'nombre' => $user['Cliente_Nombre'] ?: $user['Rol_Nombre'],
            'apellido' => $user['Cliente_Apellido'] ?? '',
            'esAdministrador' => $_SESSION['admin'],
        ];
    }
}
