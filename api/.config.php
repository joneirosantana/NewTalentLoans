<?php
// Credenciales locales de prueba. En producción use variables de entorno y cambie estas claves.
return [
    'server' => getenv('NTL_DB_SERVER') ?: 'localhost',
    'database' => getenv('NTL_DB_NAME') ?: 'NewTalentLoans',
    'username' => getenv('NTL_DB_USER') ?: '',
    'password' => getenv('NTL_DB_PASSWORD') ?: '',
    'admin_email' => getenv('NTL_ADMIN_EMAIL') ?: 'admin@newtalentloans.local',
    'admin_password' => getenv('NTL_ADMIN_PASSWORD') ?: 'Demo1234!',
    'demo_client_email' => getenv('NTL_DEMO_CLIENT_EMAIL') ?: 'cliente@newtalentloans.local',
    'demo_client_password' => getenv('NTL_DEMO_CLIENT_PASSWORD') ?: 'Cliente123!',
    'demo_employee_email' => getenv('NTL_DEMO_EMPLOYEE_EMAIL') ?: 'empleado@newtalentloans.local',
    'demo_employee_password' => getenv('NTL_DEMO_EMPLOYEE_PASSWORD') ?: 'Empleado123!',
];
