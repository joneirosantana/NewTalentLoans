<?php
declare(strict_types=1);

final class LocationEntity
{
    public static function createAddress(PDO $db, array $data): int
    {
        foreach (['Provincia_Nombre', 'Ciudad_Nombre', 'Direccion_Calle'] as $field) {
            if (trim((string)($data[$field] ?? '')) === '') throw new InvalidArgumentException("Falta el campo requerido $field.");
        }
        $ownsTransaction = !$db->inTransaction();
        if ($ownsTransaction) $db->beginTransaction();
        try {
            $provinceName = trim((string)$data['Provincia_Nombre']);
            $cityName = trim((string)$data['Ciudad_Nombre']);
            $provinceId = self::findId($db, 'Provincia', 'Provincia_ID', ['Provincia_Nombre' => $provinceName]);
            if ($provinceId === null) $provinceId = (new TableEntity('Provincia', ['Provincia_Nombre'], ['Provincia_Nombre' => $provinceName]))->insert($db);
            $cityId = self::findId($db, 'Ciudad', 'Ciudad_ID', ['Provincia_ID' => $provinceId, 'Ciudad_Nombre' => $cityName]);
            if ($cityId === null) $cityId = (new TableEntity('Ciudad', ['Provincia_ID', 'Ciudad_Nombre'], ['Provincia_ID' => $provinceId, 'Ciudad_Nombre' => $cityName]))->insert($db);
            $fields = ['Ciudad_ID', 'Direccion_Calle', 'Direccion_Numero', 'Direccion_Sector', 'Direccion_Descripcion'];
            $values = array_intersect_key($data, array_flip($fields));
            $values['Ciudad_ID'] = $cityId;
            $id = (new TableEntity('Direccion', $fields, $values))->insert($db);
            if ($ownsTransaction) $db->commit();
            return $id;
        } catch (Throwable $error) {
            if ($ownsTransaction && $db->inTransaction()) $db->rollBack();
            throw $error;
        }
    }

    private static function findId(PDO $db, string $table, string $primaryKey, array $keys): ?int
    {
        $where = implode(' AND ', array_map(static fn($key) => "[$key] = ?", array_keys($keys)));
        $query = $db->prepare("SELECT [$primaryKey] FROM [$table] WHERE $where");
        $query->execute(array_values($keys));
        $id = $query->fetchColumn();
        return $id === false ? null : (int)$id;
    }
}
