<?php
require_once __DIR__ . '/php/auth.php';
protegerPaginaAdministrativa();
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Gestión de créditos | New Talent Loans</title>
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;500;700&display=swap" rel="stylesheet">
    <link rel="icon" type="image/x-icon" href="Imagenes/NewTalentLoans.png">
    
    <!-- Ionicons -->
    <script type="module" src="https://unpkg.com/ionicons@7.1.0/dist/ionicons/ionicons.esm.js"></script>
    <script nomodule src="https://unpkg.com/ionicons@7.1.0/dist/ionicons/ionicons.js"></script>
    
    <!-- CSS ÚNICO -->
    <link rel="stylesheet" href="estilos/gestionCreditos.css">
    
    <script src="scripts/gestionCreditos.js" defer></script>
</head>
<body>

    <!-- Encabezado Superior -->
    <header class="top-header">
        <!-- Logo pegado a la esquina izquierda -->
        <div class="logo-container">
            <div class="logo-white-bg">
                <img src="Imagenes/NewTalentLoans.png" alt="Logo New Talent" class="logo-img">
            </div>
        </div>
        
        <!-- Información del Usuario -->
        <div class="user-info">
            <div class="user-avatar"></div>
            <span class="user-name" id="usuarioActual">Administración</span>
        </div>
    </header>

    <!-- Contenido Principal -->
    <main class="main-content">
        
        <h1 class="welcome-message">Gestión del ciclo de crédito</h1>

        <!-- CAJA DE SELECCIÓN DE ENTIDAD -->
        <fieldset class="services-box" style="margin-bottom: 30px;">
            <legend>Entidad a gestionar</legend>
            <p style="font-size: 14px; color: #555; margin-bottom: 15px;">Seleccione una entidad para consultar sus registros y administrar sus datos.</p>
            
            <div class="input-group" style="max-width: 400px;">
                <select id="recurso">
                    <option value="solicitudes">Solicitudes</option>
                    <option value="prestamos">Préstamos</option>
                    <option value="tipos-prestamo">Tipos de préstamo</option>
                    <option value="estados-prestamo">Estados del préstamo</option>
                    <option value="cuotas">Cuotas</option>
                    <option value="pagos">Pagos</option>
                    <option value="metodos-pago">Métodos de pago</option>
                    <option value="garantes">Garantes</option>
                    <option value="facturacion">Facturación</option>
                </select>
                <label for="recurso">Entidad:</label>
            </div>
            <p id="estado" role="status" style="font-weight: 600; margin-top: 15px; color: #00963f;"></p>
        </fieldset>

        <!-- CAJA DE FORMULARIO -->
        <fieldset class="services-box" style="margin-bottom: 30px;">
            <legend id="tituloFormulario">Nuevo registro</legend>
            
            <form id="formularioRegistro" class="form-prestamo" style="padding: 10px 0;">
                <div id="camposFormulario" class="form-grid"></div>
                
                <div class="form-buttons" style="justify-content: flex-start; border: none; padding-top: 20px;">
                    <button type="submit" id="guardar" class="btn-guardar">
                        <ion-icon name="save-outline"></ion-icon> Crear registro
                    </button>
                    <button type="button" class="btn-cancelar" id="cancelar">
                        Limpiar
                    </button>
                </div>
            </form>
        </fieldset>

        <!-- CAJA DE TABLA -->
        <fieldset class="services-box">
            <legend>Registros</legend>
            <div class="table-section">
                <table class="data-table" id="tablaRegistros">
                    <thead id="encabezadoTabla"></thead>
                    <tbody id="cuerpoTabla"></tbody>
                </table>
            </div>
        </fieldset>

    </main>

    <!-- Pie de página verde oliva -->
    <footer class="bottom-footer"></footer>

</body>
</html>