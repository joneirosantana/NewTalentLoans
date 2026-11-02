<?php
declare(strict_types=1);

final class Lib
{
    public static function db(): PDO
    {
        static $connection;
        if ($connection instanceof PDO) {
            return $connection;
        }

        $config = require __DIR__ . '/.config.php';
        if (!preg_match('/^[A-Za-z0-9_]+$/', $config['database'])) {
            throw new RuntimeException('El nombre de la base solo puede contener letras, números y guion bajo.');
        }

        $options = [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ];
        $master = new PDO(
            'sqlsrv:Server=' . $config['server'] . ';Database=master;TrustServerCertificate=1',
            $config['username'],
            $config['password'],
            $options
        );

        $query = $master->prepare('SELECT DB_ID(?)');
        $query->execute([$config['database']]);
        $databaseId = $query->fetchColumn();
        $isNewDatabase = $databaseId === false || $databaseId === null;

        if ($isNewDatabase) {
            $master->exec('CREATE DATABASE [' . $config['database'] . ']');
        }

        $connection = new PDO(
            'sqlsrv:Server=' . $config['server'] . ';Database=' . $config['database'] . ';TrustServerCertificate=1',
            $config['username'],
            $config['password'],
            $options
        );

        $schemaExists = (bool)$connection->query("SELECT OBJECT_ID('Rol', 'U')")->fetchColumn();
        if ($isNewDatabase) {
            self::installDatabase($connection);
        } elseif (!$schemaExists) {
            throw new RuntimeException(
                'La base de datos existe, pero no tiene el esquema del proyecto. Modifíquela o elimínela manualmente antes de iniciar la API.'
            );
        }

        $query = $connection->prepare('SELECT COUNT(*) FROM Acceso WHERE Acceso_Correo = ?');
        $query->execute([$config['demo_client_email']]);
        if ($isNewDatabase || !$query->fetchColumn()) {
            self::seedDemo($connection);
        }

        return $connection;
    }

    private static function installDatabase(PDO $db): void
    {
        $files = [
            __DIR__ . '/database/03_creacion_base_datos.sql',
            __DIR__ . '/database/02_triggers.sql',
            __DIR__ . '/database/01_stored_procedures.sql',
        ];

        foreach ($files as $file) {
            if (!is_file($file)) {
                throw new RuntimeException('No se encontró el archivo de instalación ' . basename($file) . '.');
            }

            $batches = preg_split('/^\s*GO\s*$/mi', file_get_contents($file));
            foreach ($batches as $index => $batch) {
                $batch = trim($batch);
                $databaseHeader = basename($file) === '03_creacion_base_datos.sql' && $index < 2;
                if ($batch === '' || $databaseHeader || preg_match('/\bUSE\s+/i', $batch)) {
                    continue;
                }
                $db->exec($batch);
            }
        }
    }

    private static function seedDemo(PDO $db): void
    {
        $db->beginTransaction();
        try {
            foreach (['Administrador', 'Cliente', 'Empleado'] as $role) {
                $query = $db->prepare(
                    'IF NOT EXISTS (SELECT 1 FROM Rol WHERE Rol_Nombre = ?)
                     INSERT INTO Rol(Rol_Nombre) VALUES (?)'
                );
                $query->execute([$role, $role]);
            }

            $catalogs = [
                ['EstadoSolicitud', 'EstadoSolicitud_Nombre', ['Pendiente', 'Aprobada', 'Rechazada']],
                ['EstadoPrestamo', 'EstadoPrestamo_Nombre', ['Aprobado', 'Activo', 'Pagado', 'Atrasado', 'Cancelado']],
                ['TipoPrestamo', 'TipoPrestamo_Nombre', ['Personal', 'Educativo', 'Emergencia']],
                ['MetodoPago', 'MetodoPago_Nombre', ['Efectivo', 'Transferencia', 'Tarjeta']],
            ];
            foreach ($catalogs as [$table, $column, $values]) {
                foreach ($values as $value) {
                    self::insertCatalogValue($db, $table, $column, $value);
                }
            }

            $db->exec(
                "IF NOT EXISTS (SELECT 1 FROM Moneda WHERE Moneda_Codigo = 'DOP')
                 INSERT INTO Moneda(Moneda_Codigo, Moneda_Nombre, Moneda_Simbolo)
                 VALUES ('DOP', N'Peso dominicano', N'RD$')"
            );

            $config = require __DIR__ . '/.config.php';
            $clientRole = (int)$db->query("SELECT Rol_ID FROM Rol WHERE Rol_Nombre = N'Cliente'")->fetchColumn();
            $employeeRole = (int)$db->query("SELECT Rol_ID FROM Rol WHERE Rol_Nombre = N'Empleado'")->fetchColumn();
            $cityId = self::demoCity($db);

            self::seedPerson(
                $db, $config['demo_client_email'], $config['demo_client_password'],
                $clientRole, 'Ana', 'Prueba', '000-0000000-1', $cityId, true
            );
            self::seedPerson(
                $db, $config['demo_employee_email'], $config['demo_employee_password'],
                $employeeRole, 'Luis', 'Prueba', '000-0000000-2', $cityId, false
            );
            $db->commit();
        } catch (Throwable $error) {
            if ($db->inTransaction()) {
                $db->rollBack();
            }
            throw $error;
        }
    }

    private static function insertCatalogValue(PDO $db, string $table, string $column, string $value): void
    {
        $extraColumn = $table === 'TipoPrestamo' ? ', TipoPrestamo_TasaBase' : '';
        $extraValue = $table === 'TipoPrestamo' ? ', 10' : '';
        $sql = "IF NOT EXISTS (SELECT 1 FROM [$table] WHERE [$column] = ?)
                INSERT INTO [$table] ([$column]$extraColumn) VALUES (?$extraValue)";
        $query = $db->prepare($sql);
        $query->execute([$value, $value]);
    }

    private static function demoCity(PDO $db): int
    {
        $cityId = (int)$db->query('SELECT TOP 1 Ciudad_ID FROM Ciudad')->fetchColumn();
        if ($cityId > 0) {
            return $cityId;
        }

        $db->exec(
            "INSERT INTO Provincia(Provincia_Nombre) VALUES (N'Distrito Nacional');
             INSERT INTO Ciudad(Provincia_ID, Ciudad_Nombre)
             VALUES (SCOPE_IDENTITY(), N'Santo Domingo')"
        );
        return (int)$db->query('SELECT SCOPE_IDENTITY()')->fetchColumn();
    }

    private static function seedPerson(
        PDO $db,
        string $email,
        string $password,
        int $roleId,
        string $firstName,
        string $lastName,
        string $identityNumber,
        int $cityId,
        bool $isClient
    ): void {
        $query = $db->prepare('SELECT Acceso_ID FROM Acceso WHERE Acceso_Correo = ?');
        $query->execute([$email]);
        if ($query->fetchColumn()) {
            return;
        }

        $query = $db->prepare(
            'INSERT INTO Acceso(Rol_ID, Acceso_Correo, Acceso_ContrasenaHash)
             VALUES (?, ?, ?)'
        );
        $query->execute([$roleId, $email, password_hash($password, PASSWORD_DEFAULT)]);
        $accessId = (int)$db->query('SELECT SCOPE_IDENTITY()')->fetchColumn();

        $query = $db->prepare('INSERT INTO Direccion(Ciudad_ID, Direccion_Calle) VALUES (?, ?)');
        $query->execute([$cityId, 'Calle de Prueba']);
        $addressId = (int)$db->query('SELECT SCOPE_IDENTITY()')->fetchColumn();

        if ($isClient) {
            self::insertDemoClient($db, $addressId, $accessId, $firstName, $lastName, $identityNumber, $email);
            return;
        }

        $query = $db->prepare(
            'INSERT INTO Empleado(Direccion_ID, Acceso_ID, Empleado_Nombre, Empleado_Apellido,
                                  Empleado_Cedula, Empleado_Cargo)
             VALUES (?, ?, ?, ?, ?, ?)'
        );
        $query->execute([$addressId, $accessId, $firstName, $lastName, $identityNumber, 'Agente de prueba']);
    }

    private static function insertDemoClient(
        PDO $db,
        int $addressId,
        int $accessId,
        string $firstName,
        string $lastName,
        string $identityNumber,
        string $email
    ): void {
        $query = $db->prepare(
            'INSERT INTO Cliente(Direccion_ID, Acceso_ID, Cliente_Nombre, Cliente_Apellido,
                                Cliente_Cedula, Cliente_Sueldo)
             VALUES (?, ?, ?, ?, ?, ?)'
        );
        $query->execute([$addressId, $accessId, $firstName, $lastName, $identityNumber, 50000]);
        $clientId = (int)$db->query('SELECT SCOPE_IDENTITY()')->fetchColumn();

        $query = $db->prepare('INSERT INTO Telefono(Cliente_ID, Telefono_Numero) VALUES (?, ?)');
        $query->execute([$clientId, '8090000001']);
        $query = $db->prepare('INSERT INTO Correo(Cliente_ID, Correo_Direccion) VALUES (?, ?)');
        $query->execute([$clientId, $email]);
    }

    public static function out(int $status, array $body): never
    {
        http_response_code($status);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode($body, JSON_UNESCAPED_UNICODE);
        exit;
    }

    public static function input(): array
    {
        $data = json_decode(file_get_contents('php://input'), true);
        if (!is_array($data)) {
            throw new InvalidArgumentException('Envíe un JSON válido.');
        }
        return $data;
    }

    public static function text(array $data, string $key, int $max, bool $required = true): string
    {
        $value = trim((string)($data[$key] ?? ''));
        if (($required && $value === '') || mb_strlen($value) > $max) {
            throw new InvalidArgumentException('Revise el campo ' . $key . '.');
        }
        return $value;
    }

    public static function admin(): bool
    {
        return ($_SESSION['rol'] ?? null) === 'Administrador';
    }

    public static function requireUser(): int
    {
        if (empty($_SESSION['cliente_id']) && empty($_SESSION['admin'])) {
            self::out(401, ['success' => false, 'message' => 'Inicie sesión para continuar.']);
        }
        return (int)($_SESSION['cliente_id'] ?? 0);
    }

    public static function audit(PDO $db, string $entity, string $id, string $action): void
    {
        try {
            $query = $db->prepare(
                'INSERT INTO Auditoria(Acceso_ID, Auditoria_Entidad, Auditoria_RegistroId,
                                      Auditoria_Accion, Auditoria_DireccionIP)
                 VALUES (?, ?, ?, ?, ?)'
            );
            $query->execute([
                $_SESSION['acceso_id'] ?? null,
                $entity,
                $id,
                $action,
                $_SERVER['REMOTE_ADDR'] ?? null,
            ]);
        } catch (Throwable $error) {
            error_log('Auditoría: ' . $error->getMessage());
        }
    }

    public static function databaseMessage(PDOException $error): ?string
    {
        $code = (int)($error->errorInfo[1] ?? 0);
        return self::databaseMessages()[$code] ?? null;
    }

    private static function databaseMessages(): array
    {
        return [
            2601 => 'El correo o documento ya está registrado.',
            2627 => 'El correo o documento ya está registrado.',
            50100 => 'Faltan datos obligatorios del cliente.',
            50101 => 'El sueldo debe ser mayor o igual a cero.',
            50102 => 'No existe el rol Cliente.',
            50103 => 'El correo o la cédula ya están registrados.',
            50110 => 'Monto, tipo, método o plazo inválido.',
            50111 => 'Cliente no encontrado.',
            50112 => 'Tipo de préstamo no encontrado.',
            50113 => 'Método de pago no encontrado.',
            50114 => 'Moneda inválida o inactiva.',
            50115 => 'Falta el estado Pendiente.',
            50116 => 'La cuenta no corresponde al cliente.',
            50120 => 'La decisión de solicitud no es válida.',
            50121 => 'Solicitud no encontrada.',
            50122 => 'La solicitud ya fue resuelta.',
            50123 => 'No existe el estado solicitado.',
            50124 => 'Seleccione el tipo de préstamo.',
            50125 => 'Tipo de préstamo no encontrado.',
            50126 => 'El monto requiere los datos completos del garante.',
            50127 => 'La solicitud ya tiene un préstamo.',
            50128 => 'Falta el estado Aprobado.',
            50130 => 'El monto debe ser mayor que cero.',
            50131 => 'Cliente no encontrado.',
            50132 => 'Método de pago no encontrado.',
            50133 => 'No existe un préstamo activo para el cliente.',
            50134 => 'El monto supera el saldo pendiente.',
            50135 => 'La cuota no pertenece al préstamo o ya fue pagada.',
            50140 => 'El monto del desembolso debe ser mayor que cero.',
            50141 => 'Préstamo no encontrado.',
            50142 => 'Solo se desembolsan préstamos aprobados.',
            50143 => 'El desembolso debe coincidir con el monto aprobado.',
            50144 => 'Método de pago no encontrado.',
            50145 => 'El préstamo ya tiene un desembolso procesado.',
            50146 => 'Falta el estado Activo.',
            50010 => 'El préstamo no existe.',
            50011 => 'El pago supera el saldo o tiene un monto inválido.',
            50012 => 'El préstamo no está desembolsado o activo.',
            50013 => 'El pago no corresponde al cliente del préstamo.',
            50014 => 'Método de pago inválido.',
            50015 => 'No se pudo distribuir el pago entre las cuotas.',
            50016 => 'Use la operación de reversión para cancelar el pago.',
            50017 => 'Un pago nuevo debe iniciar como aplicado.',
            50018 => 'Los datos contables de un pago no se pueden editar.',
            50019 => 'Transición de pago no permitida.',
            50020 => 'Los pagos no se borran; use la reversión.',
            50021 => 'Los desembolsos no se borran.',
            50022 => 'Use la operación de reversión para cancelar el desembolso.',
            50023 => 'La reversión requiere el procedimiento autorizado.',
            50024 => 'Un desembolso nuevo debe iniciar como procesado.',
            50025 => 'La cuota no está pendiente en este préstamo.',
            50030 => 'Una solicitud evaluada no puede volver a Pendiente.',
            50031 => 'Una solicitud evaluada no puede cambiar de cliente, monto, plazo o tipo.',
            50032 => 'Monto fuera del rango permitido.',
            50033 => 'Plazo fuera del rango permitido.',
            50034 => 'Un préstamo cerrado no puede reabrirse manualmente.',
            50035 => 'No se puede desactivar al último administrador activo.',
            50040 => 'Indique el motivo de la reversión.',
            50041 => 'Pago no encontrado.',
            50042 => 'Solo se puede revertir un pago aplicado.',
            50043 => 'Indique el motivo de la reversión del desembolso.',
            50044 => 'Desembolso no encontrado.',
            50045 => 'Solo se puede revertir un desembolso procesado.',
            50046 => 'Revierta primero los pagos aplicados al préstamo.',
            50047 => 'Falta el estado Cancelado.',
        ];
    }

    public static function seedAdmin(PDO $db): void
    {
        $config = require __DIR__ . '/.config.php';
        $query = $db->prepare('SELECT COUNT(*) FROM Acceso WHERE Acceso_Correo = ?');
        $query->execute([$config['admin_email']]);
        if ($query->fetchColumn()) {
            return;
        }

        $roleId = $db->query("SELECT Rol_ID FROM Rol WHERE Rol_Nombre = N'Administrador'")->fetchColumn();
        if (!$roleId) {
            return;
        }

        $query = $db->prepare(
            'INSERT INTO Acceso(Rol_ID, Acceso_Correo, Acceso_ContrasenaHash)
             VALUES (?, ?, ?)'
        );
        $query->execute([
            $roleId,
            $config['admin_email'],
            password_hash($config['admin_password'], PASSWORD_DEFAULT),
        ]);
    }
}
