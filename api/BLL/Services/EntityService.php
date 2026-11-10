<?php
final class EntityService
{
    private const MAP = [
        'clientes' => ['Cliente', 'Cliente_ID', ['Cliente_Nombre', 'Cliente_Apellido', 'Cliente_Cedula', 'Cliente_Sueldo']],
        'solicitudes-admin' => ['Solicitud', 'Solicitud_ID', ['Cliente_ID', 'TipoPrestamo_ID', 'MetodoPago_ID', 'Moneda_ID', 'EstadoSolicitud_ID', 'Solicitud_Monto', 'Solicitud_Plazo', 'Solicitud_Motivo', 'TipoPrestamo_Nombre', 'MetodoPago_Nombre', 'Moneda_Codigo', 'TipoPrestamo_TasaBase', 'TipoPrestamo_MontoMinimo', 'TipoPrestamo_MontoMaximo', 'TipoPrestamo_PlazoMinimo', 'TipoPrestamo_PlazoMaximo', 'Moneda_Nombre', 'Moneda_Simbolo', 'Moneda_Activa']],
        'prestamos' => ['Prestamo', 'Prestamo_ID', ['Solicitud_ID', 'TipoPrestamo_ID', 'EstadoPrestamo_ID', 'Prestamo_Monto', 'Prestamo_Tasa', 'Prestamo_Plazo', 'Prestamo_FechaDesembolso', 'Prestamo_Saldo', 'TipoPrestamo_Nombre', 'TipoPrestamo_TasaBase', 'TipoPrestamo_MontoMinimo', 'TipoPrestamo_MontoMaximo', 'TipoPrestamo_PlazoMinimo', 'TipoPrestamo_PlazoMaximo']],
        'cuotas' => ['Cuota', 'Cuota_ID', ['Prestamo_ID', 'Cuota_Numero', 'Cuota_FechaVencimiento', 'Cuota_Capital', 'Cuota_Interes', 'Cuota_Monto', 'Cuota_Saldo', 'Cuota_Estado']],
        'pagos' => ['Pago', 'Pago_ID', ['Prestamo_ID', 'MetodoPago_ID', 'Cliente_ID', 'Cuota_ID', 'Pago_Monto', 'MetodoPago_Nombre']],
        'tipos-prestamo' => ['TipoPrestamo', 'TipoPrestamo_ID', ['TipoPrestamo_Nombre', 'TipoPrestamo_TasaBase']],
        'estados-prestamo' => ['EstadoPrestamo', 'EstadoPrestamo_ID', ['EstadoPrestamo_Nombre']],
        'metodos-pago' => ['MetodoPago', 'MetodoPago_ID', ['MetodoPago_Nombre', 'MetodoPago_Descripcion']],
        'monedas' => ['Moneda', 'Moneda_ID', ['Moneda_Codigo', 'Moneda_Nombre', 'Moneda_Simbolo', 'Moneda_Activa']],
        'tipos-garantia' => ['TipoGarantia', 'TipoGarantia_ID', ['TipoGarantia_Nombre', 'TipoGarantia_Descripcion', 'TipoGarantia_Activa']],
        'garantes' => ['Garante', 'Garante_ID', ['Prestamo_ID', 'Acceso_ID', 'Garante_Nombre', 'Garante_Cedula', 'Garante_Telefono']],
        'garantias' => ['Garantia', 'Garantia_ID', ['Prestamo_ID', 'TipoGarantia_ID', 'TipoGarantia_Nombre', 'TipoGarantia_Descripcion', 'Garantia_Descripcion', 'Garantia_ValorEstimado', 'Garantia_Referencia', 'Garantia_Estado']],
        'desembolsos' => ['Desembolso', 'Desembolso_ID', ['Prestamo_ID', 'MetodoPago_ID', 'Empleado_ID', 'Desembolso_Monto', 'Desembolso_Referencia', 'Desembolso_Estado', 'Desembolso_Observacion']],
        'estados-solicitud' => ['EstadoSolicitud', 'EstadoSolicitud_ID', ['EstadoSolicitud_Nombre']],
    ];

    private const WORKFLOW_ONLY = [
        'solicitudes-admin', 'prestamos', 'cuotas', 'pagos', 'desembolsos',
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
            $entity = self::entityFor($resource, $table, $fields);
            if ($id === null) return ['datos' => $entity->getAll($db)];
            $record = $entity->getById($db, $id);
            return ['datos' => $record === null ? [] : [$record]];
        }
        if (in_array($method, ['POST', 'PUT'], true)) {
            return self::saveRecord($db, $resource, $table, $primaryKey, $fields, $method, $id);
        }
        if ($method === 'DELETE' && $id !== null) {
            return ['eliminado' => self::entityFor($resource, $table, $fields)->delete($db, $id)];
        }

        throw new InvalidArgumentException('Método o ID no permitido.');
    }

    private static function listClients(PDO $db, ?int $id): array
    {
        if (ApiSupport::admin() || ApiSupport::readOnlyCompany()) {
            $query = $db->query('SELECT e.Empresa_ID, e.Empresa_Nombre,
                COUNT(DISTINCT c.Cliente_ID) clientes,
                COALESCE(SUM(c.Cliente_Sueldo),0) sueldo_total,
                COALESCE(SUM(p.Prestamo_Saldo),0) deuda_total
                FROM Empresa e LEFT JOIN Cliente c ON c.Empresa_ID=e.Empresa_ID
                LEFT JOIN Solicitud s ON s.Cliente_ID=c.Cliente_ID
                LEFT JOIN Prestamo p ON p.Solicitud_ID=s.Solicitud_ID
                GROUP BY e.Empresa_ID,e.Empresa_Nombre ORDER BY e.Empresa_Nombre');
            return ['datos' => $query->fetchAll(), 'privacidad' => 'agregada'];
        }
        $sql = 'SELECT c.Cliente_ID, c.Cliente_Nombre, c.Cliente_Apellido,
                       c.Cliente_Cedula, c.Cliente_Sueldo, a.Acceso_Correo,
                       a.Acceso_Activo, d.Direccion_Calle, d.Direccion_Numero,
                       d.Direccion_Sector, ci.Ciudad_Nombre, p.Provincia_Nombre
                FROM Cliente c
                JOIN Acceso a ON a.Acceso_ID = c.Acceso_ID
                JOIN Direccion d ON d.Direccion_ID = c.Direccion_ID
                JOIN Ciudad ci ON ci.Ciudad_ID = d.Ciudad_ID
                JOIN Provincia p ON p.Provincia_ID = ci.Provincia_ID';
        $params = [];
        if ($id !== null) {
            $sql .= ' WHERE c.Cliente_ID = ?';
            $params[] = $id;
        } elseif (ApiSupport::companyId() !== null) {
            $sql .= ' WHERE c.Empresa_ID = ?';
            $params[] = ApiSupport::companyId();
        }

        $query = $db->prepare($sql);
        $query->execute($params);
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

    private static function entityFor(string $resource, string $table, array $fields, array $values = []): EntityInterface
    {
        $catalogResources = ['tipos-prestamo', 'estados-prestamo', 'metodos-pago', 'monedas', 'tipos-garantia', 'estados-solicitud'];
        return in_array($resource, $catalogResources, true)
            ? CatalogEntity::forTable($table, $values)
            : new TableEntity($table, $fields, $values);
    }

    private static function saveRecord(PDO $db, string $resource, string $table, string $primaryKey, array $fields, string $method, ?int $id): array
    {
        $values = array_intersect_key(ApiSupport::input(), array_flip($fields));
        if (!$values) throw new InvalidArgumentException('No hay campos permitidos para guardar.');
        $entity = self::entityFor($resource, $table, $fields, $values);
        if ($method === 'POST') return ['id' => $entity->insert($db)];
        if ($id === null) throw new InvalidArgumentException('Falta un ID válido.');
        return ['actualizado' => $entity->update($db, $id)];
    }
}






