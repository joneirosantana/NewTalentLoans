// ==========================================================
// SISTEMA DE CONFIGURACIÓN - New Talent Loans
// ==========================================================

document.addEventListener('DOMContentLoaded', () => {

    // ==========================================================
    // 🔌 CONFIGURACIÓN DEL BACKEND
    // ==========================================================
    const API_URL = 'http://localhost:3000';

    const ENDPOINTS = {
        obtener: `${API_URL}/api/configuracion`,
        guardar: `${API_URL}/api/configuracion`
    };

    // 👇 Cambia a FALSE cuando tengas tu backend listo
    const MODO_SIMULACION = true;

    // =========================================
    // REFERENCIAS DEL DOM
    // =========================================
    const formConfiguracion = document.getElementById('formConfiguracion');
    const inputTasaInteres = document.getElementById('tasaInteres');
    const selectMoneda = document.getElementById('moneda');
    const btnGuardarCambios = document.getElementById('btnGuardarCambios');

    // Modal de mensajes
    const modalOverlay = document.getElementById('modalOverlay');
    const modalTitle = document.getElementById('modalTitle');
    const modalMessage = document.getElementById('modalMessage');
    const modalBtn = document.getElementById('modalBtn');

    let accionModalActual = null;

    // ==========================================================
    // 🧭 SIDEBAR
    // ==========================================================
    const menuToggle = document.querySelector('.menu-toggle');
    const sidebar = document.querySelector('.sidebar');
    if (menuToggle && sidebar) {
        menuToggle.addEventListener('click', () => {
            sidebar.classList.toggle('open');
        });
    }

    // Nombre del usuario logueado
    const usuarioGuardado = localStorage.getItem('usuario');
    if (usuarioGuardado) {
        try {
            const datos = JSON.parse(usuarioGuardado);
            const nombreCompleto = datos.nombre + ' ' + (datos.apellido || '');
            const userNameElement = document.querySelector('.user-name');
            if (userNameElement) userNameElement.textContent = nombreCompleto;
            const loggedUserElement = document.querySelector('.logged-user');
            if (loggedUserElement) loggedUserElement.textContent = nombreCompleto;
        } catch (e) {
            console.warn('No se pudo leer el usuario del localStorage');
        }
    }

    // =========================================
    // SISTEMA DE MODAL
    // =========================================
    function mostrarModal(titulo, mensaje, accionAceptar = null) {
        modalTitle.textContent = titulo;
        modalMessage.textContent = mensaje;
        modalOverlay.classList.add('active');
        accionModalActual = accionAceptar;
    }

    function cerrarModal() {
        modalOverlay.classList.remove('active');
        accionModalActual = null;
    }

    modalBtn.addEventListener('click', () => {
        const accion = accionModalActual;
        cerrarModal();
        if (accion) accion();
    });

    modalOverlay.addEventListener('click', (e) => {
        if (e.target === modalOverlay) cerrarModal();
    });

    // =========================================
    // CERRAR SESIÓN
    // =========================================
    const logoutLink = document.querySelector('.logout-link');
    if (logoutLink) {
        logoutLink.addEventListener('click', (e) => {
            e.preventDefault();

            mostrarModal(
                'Cerrar Sesión',
                '¿Estás seguro de que deseas cerrar sesión?',
                () => {
                    localStorage.removeItem('token');
                    fetch('php/api.php?recurso=cerrar-sesion', { method: 'POST', keepalive: true });
                    localStorage.removeItem('usuario');
                    console.log('👋 Sesión cerrada correctamente');
                    window.location.href = 'sesion-cerrada.php';
                }
            );
        });
    }

    // =========================================
    // FUNCIÓN AUXILIAR: PETICIÓN A LA API
    // =========================================
    async function peticionAPI(url, opciones = {}) {
        try {
            const response = await fetch(url, opciones);
            const data = await response.json();
            return { ok: response.ok, status: response.status, data };
        } catch (error) {
            console.error('❌ Error en la petición:', error);
            return { ok: false, status: 0, data: { message: 'Error de conexión con el servidor' } };
        }
    }

    // =========================================
    // 1. CARGAR CONFIGURACIÓN ACTUAL
    // =========================================
    async function cargarConfiguracion() {
        console.log('📋 [API] GET ' + ENDPOINTS.obtener);

        if (MODO_SIMULACION) {
            // 🔸 Valores por defecto (simulados)
            inputTasaInteres.value = '15';
            selectMoneda.value = 'COP';
            return;
        }

        const { ok, data } = await peticionAPI(ENDPOINTS.obtener);

        if (ok && data.success) {
            inputTasaInteres.value = data.tasaInteres || '';
            selectMoneda.value = data.moneda || '';
        } else {
            console.warn('No se pudo cargar la configuración actual');
        }
    }

    // =========================================
    // 2. GUARDAR CONFIGURACIÓN
    // =========================================
    formConfiguracion.addEventListener('submit', async (e) => {
        e.preventDefault();

        const tasaInteres = inputTasaInteres.value.trim();
        const moneda = selectMoneda.value;

        // Validaciones
        if (tasaInteres === '' || moneda === '') {
            mostrarModal('Campos Incompletos', 'Por favor complete todos los campos.');
            return;
        }

        if (parseFloat(tasaInteres) < 0 || parseFloat(tasaInteres) > 100) {
            mostrarModal('Tasa Inválida', 'La tasa de interés debe estar entre 0 y 100.');
            return;
        }

        const datos = {
            tasaInteres: parseFloat(tasaInteres),
            moneda: moneda
        };

        console.log('💾 Enviando configuración:', datos);
        mostrarModal('Guardando...', 'Guardando los cambios en el servidor...');

        if (MODO_SIMULACION) {
            setTimeout(() => {
                cerrarModal();
                mostrarModal(
                    '¡Cambios Guardados!',
                    `La configuración se ha guardado correctamente (simulado).\n\nTasa: ${datos.tasaInteres}%\nMoneda: ${datos.moneda}`
                );
            }, 1000);
            return;
        }

        // 🔌 REAL
        const { ok, data } = await peticionAPI(ENDPOINTS.guardar, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(datos)
        });

        cerrarModal();

        if (ok && data.success) {
            mostrarModal(
                '¡Cambios Guardados!',
                data.message || 'La configuración se ha guardado correctamente.'
            );
        } else {
            mostrarModal('Error', data.message || 'No se pudo guardar la configuración.');
        }
    });

    // =========================================
    // 3. INICIALIZAR
    // =========================================
    cargarConfiguracion();

    // =========================================
    // 4. CERRAR MODALES CON ESC
    // =========================================
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            document.querySelectorAll('.modal-overlay.active').forEach(modal => {
                modal.classList.remove('active');
            });
            accionModalActual = null;
        }
    });

});