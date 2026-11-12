<?php
declare(strict_types=1);

interface EntityInterface
{
    public function table(): string;
    public function primaryKey(): string;
    public function attributes(): array;
    public function getAll(PDO $db): array;
    public function getById(PDO $db, int $id): ?array;
    public function insert(PDO $db): int;
    public function update(PDO $db, int $id): bool;
    public function delete(PDO $db, int $id): bool;
}
