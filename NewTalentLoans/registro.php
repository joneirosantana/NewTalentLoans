<?php
require_once __DIR__ . '/php/auth.php';
redirigirSiYaInicioSesion();
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Registrarse | New Talent Loans</title>
    <link rel="icon" type="image/x-icon" href="Imagenes/NewTalentLoans.png">
    <!-- Fuente Montserrat -->
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;500;700&display=swap" rel="stylesheet">
    
    <!-- Ionicons -->
    <script type="module" src="https://unpkg.com/ionicons@7.1.0/dist/ionicons/ionicons.esm.js"></script>
    <script nomodule src="https://unpkg.com/ionicons@7.1.0/dist/ionicons/ionicons.js"></script>

    <link rel="stylesheet" href="estilos/stylesRegistro.css">
</head>
<body>

    <div class="registro-wrapper">
        
        <div class="registro-card">
            
            <!-- Flecha para volver -->
            <button class="btn-volver" id="btnVolver" type="button">
                <ion-icon name="arrow-back-outline"></ion-icon>
            </button>

            <!-- Título -->
            <h1 class="titulo">Registrarse</h1>

            <!-- Texto descriptivo -->
            <p class="descripcion">
                Estimado/a Cliente, por favor ingrese sus datos para pertenecer a nuestro sistema.
            </p>

            <form id="formRegistro" action="#" method="POST" novalidate>

                <!-- PASO 1: Nombre y Apellido -->
                <div class="paso activo" id="paso-1">
                    <div class="input-group">
                        <input type="text" id="nombre" name="nombre" required>
                        <label for="nombre">Nombre:</label>
                    </div>
                    <div class="input-group">
                        <input type="text" id="apellido" name="apellido" required>
                        <label for="apellido">Apellido:</label>
                    </div>
                </div>

                <!-- PASO 2: Dirección, Teléfono, Cédula -->
                <div class="paso" id="paso-2">
                    <div class="input-group">
                        <input type="number" id="sueldo" name="sueldo" min="0" step="0.01" required>
                        <label for="sueldo">Sueldo mensual (RD$):</label>
                    </div>
                    <div class="input-group">
                        <input type="text" id="direccion" name="direccion" maxlength="250" required>
                        <label for="direccion">Dirección:</label>
                    </div>
                    <div class="input-group">
                        <input type="text" id="pais" name="pais" required>
                        <label for="pais">País:</label>
                    </div>
                    <div class="input-group">
                        <input type="text" id="provincia" name="provincia" required>
                        <label for="provincia">Provincia:</label>
                    </div>
                    <div class="input-group">
                        <input type="text" id="ciudad" name="ciudad" required>
                        <label for="ciudad">Ciudad:</label>
                    </div>
                    <div class="input-group">
                        <input type="tel" id="telefono" name="telefono" required>
                        <label for="telefono">Número de Teléfono:</label>
                    </div>
                    <div class="input-group">
                        <input type="text" id="cedula" name="cedula" required>
                        <label for="cedula">Cédula:</label>
                    </div>
                </div>

                <!-- PASO 3: Correo, Contraseña, Confirmar + Términos -->
                <div class="paso" id="paso-3">
                    <div class="input-group">
                        <input type="email" id="correo" name="correo" required>
                        <label for="correo">Correo Electrónico:</label>
                    </div>
                    <div class="input-group">
                        <input type="password" id="password" name="password" required>
                        <label for="password">Contraseña:</label>
                    </div>
                    <div class="input-group">
                        <input type="password" id="confirmPassword" name="confirmPassword" required>
                        <label for="confirmPassword">Confirmar Contraseña:</label>
                    </div>

                    <!-- Checkbox de Términos -->
                    <div class="terminos-box">
                        <label class="checkbox-container">
                            <input type="checkbox" id="aceptarTerminos" required>
                            <span class="checkmark"></span>
                            <span class="terminos-texto">
                                Acepto los <a href="#" id="verTerminos">Términos y Condiciones</a> 
                                de New Talent Loans.
                            </span>
                        </label>
                    </div>
                </div>

                <!-- Botón Siguiente / Registrar -->
                <button type="submit" class="btn-registrar" id="btnSiguiente">Siguiente</button>

            </form>
        </div>
    </div>

    <!-- MODAL DE MENSAJES (Éxito/Error) -->
    <div class="modal-overlay" id="modalOverlay">
        <div class="modal-box">
            <h3 class="modal-title" id="modalTitle">Título</h3>
            <p class="modal-message" id="modalMessage">Mensaje</p>
            <button class="modal-btn" id="modalBtn" type="button">Aceptar</button>
        </div>
    </div>

    <!-- MODAL DE TÉRMINOS Y CONDICIONES -->
    <div class="modal-overlay" id="modalTerminos">
        <div class="modal-box modal-box-grande">
            <h3 class="modal-title">Términos y Condiciones</h3>
                <div class="terminos-contenido">
                    
                    <p class="terminos-fecha"><strong>Última actualización:</strong> Enero 2026</p>
                    
                    <p><strong>1. Aceptación de los Términos</strong></p>
                    <p>Al registrarse y utilizar los servicios de <strong>New Talent Loans</strong>, usted acepta de manera libre, expresa e informada los presentes Términos y Condiciones. Si no está de acuerdo con alguno de los puntos aquí establecidos, le solicitamos abstenerse de utilizar el sistema.</p>

                    <p><strong>2. Normas de Uso del Sistema</strong></p>
                    <p>El usuario se compromete a:</p>
                    <ul>
                        <li>Proporcionar información <strong>veraz, completa y actualizada</strong> en el momento del registro.</li>
                        <li>No compartir su contraseña ni credenciales de acceso con terceros.</li>
                        <li>Utilizar la plataforma únicamente para fines lícitos y relacionados con los servicios ofrecidos.</li>
                        <li>No realizar intentos de hackeo, ingeniería inversa o manipulación del sistema.</li>
                        <li>Mantener actualizados sus datos de contacto para la correcta gestión del préstamo.</li>
                    </ul>

                    <p><strong>3. Autorización de Acceso a Tarjetas y Cuentas Bancarias</strong></p>
                    <p>El usuario, al aceptar estos términos, <strong>autoriza expresamente a New Talent Loans</strong> a:</p>
                    <ul>
                        <li>Acceder a la información de sus tarjetas débito/crédito y cuentas bancarias registradas.</li>
                        <li>Realizar débitos automáticos para el cobro de cuotas, intereses y moras cuando corresponda.</li>
                        <li>Consultar su historial crediticio en centrales de riesgo (Datacrédito, Cifin, etc.).</li>
                        <li>Gestionar el cobro sin límite de gastos sobre las cuentas asociadas al préstamo, siempre bajo las condiciones pactadas.</li>
                    </ul>
                    <p>Esta autorización permanecerá vigente durante toda la relación contractual y hasta la cancelación total de la obligación.</p>

                    <p><strong>4. Condiciones del Préstamo</strong></p>
                    <ul>
                        <li>El monto, plazo y tasa de interés serán informados al momento de la aprobación del crédito.</li>
                        <li>El usuario se compromete a pagar las cuotas en las fechas establecidas.</li>
                        <li>El incumplimiento genera <strong>intereses de mora</strong> y posibles reportes a centrales de riesgo.</li>
                        <li>New Talent Loans se reserva el derecho de aprobar o rechazar solicitudes según su análisis interno.</li>
                    </ul>

                    <p><strong>5. Uso de los Datos Personales</strong></p>
                    <p>Los datos proporcionados serán tratados conforme a la <strong>Ley de Protección de Datos Personales</strong> y utilizados exclusivamente para:</p>
                    <ul>
                        <li>Validación de identidad y capacidad de pago.</li>
                        <li>Gestión de cobranza y seguimiento del crédito.</li>
                        <li>Envío de notificaciones relacionadas con el servicio.</li>
                    </ul>
                    <p>New Talent Loans no compartirá su información con terceros sin su consentimiento, salvo obligación legal.</p>

                    <p><strong>6. Confidencialidad</strong></p>
                    <p>New Talent Loans se compromete a proteger la información personal y financiera de sus usuarios mediante medidas de seguridad técnicas y administrativas adecuadas.</p>

                    <p><strong>7. Responsabilidades del Usuario</strong></p>
                    <p>El usuario será el único responsable de:</p>
                    <ul>
                        <li>La veracidad de la información suministrada.</li>
                        <li>El uso que le dé a su cuenta dentro del sistema.</li>
                        <li>El pago oportuno de sus obligaciones financieras.</li>
                        <li>Las consecuencias derivadas del mal uso de la plataforma.</li>
                    </ul>

                    <p><strong>8. Cobranza y Reportes</strong></p>
                    <p>En caso de mora, New Talent Loans podrá:</p>
                    <ul>
                        <li>Realizar cobros por vía telefónica, correo electrónico o mensajes de texto.</li>
                        <li>Reportar al usuario a centrales de riesgo.</li>
                        <li>Iniciar acciones legales de cobro judicial cuando sea necesario.</li>
                    </ul>

                    <p><strong>9. Modificaciones</strong></p>
                    <p>New Talent Loans se reserva el derecho de modificar estos Términos y Condiciones en cualquier momento. Las modificaciones serán notificadas al usuario y entrarán en vigencia desde su publicación en el sistema.</p>

                    <p><strong>10. Aceptación Final</strong></p>
                    <p>Al marcar la casilla de aceptación, el usuario declara haber leído, entendido y aceptado en su totalidad los presentes Términos y Condiciones, así como autorizar el acceso a sus cuentas y tarjetas según lo estipulado.</p>

                </div>
            <button class="modal-btn" id="cerrarTerminos" type="button">Entendido</button>
        </div>
    </div>

    <script src="scripts/registro.js"></script>
</body>
</html>


