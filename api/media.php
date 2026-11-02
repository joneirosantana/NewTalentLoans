<?php
declare(strict_types=1);

$assets = [
    'icon' => __DIR__ . '/media/icon.png',
    'logo' => __DIR__ . '/media/logo.png',
];
$name = (string)($_GET['asset'] ?? '');
if (!isset($assets[$name]) || !is_file($assets[$name])) {
    http_response_code(404);
    exit;
}
header('Content-Type: image/png');
header('Cache-Control: public, max-age=86400');
header('X-Content-Type-Options: nosniff');
readfile($assets[$name]);
