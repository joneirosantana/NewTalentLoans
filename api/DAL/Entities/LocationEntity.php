<?php
declare(strict_types=1);

final class LocationEntity
{
    public static function createAddress(PDO $db, array $data): int
    {
        $data['Direccion_Provincia'] ??= $data['Provincia_Nombre'] ?? null;
        $data['Direccion_Ciudad'] ??= $data['Ciudad_Nombre'] ?? null;
        foreach (['Direccion_Provincia', 'Direccion_Ciudad', 'Direccion_Calle'] as $field) {
            if (trim((string)($data[$field] ?? '')) === '') throw new InvalidArgumentException("Falta el campo requerido $field.");
        }
        $fields = ['Direccion_Provincia', 'Direccion_Ciudad', 'Direccion_Calle', 'Direccion_Numero', 'Direccion_Sector', 'Direccion_Descripcion'];
        return (new TableEntity('Direccion', $fields, array_intersect_key($data, array_flip($fields))))->insert($db);
    }
}
