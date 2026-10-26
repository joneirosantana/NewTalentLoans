<?php
require_once __DIR__ . '/php/auth.php';
protegerPaginaAdministrativa();
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Panel Principal - New Talent Loans</title>
    <link rel="icon" type="image/x-icon" href="Imagenes/NewTalentLoans.png">
    <!-- Fuente Montserrat -->
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;500;700&display=swap" rel="stylesheet">
    
    <!-- Ionicons -->
    <script type="module" src="https://unpkg.com/ionicons@7.1.0/dist/ionicons/ionicons.esm.js"></script>
    <script nomodule src="https://unpkg.com/ionicons@7.1.0/dist/ionicons/ionicons.js"></script>

    <link rel="stylesheet" href="estilos/stylesPanel.css">
    <script src="scripts/scriptPanel.js" defer></script>
</head>
<body>

    <!-- ENCABEZADO SUPERIOR -->
    <header class="top-header">
        <div class="header-left">
            <button class="menu-toggle">
                <ion-icon name="menu-outline"></ion-icon>
            </button>
            <div class="logo-container">
                <div class="logo-white-bg">
                    <img src="Imagenes/NewTalentLoans.png" alt="Logo" class="logo-img">
                </div>
            </div>
        </div>
        
        <div class="user-info">
            <div class="user-avatar"></div>
            <span class="user-name">Administrador</span>
        </div>
    </header>

    <!-- CONTENEDOR PRINCIPAL -->
    <div class="app-container">
        
        <!-- MENÚ LATERAL (Sidebar) -->
        <aside class="sidebar" id="sidebar">
            <nav class="sidebar-nav">
                <ul>
                    <li><a href="panel-servicios.php"><ion-icon name="home-outline"></ion-icon><span>Inicio</span></a></li>
                    <li class="active"><a href="panel-principal.php"><ion-icon name="desktop-outline"></ion-icon><span>Panel Principal</span></a></li>
                    <li><a href="clientes.php"><ion-icon name="people-outline"></ion-icon><span>Cliente</span></a></li>
                    <li><a href="solicitudes.php"><ion-icon name="document-text-outline"></ion-icon><span>Solicitudes</span></a></li>
                    <li><a href="prestamos.php"><ion-icon name="cash-outline"></ion-icon><span>Prestamos</span></a></li>
                    <li><a href="pagos.php"><ion-icon name="card-outline"></ion-icon><span>Pagos</span></a></li>
                    <li><a href="reportes.php"><ion-icon name="bar-chart-outline"></ion-icon><span>Reportes</span></a></li>
                    <li><a href="configuracion.php"><ion-icon name="settings-outline"></ion-icon><span>Configuración</span></a></li>
                </ul>
            <a href="gestion-creditos.php">Gestión de créditos</a></nav>

            <div class="sidebar-footer">
                <p class="logged-user">Nombre del que esta logueado</p>
                <a href="#" class="logout-link">Cerrar Sesión</a>
            </div>
        </aside>

        <!-- ÁREA DE CONTENIDO PRINCIPAL (DASHBOARD) -->
        <main class="main-content">
            
            <h2 class="page-title">Panel Principal</h2>
            <hr class="title-divider">

            <!-- Tarjetas de Resumen -->
            <div class="dashboard-cards">
                <!-- Tarjeta 1 -->
                <div class="card" id="card-capital" data-tipo="capital">
                    <h3 class="card-value">$0.00</h3>
                    <p class="card-label">Capital Prestado</p>
                </div>
                <!-- Tarjeta 2 -->
                <div class="card" id="card-pagos" data-tipo="pagos">
                    <h3 class="card-value">$0.00</h3>
                    <p class="card-label">Pagos Recibidos (Mes)</p>
                </div>
                <!-- Tarjeta 3 -->
                <div class="card" id="card-prestamos" data-tipo="prestamos">
                    <h3 class="card-value">0</h3>
                    <p class="card-label">Préstamos Activos</p>
                </div>
                <!-- Tarjeta 4 -->
                <div class="card" id="card-atrasados" data-tipo="atrasados">
                    <h3 class="card-value">0</h3>
                    <p class="card-label">Pagos Atrasados</p>
                </div>
            </div>

            <!-- Sección de Tabla -->
            <div class="table-section">
                <h3 class="table-title">Últimos Préstamos Registrados</h3>
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Cliente</th>
                            <th>Monto</th>
                            <th>Estado</th>
                            <th>Fecha</th>
                        </tr>
                    </thead>
                    <tbody>
                        <!-- Filas vacías como en la imagen -->
                        <tr><td></td><td></td><td></td><td></td><td></td></tr>
                        <tr><td></td><td></td><td></td><td></td><td></td></tr>
                        <tr><td></td><td></td><td></td><td></td><td></td></tr>
                    </tbody>
                </table>
            </div>

        </main>

    </div>

    <!-- PIE DE PÁGINA -->
    <footer class="bottom-footer">
        <div class="footer-content">
            <span>Todos los Derechos Reservados</span>
            <span class="divider">|</span>
            <span>New Talent Loans</span>
            <span class="divider">|</span>
            <ion-icon name="information-circle-outline"></ion-icon>
            <span>Version 1.0.1</span>
        </div>
    </footer>

    <!-- MODAL PERSONALIZADO -->
    <div class="modal-overlay" id="modalOverlay">
        <div class="modal-box">
            <h3 class="modal-title" id="modalTitle">Título del Modal</h3>
            <p class="modal-message" id="modalMessage">Mensaje del modal.</p>
            <button class="modal-btn" id="modalBtn">Aceptar</button>
        </div>
    </div>
</body>
</html>