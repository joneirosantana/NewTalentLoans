<?php
require_once __DIR__ . '/php/auth.php';
protegerPaginaSolicitudesCliente();
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Mis préstamos | New Talent Loans</title>
    <link rel="icon" href="Imagenes/NewTalentLoans.png">
    
    <!-- Fuente Montserrat -->
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;500;700&display=swap" rel="stylesheet">
    
    <!-- Ionicons -->
    <script type="module" src="https://unpkg.com/ionicons@7.1.0/dist/ionicons/ionicons.esm.js"></script>
    <script nomodule src="https://unpkg.com/ionicons@7.1.0/dist/ionicons/ionicons.js"></script>

    <!-- CSS ÚNICO PARA ESTA PÁGINA -->
    <link rel="stylesheet" href="estilos/solicitudes.css">
    
    <script src="scripts/solicitudes.js" defer></script>
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
            <span class="user-name">Cliente</span>
        </div>
    </header>

    <!-- CONTENEDOR PRINCIPAL -->
    <div class="app-container">
        
        <!-- MENÚ LATERAL -->
        <aside class="sidebar" id="sidebar">
            <nav class="sidebar-nav">
                <ul>
                    <li><a href="portal-cliente.php"><ion-icon name="home-outline"></ion-icon><span>Mi Inicio</span></a></li>
                    <li class="active"><a href="solicitudes.php"><ion-icon name="cash-outline"></ion-icon><span>Mis Préstamos</span></a></li>
                    <li><a href="pagos-cliente.php"><ion-icon name="card-outline"></ion-icon><span>Mis Pagos</span></a></li>
                    <li><a href="cambiar-contrasena.php"><ion-icon name="lock-closed-outline"></ion-icon><span>Cambiar Contraseña</span></a></li>
                </ul>
            </nav>

            <div class="sidebar-footer">
                <p class="logged-user">Nombre del Cliente</p>
                <a href="#" class="logout-link">Cerrar Sesión</a>
            </div>
        </aside>

        <!-- ÁREA DE CONTENIDO PRINCIPAL -->
        <main class="main-content">
            
            <h2 class="page-title">Mis Préstamos</h2>
            <hr class="title-divider">

            <!-- 4 CUADROS DE RESUMEN -->
            <div class="dashboard-cards">
                <div class="card">
                    <h3 class="card-value" id="sueldoCliente">$0.00</h3>
                    <p class="card-label">Mi Sueldo Mensual</p>
                </div>
                <div class="card">
                    <h3 class="card-value" id="prestamoMonto">$0.00</h3>
                    <p class="card-label">Monto Préstamo Activo</p>
                </div>
                <div class="card">
                    <h3 class="card-value" id="prestamoSaldo">$0.00</h3>
                    <p class="card-label">Saldo Pendiente</p>
                </div>
                <div class="card">
                    <h3 class="card-value" id="prestamoCuota">$0.00</h3>
                    <p class="card-label">Cuota Mensual</p>
                </div>
            </div>

            <!-- FORMULARIO DE SOLICITUD -->
            <div class="gestion-prestamos-box" style="margin-bottom: 30px;">
                <div class="gestion-header">
                    <h3 class="gestion-titulo">Solicitar un Nuevo Préstamo</h3>
                </div>
                
                <form id="formSolicitud" class="form-prestamo" style="padding: 10px 20px 20px;">
                    <div class="form-row">
                        <div class="input-group">
                            <select id="tipoPrestamo" required>
                                <option value="" disabled selected>Cargando...</option>
                            </select>
                            <label for="tipoPrestamo">Tipo de préstamo:</label>
                        </div>
                        <div class="input-group">
                            <select id="metodoPago" required>
                                <option value="" disabled selected>Cargando...</option>
                            </select>
                            <label for="metodoPago">Método de pago:</label>
                        </div>
                    </div>

                    <div class="form-row">
                        <div class="input-group">
                            <input id="monto" type="number" min="1" step="0.01" placeholder=" " required>
                            <label for="monto">Monto solicitado (RD$):</label>
                        </div>
                        <div class="input-group">
                            <input id="plazo" type="number" min="1" max="120" placeholder=" " required>
                            <label for="plazo">Plazo en meses:</label>
                        </div>
                    </div>

                    <div id="grupoGarante" class="grupo-garante" hidden>
                        <h3>Se requiere un garante</h3>
                        <p style="font-size: 13px; color: #e67e22; margin-bottom: 15px;">El monto supera su sueldo mensual. Complete los datos para continuar.</p>
                        <div class="input-group">
                            <input id="garanteNombre" type="text" maxlength="150" placeholder=" ">
                            <label for="garanteNombre">Nombre completo del garante:</label>
                        </div>
                        <div class="form-row">
                            <div class="input-group">
                                <input id="garanteCedula" type="text" maxlength="30" placeholder=" ">
                                <label for="garanteCedula">Cédula del garante:</label>
                            </div>
                            <div class="input-group">
                                <input id="garanteTelefono" type="tel" maxlength="30" placeholder=" ">
                                <label for="garanteTelefono">Teléfono del garante:</label>
                            </div>
                        </div>
                    </div>

                    <div class="input-group">
                        <textarea id="motivo" rows="3" maxlength="500" placeholder=" " required></textarea>
                        <label for="motivo">Motivo de la solicitud:</label>
                    </div>

                    <div class="form-buttons" style="justify-content: flex-start; gap: 15px; border: none; padding-top: 10px;">
                        <button id="btnProyeccion" type="button" class="btn-cancelar">
                            <ion-icon name="calculator-outline"></ion-icon> Proyección
                        </button>
                        <button id="btnEnviar" type="submit" class="btn-guardar">
                            <ion-icon name="send-outline"></ion-icon> Enviar Solicitud
                        </button>
                    </div>
                    <div id="resultadoProyeccion" class="proyeccion" role="status" hidden></div>
                </form>
                <p id="mensaje" role="status" style="font-weight: 600; text-align: center; margin-top: 15px;"></p>
            </div>

            <!-- PANEL DE PRÉSTAMO ACTIVO (Si existe) -->
            <div id="panelPrestamoActivo" class="gestion-prestamos-box" style="margin-bottom: 30px;" hidden>
                <div class="gestion-header">
                    <h3 class="gestion-titulo">Mi Préstamo Activo</h3>
                </div>
                <div id="resumenPrestamo" class="resumen-prestamo" style="padding: 15px 20px;"></div>

                <form id="formPago" class="form-prestamo" style="padding: 10px 20px 20px;">
                    <h3 style="font-size: 16px; color: #00963f; margin-bottom: 10px;">Registrar pago o adelanto</h3>
                    
                    <div class="form-row">
                        <div class="input-group">
                            <select id="tipoPago">
                                <option value="cuota">Pago</option>
                                <option value="adelanto">Adelanto a capital</option>
                            </select>
                            <label for="tipoPago">Operación:</label>
                        </div>
                        <div class="input-group">
                            <select id="metodoPagoActivo" required>
                                <option value="" disabled selected>Seleccione</option>
                            </select>
                            <label for="metodoPagoActivo">Método de pago:</label>
                        </div>
                    </div>

                    <div class="input-group">
                        <input id="montoPago" type="number" min="0.01" step="0.01" placeholder=" " required>
                        <label for="montoPago">Monto (RD$):</label>
                    </div>

                    <div class="form-buttons" style="justify-content: flex-start; border: none; padding-top: 10px;">
                        <button id="btnRegistrarPago" type="submit" class="btn-guardar">
                            <ion-icon name="save-outline"></ion-icon> Registrar operación
                        </button>
                    </div>
                </form>
                <p id="mensajePago" role="status" style="font-weight: 600; text-align: center; margin-top: 10px;"></p>

                <div style="padding: 0 20px 20px;">
                    <button id="btnContacto" type="button" class="btn-cancelar">
                        <ion-icon name="headset-outline"></ion-icon> Contactar soporte
                    </button>
                    <div id="datosContacto" class="datos-contacto" hidden>
                        <a class="contacto" href="mailto:contacto@NuevoTalentoLoans.com">contacto@NuevoTalentoLoans.com</a>
                        <a class="contacto" href="tel:8091110000">809-111-0000</a>
                    </div>
                </div>
            </div>

            <!-- TABLA DE HISTORIAL DE SOLICITUDES -->
            <div class="table-section">
                <h3 class="table-title">Historial de Solicitudes</h3>
                <table class="data-table" id="tablaSolicitudes">
                    <thead>
                        <tr>
                            <th>Fecha</th>
                            <th>Monto</th>
                            <th>Plazo</th>
                            <th>Motivo</th>
                            <th>Estado</th>
                        </tr>
                    </thead>
                    <tbody id="listaSolicitudes">
                        <tr><td colspan="5" class="tabla-vacia">Cargando...</td></tr>
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

</body>
</html>