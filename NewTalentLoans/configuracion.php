<?php
require_once __DIR__ . '/php/auth.php';
protegerPaginaAdministrativa();
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Configuración | New Talent Loans</title>
    <link rel="icon" type="image/x-icon" href="Imagenes/NewTalentLoans.png">
    
    <!-- Fuente Montserrat -->
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;500;700&display=swap" rel="stylesheet">
    
    <!-- Ionicons -->
    <script type="module" src="https://unpkg.com/ionicons@7.1.0/dist/ionicons/ionicons.esm.js"></script>
    <script nomodule src="https://unpkg.com/ionicons@7.1.0/dist/ionicons/ionicons.js"></script>

    <link rel="stylesheet" href="estilos/configuracion.css">
    <script src="scripts/configuracion.js" defer></script>
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
        
        <!-- MENÚ LATERAL -->
        <aside class="sidebar" id="sidebar">
            <nav class="sidebar-nav">
                <ul>
                    <li><a href="panel-servicios.php"><ion-icon name="home-outline"></ion-icon><span>Inicio</span></a></li>
                    <li><a href="panel-principal.php"><ion-icon name="desktop-outline"></ion-icon><span>Panel Principal</span></a></li>
                    <li><a href="clientes.php"><ion-icon name="people-outline"></ion-icon><span>Cliente</span></a></li>
                    <li><a href="solicitudes.php"><ion-icon name="document-text-outline"></ion-icon><span>Solicitudes</span></a></li>
                    <li><a href="prestamos.php"><ion-icon name="cash-outline"></ion-icon><span>Prestamos</span></a></li>
                    <li><a href="pagos.php"><ion-icon name="card-outline"></ion-icon><span>Pagos</span></a></li>
                    <li><a href="reportes.php"><ion-icon name="bar-chart-outline"></ion-icon><span>Reportes</span></a></li>
                    <li class="active"><a href="configuracion.php"><ion-icon name="settings-outline"></ion-icon><span>Configuración</span></a></li>
                </ul>
            </nav>

            <div class="sidebar-footer">
                <p class="logged-user">Nombre del que esta logueado</p>
                <a href="#" class="logout-link">Cerrar Sesión</a>
            </div>
        </aside>

        <!-- ÁREA DE CONTENIDO PRINCIPAL -->
        <main class="main-content">
            
            <h2 class="page-title">Configuración</h2>
            <hr class="title-divider">

            <!-- Caja de Configuración del Sistema -->
            <div class="configuracion-box">
                
                <h3 class="configuracion-titulo">Configuración del Sistema</h3>

                <form id="formConfiguracion" class="form-configuracion">
                    
                    <!-- Tasa de Interés -->
                    <div class="form-group">
                        <label for="tasaInteres">Tasa de Interés Global por Defecto (%)</label>
                        <input type="number" id="tasaInteres" name="tasaInteres" 
                               min="0" max="100" step="0.01" required>
                    </div>

                    <!-- Moneda del Sistema -->
                    <div class="form-group">
                        <label for="moneda">Moneda del Sistema</label>
                        <select id="moneda" name="moneda" required>
                            <option value="">Seleccione una moneda</option>
                            <option value="COP">Peso Colombiano (COP)</option>
                            <option value="USD">Dólar Estadounidense (USD)</option>
                            <option value="EUR">Euro (EUR)</option>
                            <option value="MXN">Peso Mexicano (MXN)</option>
                            <option value="ARS">Peso Argentino (ARS)</option>
                            <option value="DOP">Peso Dominicano (DOP)</option>
                            <option value="VES">Bolívar Venezolano (VES)</option>
                            <option value="PEN">Sol Peruano (PEN)</option>
                        </select>
                    </div>

                    <!-- Botón Guardar -->
                    <button type="submit" class="btn-guardar-cambios" id="btnGuardarCambios">
                        Guardar Cambios
                    </button>

                </form>
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

    <!-- MODAL DE MENSAJES -->
    <div class="modal-overlay modal-mensajes" id="modalOverlay">
        <div class="modal-box">
            <h3 class="modal-title" id="modalTitle">Título</h3>
            <p class="modal-message" id="modalMessage">Mensaje</p>
            <button class="modal-btn" id="modalBtn">Aceptar</button>
        </div>
    </div>

</body>
</html>