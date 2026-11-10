<?php
declare(strict_types=1);

final class DatabaseConnection
{
    public static function get(): PDO
    {
        static $connection;
        if ($connection instanceof PDO) {
            return $connection;
        }

        $config = require __DIR__ . '/../.config.php';
        if (!preg_match('/^[A-Za-z0-9_]+$/', $config['database'])) {
            throw new RuntimeException('El nombre de la base solo puede contener letras, números y guion bajo.');
        }

        $options = [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ];
        $dsn = 'sqlsrv:Server=' . $config['server'] . ';Database=master;TrustServerCertificate=1';
        $master = new PDO($dsn, $config['username'], $config['password'], $options);

        $query = $master->prepare('SELECT DB_ID(?)');
        $query->execute([$config['database']]);
        $databaseId = $query->fetchColumn();
        $isNewDatabase = $databaseId === false || $databaseId === null;

        if ($isNewDatabase) {
            $master->exec('CREATE DATABASE [' . $config['database'] . ']');
        }

        $dsn = 'sqlsrv:Server=' . $config['server'] . ';Database=' . $config['database'] . ';TrustServerCertificate=1';
        $connection = new PDO($dsn, $config['username'], $config['password'], $options);

        $schemaExists = (bool)$connection->query("SELECT OBJECT_ID('Rol', 'U')")->fetchColumn();
        if ($isNewDatabase || !$schemaExists) {
            self::installDatabase($connection);
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
            __DIR__ . '/../database/03_creacion_base_datos.sql',
            __DIR__ . '/../database/02_triggers.sql',
            __DIR__ . '/../database/01_stored_procedures.sql',
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
            foreach (['Cliente', 'RRHH', 'Contable', 'Solicitudes', 'Gerente', 'Pendiente', 'Dueño'] as $role) {
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

            $config = require __DIR__ . '/../.config.php';
            $clientRole = (int)$db->query("SELECT Rol_ID FROM Rol WHERE Rol_Nombre = N'Cliente'")->fetchColumn();
            $cityId = self::demoCity($db);

            self::seedPerson(
                $db, $config['demo_client_email'], $config['demo_client_password'],
                $clientRole, 'Ana', 'Prueba', '000-0000000-1', $cityId, true
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
        return (int)$db->query('SELECT TOP 1 Ciudad_ID FROM Ciudad ORDER BY Ciudad_ID DESC')->fetchColumn();
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
        bool $isClient,
        bool $active = true
    ): void {
        $query = $db->prepare('SELECT Acceso_ID FROM Acceso WHERE Acceso_Correo = ?');
        $query->execute([$email]);
        if ($query->fetchColumn()) {
            return;
        }

        $query = $db->prepare(
            'INSERT INTO Acceso(Rol_ID, Acceso_Correo, Acceso_ContrasenaHash, Acceso_Activo)
             VALUES (?, ?, ?, ?)'
        );
        $query->execute([$roleId, $email, password_hash($password, PASSWORD_DEFAULT), $active ? 1 : 0]);
        $accessId = (int)$db->query('SELECT TOP 1 Acceso_ID FROM Acceso ORDER BY Acceso_ID DESC')->fetchColumn();

        $query = $db->prepare('INSERT INTO Direccion(Ciudad_ID, Direccion_Calle) VALUES (?, ?)');
        $query->execute([$cityId, 'Calle de Prueba']);
        $addressId = (int)$db->query('SELECT TOP 1 Direccion_ID FROM Direccion ORDER BY Direccion_ID DESC')->fetchColumn();

        if ($isClient) {
            self::insertDemoClient($db, $addressId, $accessId, $firstName, $lastName, $identityNumber, $email);
            return;
        }

        $departmentId = (int)$db->query("SELECT TOP 1 Departamento_ID FROM Departamento ORDER BY Departamento_ID")->fetchColumn();
        $query = $db->prepare(
            "INSERT INTO Empleado(Direccion_ID, Acceso_ID, Departamento_ID, Empleado_Nombre, Empleado_Apellido,
                                  Empleado_Cedula, Empleado_Cargo, Empleado_Estado)
             VALUES (?, ?, ?, ?, ?, ?, ?, N'Pendiente')"
        );
        $query->execute([$addressId, $accessId, $departmentId, $firstName, $lastName, $identityNumber, 'Encargado de personal']);
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
        $clientId = (int)$db->query('SELECT TOP 1 Cliente_ID FROM Cliente ORDER BY Cliente_ID DESC')->fetchColumn();

        $query = $db->prepare('INSERT INTO Telefono(Cliente_ID, Telefono_Numero) VALUES (?, ?)');
        $query->execute([$clientId, '8090000001']);
        $query = $db->prepare('INSERT INTO Correo(Cliente_ID, Correo_Direccion) VALUES (?, ?)');
        $query->execute([$clientId, $email]);
    }

}



