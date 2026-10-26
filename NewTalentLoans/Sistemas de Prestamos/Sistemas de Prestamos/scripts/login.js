// ============================================
// VALIDACIÓN DE LOGIN - New Talent Loans
// ============================================
// Esperamos a que TODO el HTML esté cargado antes de ejecutar
document.addEventListener('DOMContentLoaded', function() {

    console.log("✅ login.js cargado correctamente");

    // =========================================
    // 1. REFERENCIAS A LOS ELEMENTOS DEL HTML
    // =========================================
    const formLogin = document.getElementById('formLogin');
    const inputCorreo = document.getElementById('correo');
    const inputPassword = document.getElementById('password');
    const modalOverlay = document.getElementById('modalOverlay');
    const modalTitle = document.getElementById('modalTitle');
    const modalMessage = document.getElementById('modalMessage');
    const modalBtn = document.getElementById('modalBtn');

    // =========================================
    // 2. VERIFICACIÓN DE SEGURIDAD
    // =========================================
    if (!formLogin) { console.error("❌ Falta el formulario con id='formLogin'"); return; }
    if (!inputCorreo) { console.error("❌ Falta el input con id='correo'"); return; }
    if (!inputPassword) { console.error("❌ Falta el input con id='password'"); return; }
    if (!modalOverlay) { console.error("❌ Falta el modal con id='modalOverlay'"); return; }
    if (!modalTitle) { console.error("❌ Falta el título del modal con id='modalTitle'"); return; }
    if (!modalMessage) { console.error("❌ Falta el mensaje del modal con id='modalMessage'"); return; }
    if (!modalBtn) { console.error("❌ Falta el botón del modal con id='modalBtn'"); return; }

    console.log("✅ Todos los elementos del HTML fueron encontrados");

    // =========================================
    // 3. FUNCIÓN PARA MOSTRAR EL MODAL
    // =========================================
    function mostrarModal(titulo, mensaje, callback) {
        modalTitle.textContent = titulo;
        modalMessage.textContent = mensaje;
        modalOverlay.classList.add('active');

        // Limpiamos el evento anterior y creamos uno nuevo
        const nuevoBtn = modalBtn.cloneNode(true);
        modalBtn.parentNode.replaceChild(nuevoBtn, modalBtn);

        nuevoBtn.addEventListener('click', function() {
            modalOverlay.classList.remove('active');
            if (callback) callback();
        });
    }

    // Cerrar modal al hacer clic fuera de la caja
    modalOverlay.addEventListener('click', function(e) {
        if (e.target === modalOverlay) {
            modalOverlay.classList.remove('active');
        }
    });

    // =========================================
    // 4. VALIDACIÓN DEL FORMULARIO
    // =========================================
    formLogin.addEventListener('submit', function(e) {
        e.preventDefault(); // Evita que la página se recargue

        console.log("Formulario enviado");

        const correo = inputCorreo.value.trim();
        const password = inputPassword.value.trim();

        // --- VALIDACIÓN 1: Campos vacíos ---
        if (correo === '' || password === '') {
            mostrarModal('Campos Vacíos', 'Por favor, complete todos los campos para continuar.');
            return;
        }

        // --- VALIDACIÓN 2: Formato de correo ---
        const regexCorreo = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!regexCorreo.test(correo)) {
            mostrarModal('Correo Inválido', 'Por favor, ingrese un correo electrónico válido (ejemplo@dominio.com).');
            return;
        }

        // --- VALIDACIÓN 3: Contraseña mínima ---
        if (password.length < 6) {
            mostrarModal('Contraseña Corta', 'La contraseña debe tener al menos 6 caracteres.');
            return;
        }

        console.log("✅ Validaciones pasadas. Enviando al backend...");

        // =========================================
        // 5. CONEXIÓN CON EL BACKEND
        // =========================================
        // Cuando tengas tu API lista, DESCOMENTA este bloque y BORRA la simulación:
        
        /*
        fetch('https://tu-api.com/login', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ correo: correo, password: password })
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                localStorage.setItem('token', data.token);
                localStorage.setItem('usuario', data.nombre);
                mostrarModal('¡Bienvenido!', 'Hola ' + data.nombre + ', redirigiendo...', function() {
                    window.location.href = 'PanelDeServicio.html';
                });
            } else {
                mostrarModal('Credenciales Incorrectas', data.message || 'El correo o la contraseña no son válidos.');
            }
        })
        .catch(error => {
            console.error('Error:', error);
            mostrarModal('Error de Conexión', 'No se pudo conectar con el servidor. Intente más tarde.');
        });
        */

        // --- SIMULACIÓN (BORRAR CUANDO CONECTES TU BACKEND) ---
        setTimeout(function() {
            // Credenciales de prueba
            if (correo === 'admin@newtalent.com' && password === '123456') {
                localStorage.setItem('usuario', 'Administrador');
                
                mostrarModal('¡Bienvenido!', 'Inicio de sesión exitoso. Redirigiendo al sistema...', function() {
                    window.location.href = 'PanelDeServicio.html';
                });
            } else {
                mostrarModal('Credenciales Incorrectas', 'El correo o la contraseña no son válidos. Intente de nuevo.');
            }
        }, 800);
    });

});