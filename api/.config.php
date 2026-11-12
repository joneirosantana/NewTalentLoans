<?php
// Credenciales locales de prueba. En producción use variables de entorno y cambie estas claves.
return [
    'server' => getenv('NTL_DB_SERVER') ?: 'HENRY\\SQLEXPRESS',
    'database' => getenv('NTL_DB_NAME') ?: 'NewTalentLoans',
    'username' => getenv('NTL_DB_USER') ?: '',
    'password' => getenv('NTL_DB_PASSWORD') ?: '',
    'demo_client_email' => getenv('NTL_DEMO_CLIENT_EMAIL') ?: 'cliente@newtalentloans.local',
    'demo_client_password' => getenv('NTL_DEMO_CLIENT_PASSWORD') ?: 'Cliente123!',
    'demo_employee_email' => getenv('NTL_DEMO_EMPLOYEE_EMAIL') ?: 'eleccionempleado@newtalentloans.com',
    'demo_employee_password' => getenv('NTL_DEMO_EMPLOYEE_PASSWORD') ?: 'Empleado123!',
];
