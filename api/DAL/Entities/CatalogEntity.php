<?php
declare(strict_types=1);

final class CatalogEntity
{
    private const CATALOGS = [
        'TipoPrestamo' => ['TipoPrestamo_ID', ['TipoPrestamo_Nombre', 'TipoPrestamo_TasaBase', 'TipoPrestamo_MontoMinimo', 'TipoPrestamo_MontoMaximo', 'TipoPrestamo_PlazoMinimo', 'TipoPrestamo_PlazoMaximo'], ['TipoPrestamo_Nombre']],
        'EstadoPrestamo' => ['EstadoPrestamo_ID', ['EstadoPrestamo_Nombre'], ['EstadoPrestamo_Nombre']],
        'MetodoPago' => ['MetodoPago_ID', ['MetodoPago_Nombre', 'MetodoPago_Descripcion'], ['MetodoPago_Nombre']],
        'Moneda' => ['Moneda_ID', ['Moneda_Codigo', 'Moneda_Nombre', 'Moneda_Simbolo', 'Moneda_Activa'], ['Moneda_Codigo']],
        'EstadoSolicitud' => ['EstadoSolicitud_ID', ['EstadoSolicitud_Nombre'], ['EstadoSolicitud_Nombre']],
        'TipoGarantia' => ['TipoGarantia_ID', ['TipoGarantia_Nombre', 'TipoGarantia_Descripcion', 'TipoGarantia_Activa'], ['TipoGarantia_Nombre']],
        'Rol' => ['Rol_ID', ['Rol_Nombre'], ['Rol_Nombre']],
    ];

    public static function forTable(string $table, array $values = []): TableEntity
    {
        if (!isset(self::CATALOGS[$table])) throw new InvalidArgumentException('Catálogo no permitido.');
        return new TableEntity($table, self::CATALOGS[$table][1], $values);
    }

    public static function getOrCreate(PDO $db, string $table, array $values): int
    {
        if (!isset(self::CATALOGS[$table])) throw new InvalidArgumentException('Catálogo no permitido.');
        [$primaryKey, $fields, $naturalKeys] = self::CATALOGS[$table];
        $values = array_intersect_key($values, array_flip($fields));
        foreach ($naturalKeys as $key) if (!array_key_exists($key, $values) || $values[$key] === '') throw new InvalidArgumentException("Falta el campo requerido $key.");
        $where = implode(' AND ', array_map(static fn($key) => "[$key] = ?", $naturalKeys));
        $query = $db->prepare("SELECT [$primaryKey] FROM [$table] WHERE $where");
        $query->execute(array_map(static fn($key) => $values[$key], $naturalKeys));
        $existing = $query->fetchColumn();
        if ($existing !== false) return (int)$existing;
        return self::forTable($table, $values)->insert($db);
    }
}
