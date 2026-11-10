<?php
declare(strict_types=1);

final class DatabaseManager
{
    public static function getAll(PDO $db, string $table): array
    {
        self::identifier($table);
        return $db->query("SELECT * FROM [$table]")->fetchAll();
    }

    public static function getById(PDO $db, string $table, string $primaryKey, int $id): ?array
    {
        self::identifier($table); self::identifier($primaryKey);
        $q = $db->prepare("SELECT * FROM [$table] WHERE [$primaryKey] = ?");
        $q->execute([$id]);
        return $q->fetch() ?: null;
    }

    public static function insert(PDO $db, string $table, array $data, array $allowed): int
    {
        self::identifier($table);
        $data = array_intersect_key($data, array_flip($allowed));
        if (!$data) throw new InvalidArgumentException('No hay campos permitidos para guardar.');
        foreach (array_keys($data) as $column) self::identifier($column);
        $columns = array_keys($data);
        $names = implode(',', array_map(static fn($c) => "[$c]", $columns));
        $marks = implode(',', array_fill(0, count($columns), '?'));
        $primaryKey = $table . '_ID';
        self::identifier($primaryKey);
        $q = $db->prepare("INSERT INTO [$table] ($names) OUTPUT INSERTED.[$primaryKey] VALUES ($marks)");
        $q->execute(array_values($data));
        $id = $q->fetchColumn();
        if ($id === false) throw new RuntimeException('No se pudo recuperar el registro insertado.');
        return (int)$id;
    }

    public static function update(PDO $db, string $table, string $primaryKey, array $data, array $allowed, int $id): bool
    {
        self::identifier($table); self::identifier($primaryKey);
        $data = array_intersect_key($data, array_flip($allowed));
        if (!$data) throw new InvalidArgumentException('No hay campos permitidos para actualizar.');
        foreach (array_keys($data) as $column) self::identifier($column);
        $set = implode(',', array_map(static fn($c) => "[$c] = ?", array_keys($data)));
        $q = $db->prepare("UPDATE [$table] SET $set WHERE [$primaryKey] = ?");
        $q->execute([...array_values($data), $id]);
        return $q->rowCount() > 0;
    }

    public static function delete(PDO $db, string $table, string $primaryKey, int $id): bool
    {
        self::identifier($table); self::identifier($primaryKey);
        $q = $db->prepare("DELETE FROM [$table] WHERE [$primaryKey] = ?");
        $q->execute([$id]);
        return $q->rowCount() > 0;
    }

    private static function identifier(string $name): void
    {
        if (!preg_match('/^[A-Za-z][A-Za-z0-9_]*$/', $name)) throw new InvalidArgumentException('Identificador SQL no permitido.');
    }
}

