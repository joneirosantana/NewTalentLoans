<?php
declare(strict_types=1);

final class TableEntity implements EntityInterface
{
    private string $tableName;
    private string $keyName;
    private array $allowedFields;
    private array $values;

    public function __construct(string $table, array $allowedFields, array $values = [])
    {
        if (!preg_match('/^[A-Za-z][A-Za-z0-9_]*$/', $table)) throw new InvalidArgumentException('Tabla no permitida.');
        foreach ($allowedFields as $field) if (!preg_match('/^[A-Za-z][A-Za-z0-9_]*$/', $field)) throw new InvalidArgumentException('Campo no permitido.');
        $this->tableName = $table;
        $this->keyName = $table . '_ID';
        $this->allowedFields = array_values(array_diff($allowedFields, [$this->keyName]));
        $dependencyInputs = ["TipoPrestamo_Nombre", "MetodoPago_Nombre", "Moneda_Codigo", "Moneda_Nombre", "Moneda_Simbolo", "Moneda_Activa", "TipoPrestamo_TasaBase", "TipoPrestamo_MontoMinimo", "TipoPrestamo_MontoMaximo", "TipoPrestamo_PlazoMinimo", "TipoPrestamo_PlazoMaximo", "TipoGarantia_Nombre", "TipoGarantia_Descripcion", "TipoGarantia_Activa"];
        $this->values = array_intersect_key($values, array_flip([...$this->allowedFields, ...$dependencyInputs]));
    }

    public function table(): string { return $this->tableName; }
    public function primaryKey(): string { return $this->keyName; }
    public function attributes(): array { return $this->values; }
    public function getAll(PDO $db): array { return DatabaseManager::getAll($db, $this->tableName); }
    public function getById(PDO $db, int $id): ?array { return DatabaseManager::getById($db, $this->tableName, $this->keyName, $id); }
    public function insert(PDO $db): int
    {
        $ownsTransaction = !$db->inTransaction();
        if ($ownsTransaction) $db->beginTransaction();
        try {
            $values = $this->values;
            $dependencies = [
                'Solicitud' => ['TipoPrestamo_Nombre' => 'TipoPrestamo', 'MetodoPago_Nombre' => 'MetodoPago', 'Moneda_Codigo' => 'Moneda'],
                'Prestamo' => ['TipoPrestamo_Nombre' => 'TipoPrestamo'],
                'Pago' => ['MetodoPago_Nombre' => 'MetodoPago'],
                'Desembolso' => ['MetodoPago_Nombre' => 'MetodoPago'],
                'Garantia' => ['TipoGarantia_Nombre' => 'TipoGarantia'],
            ];
            foreach ($dependencies[$this->tableName] ?? [] as $inputField => $catalog) {
                if (!array_key_exists($inputField, $values)) continue;
                $naturalKey = $catalog === 'Moneda' ? 'Moneda_Codigo' : $catalog . '_Nombre';
                $catalogValues = array_filter($values, static fn($key) => str_starts_with((string)$key, $catalog . '_'), ARRAY_FILTER_USE_KEY);
                $catalogValues[$naturalKey] = $values[$inputField];
                $values[$catalog . '_ID'] = CatalogEntity::getOrCreate($db, $catalog, $catalogValues);
                unset($values[$inputField]);
            }
            $direct = array_intersect_key($values, array_flip($this->allowedFields));
            $id = DatabaseManager::insert($db, $this->tableName, $direct, $this->allowedFields);
            if ($ownsTransaction) $db->commit();
            return $id;
        } catch (Throwable $error) {
            if ($ownsTransaction && $db->inTransaction()) $db->rollBack();
            throw $error;
        }
    }
    public function update(PDO $db, int $id): bool { return DatabaseManager::update($db, $this->tableName, $this->keyName, $this->values, $this->allowedFields, $id); }
    public function delete(PDO $db, int $id): bool { return DatabaseManager::delete($db, $this->tableName, $this->keyName, $id); }
}




