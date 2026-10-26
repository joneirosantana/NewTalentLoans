<?php
require_once __DIR__ . '/php/auth.php';
protegerPaginaAdministrativa();
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cliente | New Talent Loans</title>
    <link rel="icon" type="image/x-icon" href="Imagenes/NewTalentLoans.png">
    
    <!-- Fuente Montserrat -->
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;500;700&display=swap" rel="stylesheet">
    
    <!-- Ionicons -->
    <script type="module" src="https://unpkg.com/ionicons@7.1.0/dist/ionicons/ionicons.esm.js"></script>
    <script nomodule src="https://unpkg.com/ionicons@7.1.0/dist/ionicons/ionicons.js"></script>

    <!-- CSS EXCLUSIVO DE ESTA PÁGINA -->
    <link rel="stylesheet" href="estilos/clientes.css">
    
    <!-- JS EXCLUSIVO DE ESTA PÁGINA -->
    <script src="scripts/clientes.js" defer></script>
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
                    <li class="active"><a href="clientes.php"><ion-icon name="people-outline"></ion-icon><span>Cliente</span></a></li>
                    <li><a href="solicitudes.php"><ion-icon name="document-text-outline"></ion-icon><span>Solicitudes</span></a></li>
                    <li><a href="prestamos.php"><ion-icon name="cash-outline"></ion-icon><span>Prestamos</span></a></li>
                    <li><a href="pagos.php"><ion-icon name="card-outline"></ion-icon><span>Pagos</span></a></li>
                    <li><a href="reportes.php"><ion-icon name="bar-chart-outline"></ion-icon><span>Reportes</span></a></li>
                    <li><a href="configuracion.php"><ion-icon name="settings-outline"></ion-icon><span>Configuración</span></a></li>
                </ul>
            </nav>

            <div class="sidebar-footer">
                <p class="logged-user">Nombre del que esta logueado</p>
                <a href="#" class="logout-link">Cerrar Sesión</a>
            </div>
        </aside>

        <!-- ÁREA DE CONTENIDO PRINCIPAL -->
        <main class="main-content">
            
            <h2 class="page-title">Cliente</h2>
            <hr class="title-divider">

            <div class="gestion-clientes-box">
                
                <div class="gestion-header">
                    <h3 class="gestion-titulo">Gestión de Clientes</h3>
                    <button class="btn-nuevo-cliente" id="btnNuevoCliente">
                        <ion-icon name="add-outline"></ion-icon>
                        Nuevo Cliente
                    </button>
                </div>

                <table class="tabla-clientes" id="tablaClientes">
                    <thead>
                        <tr>
                            <th>Cédula</th>
                            <th>Nombre Completo</th>
                            <th>Teléfono</th>
                            <th>Correo</th>
                            <th>Sueldo mensual</th>
                            <th>Acciones</th>
                        </tr>
                    </thead>
                    <tbody id="tbodyClientes"></tbody>
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

    <!-- MODAL DE MENSAJES -->
    <div class="modal-overlay modal-mensajes" id="modalOverlay">
        <div class="modal-box">
            <h3 class="modal-title" id="modalTitle">Título</h3>
            <p class="modal-message" id="modalMessage">Mensaje</p>
            <button class="modal-btn" id="modalBtn">Aceptar</button>
        </div>
    </div>

    <!-- MODAL CON FORMULARIO DE CLIENTE -->
    <div class="modal-overlay modal-formulario" id="modalFormCliente">
        <div class="modal-box modal-box-form">
            
            <button class="modal-close" id="cerrarFormCliente">
                <ion-icon name="close-outline"></ion-icon>
            </button>

            <h3 class="modal-title" id="tituloFormCliente">Nuevo Cliente</h3>
            <p class="modal-subtitle">Complete los datos del cliente</p>

            <form id="formCliente" class="form-cliente" novalidate>
                
                <input type="hidden" id="clienteId" name="clienteId">

                <div class="form-row">
                    <div class="input-group">
                        <input type="text" id="cedula" name="cedula" placeholder=" " required>
                        <label for="cedula">Cédula:</label>
                    </div>
                    <div class="input-group">
                        <input type="tel" id="telefono" name="telefono" placeholder=" " required>
                        <label for="telefono">Teléfono:</label>
                </div>
                <div class="input-group">
                    <input type="number" id="sueldo" name="sueldo" min="0" step="0.01" placeholder=" " required>
                    <label for="sueldo">Sueldo mensual (RD$):</label>
                    </div>
                </div>

                <div class="form-row">
                    <div class="input-group">
                        <input type="text" id="nombre" name="nombre" placeholder=" " required>
                        <label for="nombre">Nombre:</label>
                    </div>
                    <div class="input-group">
                        <input type="text" id="apellido" name="apellido" placeholder=" " required>
                        <label for="apellido">Apellido:</label>
                    </div>
                </div>

                <div class="input-group">
                    <input type="email" id="correo" name="correo" placeholder=" " required>
                    <label for="correo">Correo Electrónico:</label>
                </div>

                <div class="input-group">
                    <input type="text" id="direccion" name="direccion" placeholder=" " required>
                    <label for="direccion">Dirección:</label>
                </div>

                <div class="input-group" data-solo-creacion>
                    <input type="text" id="pais" name="pais" placeholder=" " required>
                    <label for="pais">País:</label>
                </div>
                <div class="form-row" data-solo-creacion>
                    <div class="input-group">
                        <input type="text" id="provincia" name="provincia" placeholder=" " required>
                        <label for="provincia">Provincia:</label>
                    </div>
                    <div class="input-group">
                        <input type="text" id="ciudad" name="ciudad" placeholder=" " required>
                        <label for="ciudad">Ciudad:</label>
                    </div>
                </div>
                <div class="input-group" data-solo-creacion>
                    <input type="password" id="contrasenaCliente" name="contrasena" minlength="8" placeholder=" " required>
                    <label for="contrasenaCliente">Contraseña inicial (mínimo 8 caracteres):</label>
                </div>
                <div class="form-buttons">
                    <button type="button" class="btn-cancelar" id="btnCancelarForm">Cancelar</button>
                    <button type="submit" class="btn-guardar" id="btnGuardarCliente">
                        <ion-icon name="save-outline"></ion-icon>
                        Guardar Cliente
                    </button>
                </div>

            </form>
        </div>
    </div>

</body>
</html>