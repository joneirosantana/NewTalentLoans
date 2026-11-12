<?php
declare(strict_types=1);

abstract class BaseEntity implements EntityInterface
{
    protected const TABLE = '';
    protected const PRIMARY_KEY = '';
    protected const FIELDS = [];

    public function __construct(array $values = [])
    {
        foreach ($values as $key => $value) if (property_exists($this, (string)$key)) $this->{$key} = $value;
    }
    public function table(): string { return static::TABLE; }
    public function primaryKey(): string { return static::PRIMARY_KEY; }
    public function attributes(): array
    {
        $result = [];
        foreach (static::FIELDS as $field) if ($field !== static::PRIMARY_KEY && $this->{$field} !== null) $result[$field] = $this->{$field};
        return $result;
    }
    public function getAll(PDO $db): array { return DatabaseManager::getAll($db, static::TABLE); }
    public function getById(PDO $db, int $id): ?array { return DatabaseManager::getById($db, static::TABLE, static::PRIMARY_KEY, $id); }
    public function insert(PDO $db): int { return DatabaseManager::insert($db, static::TABLE, $this->attributes(), static::FIELDS); }
    public function update(PDO $db, int $id): bool { return DatabaseManager::update($db, static::TABLE, static::PRIMARY_KEY, $this->attributes(), array_values(array_diff(static::FIELDS, [static::PRIMARY_KEY])), $id); }
    public function delete(PDO $db, int $id): bool { return DatabaseManager::delete($db, static::TABLE, static::PRIMARY_KEY, $id); }
}

