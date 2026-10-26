<?php
require_once __DIR__ . '/php/auth.php';
redirigirSiYaInicioSesion();
?>
<!DOCTYPE html>
<html lang="es">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Iniciar Sesion | New Talent Loans</title>
        <link rel="icon" type="image/x-icon" href="Imagenes/NewTalentLoans.png">
        
        <!-- Importar fuente Montserrat -->
        <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;500;700&display=swap" rel="stylesheet">
        
        <!-- Enlace al archivo CSS externo -->
        <link rel="stylesheet" href="estilos/stylesPrincipal.css">
    </head>
    <body>

        <div class="login-wrapper">
            <div class="login-card">
                
                <div class="logo">
                    <img src="Imagenes/NewTalent.png" alt="New Talent Loans Logo">
                </div>

                <p class="instruction">Ingrese sus datos:</p>

                <!-- FORMULARIO con ID -->
                <form id="formLogin" action="#" method="POST">
                    
                    <div class="input-group">
                        <input type="email" id="correo" name="correo" placeholder=" " required>
                        <label for="correo">Correo:</label>
                    </div>

                    <div class="input-group">
                        <input type="password" id="password" name="password" placeholder=" " required>
                        <label for="password">Contraseña:</label>
                    </div>

                    <div class="links">
                        <p>¿Olvido su contraseña? <a href="cambiar-contrasena.php">¡Cámbiala Aquí!</a></p>
                        <p>¿Aun no eres parte de esta compañía? <a href="registro.php">¡Regístrate, es gratis!</a></p>
                    </div>

                    <button type="submit" class="btn-login">Iniciar Sesión</button>

                </form>
            </div>
        </div>

        <!-- MODAL (DEBE ESTAR ANTES DEL SCRIPT) -->
        <div class="modal-overlay" id="modalOverlay">
            <div class="modal-box">
                <h3 class="modal-title" id="modalTitle">Título</h3>
                <p class="modal-message" id="modalMessage">Mensaje</p>
                <button class="modal-btn" id="modalBtn">Aceptar</button>
            </div>
        </div>

        <!-- SCRIPT AL FINAL DEL BODY -->
        <script src="scripts/login.js"></script>
    </body>
</html>