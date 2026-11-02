<?php
final class EntityController
{
    private const MAP = [
        'clientes' => ['Cliente', 'Cliente_ID', ['Cliente_Nombre', 'Cliente_Apellido', 'Cliente_Cedula', 'Cliente_Sueldo']],
        'solicitudes-admin' => ['Solicitud', 'Solicitud_ID', ['Cliente_ID', 'TipoPrestamo_ID', 'MetodoPago_ID', 'Moneda_ID', 'EstadoSolicitud_ID', 'Solicitud_Monto', 'Solicitud_Plazo', 'Solicitud_Motivo']],
        'prestamos' => ['Prestamo', 'Prestamo_ID', ['Solicitud_ID', 'TipoPrestamo_ID', 'EstadoPrestamo_ID', 'Prestamo_Monto', 'Prestamo_Tasa', 'Prestamo_Plazo', 'Prestamo_FechaDesembolso', 'Prestamo_Saldo']],
        'cuotas' => ['Cuota', 'Cuota_ID', ['Prestamo_ID', 'Cuota_Numero', 'Cuota_FechaVencimiento', 'Cuota_Capital', 'Cuota_Interes', 'Cuota_Monto', 'Cuota_Saldo', 'Cuota_Estado']],
        'pagos' => ['Pago', 'Pago_ID', ['Prestamo_ID', 'MetodoPago_ID', 'Cliente_ID', 'Cuota_ID', 'Pago_Monto']],
        'tipos-prestamo' => ['TipoPrestamo', 'TipoPrestamo_ID', ['TipoPrestamo_Nombre', 'TipoPrestamo_TasaBase']],
        'estados-prestamo' => ['EstadoPrestamo', 'EstadoPrestamo_ID', ['EstadoPrestamo_Nombre']],
        'metodos-pago' => ['MetodoPago', 'MetodoPago_ID', ['MetodoPago_Nombre', 'MetodoPago_Descripcion']],
        'monedas' => ['Moneda', 'Moneda_ID', ['Moneda_Codigo', 'Moneda_Nombre', 'Moneda_Simbolo', 'Moneda_Activa']],
        'tipos-garantia' => ['TipoGarantia', 'TipoGarantia_ID', ['TipoGarantia_Nombre', 'TipoGarantia_Descripcion', 'TipoGarantia_Activa']],
        'tipos-factura' => ['TipoFactura', 'TipoFactura_ID', ['TipoFactura_Nombre', 'TipoFactura_Descripcion']],
        'garantes' => ['Garante', 'Garante_ID', ['Prestamo_ID', 'Acceso_ID', 'Garante_Nombre', 'Garante_Cedula', 'Garante_Telefono']],
        'garantias' => ['Garantia', 'Garantia_ID', ['Prestamo_ID', 'TipoGarantia_ID', 'Garantia_Descripcion', 'Garantia_ValorEstimado', 'Garantia_Referencia', 'Garantia_Estado']],
        'desembolsos' => ['Desembolso', 'Desembolso_ID', ['Prestamo_ID', 'MetodoPago_ID', 'Empleado_ID', 'Desembolso_Monto', 'Desembolso_Referencia', 'Desembolso_Estado', 'Desembolso_Observacion']],
        'facturas' => ['Factura', 'Factura_ID', ['TipoFactura_ID', 'MetodoPago_ID', 'Factura_Monto', 'Factura_Descripcion', 'Factura_Estado']],
        'estados-solicitud' => ['EstadoSolicitud', 'EstadoSolicitud_ID', ['EstadoSolicitud_Nombre']],
    ];

    private const WORKFLOW_ONLY = [
        'solicitudes-admin', 'prestamos', 'cuotas', 'pagos', 'desembolsos', 'facturas',
    ];

    public static function run(PDO $db, string $resource, string $method, ?int $id): array
    {
        if (!isset(self::MAP[$resource])) {
            throw new InvalidArgumentException('Recurso no implementado.');
        }

        if (in_array($resource, self::WORKFLOW_ONLY, true) && $method !== 'GET') {
            throw new InvalidArgumentException('Use el procedimiento del flujo para modificar esta entidad.');
        }

        [$table, $primaryKey, $fields] = self::MAP[$resource];

        if ($resource === 'clientes' && $method === 'GET') {
            return self::listClients($db, $id);
        }
        if ($resource === 'clientes' && $method === 'DELETE' && $id !== null) {
            return self::deactivateClient($db, $id);
        }
        if ($method === 'GET') {
            return self::listRecords($db, $table, $primaryKey, $id);
        }
        if (in_array($method, ['POST', 'PUT'], true)) {
            return self::saveRecord($db, $table, $primaryKey, $fields, $method, $id);
        }
        if ($method === 'DELETE' && $id !== null) {
            return self::deleteRecord($db, $table, $primaryKey, $id);
        }

        throw new InvalidArgumentException('Método o ID no permitido.');
    }

    private static function listClients(PDO $db, ?int $id): array
    {
        $sql = 'SELECT c.Cliente_ID, c.Cliente_Nombre, c.Cliente_Apellido,
                       c.Cliente_Cedula, c.Cliente_Sueldo, a.Acceso_Correo,
                       a.Acceso_Activo, d.Direccion_Calle, d.Direccion_Numero,
                       d.Direccion_Sector, ci.Ciudad_Nombre, p.Provincia_Nombre
                FROM Cliente c
                JOIN Acceso a ON a.Acceso_ID = c.Acceso_ID
                JOIN Direccion d ON d.Direccion_ID = c.Direccion_ID
                JOIN Ciudad ci ON ci.Ciudad_ID = d.Ciudad_ID
                JOIN Provincia p ON p.Provincia_ID = ci.Provincia_ID';
        if ($id !== null) {
            $sql .= ' WHERE c.Cliente_ID = ?';
        }

        $query = $db->prepare($sql);
        $query->execute($id === null ? [] : [$id]);
        return ['datos' => $query->fetchAll()];
    }

    private static function deactivateClient(PDO $db, int $id): array
    {
        $query = $db->prepare(
            'UPDATE Acceso SET Acceso_Activo = 0
             WHERE Acceso_ID = (SELECT Acceso_ID FROM Cliente WHERE Cliente_ID = ?)'
        );
        $query->execute([$id]);
        return ['eliminado' => $query->rowCount() > 0];
    }

    private static function listRecords(PDO $db, string $table, string $primaryKey, ?int $id): array
    {
        $sql = "SELECT * FROM [$table]" . ($id === null ? '' : " WHERE [$primaryKey] = ?");
        $query = $db->prepare($sql);
        $query->execute($id === null ? [] : [$id]);
        return ['datos' => $query->fetchAll()];
    }

    private static function saveRecord(PDO $db, string $table, string $primaryKey, array $fields, string $method, ?int $id): array
    {
        $data = array_intersect_key(Lib::input(), array_flip($fields));
        if (!$data) {
            throw new InvalidArgumentException('No hay campos permitidos para guardar.');
        }

        $columns = array_keys($data);
        if ($method === 'POST') {
            $names = implode(',', array_map(static fn($column) => "[$column]", $columns));
            $placeholders = implode(',', array_fill(0, count($columns), '?'));
            $query = $db->prepare("INSERT INTO [$table] ($names) VALUES ($placeholders)");
            $query->execute(array_values($data));
            return ['id' => (int)$db->query('SELECT SCOPE_IDENTITY()')->fetchColumn()];
        }

        if ($id === null) {
            throw new InvalidArgumentException('Falta un ID válido.');
        }
        $assignments = implode(',', array_map(static fn($column) => "[$column] = ?", $columns));
        $query = $db->prepare("UPDATE [$table] SET $assignments WHERE [$primaryKey] = ?");
        $query->execute([...array_values($data), $id]);
        return ['actualizado' => $query->rowCount() > 0];
    }

    private static function deleteRecord(PDO $db, string $table, string $primaryKey, int $id): array
    {
        $query = $db->prepare("DELETE FROM [$table] WHERE [$primaryKey] = ?");
        $query->execute([$id]);
        return ['eliminado' => $query->rowCount() > 0];
    }
}
