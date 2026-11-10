<?php
declare(strict_types=1);

/* Cuenta administrativa del backend. No se almacena en Rol, Acceso ni Empleado. */
function admin_credentials(): array
{
    return [
        'email' => 'admin@newtalentloans.local',
        'password' => 'Demo1234!',
        'name' => 'Administrador',
    ];
}
