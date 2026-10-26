// ==========================================================
// SISTEMA DE REPORTES - New Talent Loans
// ==========================================================

document.addEventListener('DOMContentLoaded', () => {

    // ==========================================================
    // 🔌 CONFIGURACIÓN DEL BACKEND
    // ==========================================================
    const API_URL = 'http://localhost:3000';

    const ENDPOINTS = {
        estadisticas: `${API_URL}/api/reportes/estadisticas`,  // GET - Tasa y ganancia
        exportar:     (tipo, formato) => `${API_URL}/api/reportes/exportar?tipo=${tipo}&formato=${formato}`  // GET - Exportar
    };

    // 👇 Cambia a FALSE cuando tengas tu backend listo
    const MODO_SIMULACION = true;

    // =========================================
    // REFERENCIAS DEL DOM
    // =========================================
    const cardTasa = document.getElementById('card-tasa');
    const cardGanancia = document.getElementById('card-ganancia');

    const btnExportarPDF = document.getElementById('btnExportarPDF');
    const btnExportarExcel = document.getElementById('btnExportarExcel');

    // Modal de mensajes
    const modalOverlay = document.getElementById('modalOverlay');
    const modalTitle = document.getElementById('modalTitle');
    const modalMessage = document.getElementById('modalMessage');
    const modalBtn = document.getElementById('modalBtn');

    // Modal de selección de reporte
    const modalSeleccionReporte = document.getElementById('modalSeleccionReporte');
    const cerrarSeleccionReporte = document.getElementById('cerrarSeleccionReporte');
    const btnCancelarExportar = document.getElementById('btnCancelarExportar');
    const btnConfirmarExportar = document.getElementById('btnConfirmarExportar');
    const tituloSeleccionReporte = document.getElementById('tituloSeleccionReporte');

    let formatoSeleccionado = 'pdf';
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
                    localStorage.removeItem('usuario');
                    console.log('👋 Sesión cerrada correctamente');
                    window.location.href = 'CerrarSesionExitoso.html';
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
    // 1. CARGAR ESTADÍSTICAS
    // =========================================
    async function cargarEstadisticas() {
        console.log('📊 [API] GET ' + ENDPOINTS.estadisticas);

        if (MODO_SIMULACION) {
            // Valores de ejemplo
            cardTasa.querySelector('.card-value').textContent = '0%';
            cardGanancia.querySelector('.card-value').textContent = '$0.00';
            return;
        }

        const { ok, data } = await peticionAPI(ENDPOINTS.estadisticas);

        if (ok && data.success) {
            cardTasa.querySelector('.card-value').textContent = data.tasaCobro + '%';
            cardGanancia.querySelector('.card-value').textContent = 
                '$' + Number(data.gananciaIntereses).toLocaleString('es-CO', {
                    minimumFractionDigits: 2,
                    maximumFractionDigits: 2
                });
        }
    }

    // =========================================
    // 2. ABRIR MODAL DE SELECCIÓN DE REPORTE
    // =========================================
    function abrirModalSeleccion(formato) {
        formatoSeleccionado = formato;
        tituloSeleccionReporte.textContent = `Exportar a ${formato.toUpperCase()}`;

        // Reset del radio button a "clientes"
        const primerRadio = document.querySelector('input[name="tipoReporte"][value="clientes"]');
        if (primerRadio) primerRadio.checked = true;

        modalSeleccionReporte.classList.add('active');
    }

    function cerrarModalSeleccion() {
        modalSeleccionReporte.classList.remove('active');
    }

    // =========================================
    // 3. BOTONES DE EXPORTAR
    // =========================================
    if (btnExportarPDF) {
        btnExportarPDF.addEventListener('click', () => {
            console.log('📄 Exportar a PDF');
            abrirModalSeleccion('pdf');
        });
    }

    if (btnExportarExcel) {
        btnExportarExcel.addEventListener('click', () => {
            console.log('📊 Exportar a Excel');
            abrirModalSeleccion('excel');
        });
    }

    // Cerrar modal de selección
    cerrarSeleccionReporte.addEventListener('click', cerrarModalSeleccion);
    btnCancelarExportar.addEventListener('click', cerrarModalSeleccion);

    modalSeleccionReporte.addEventListener('click', (e) => {
        if (e.target === modalSeleccionReporte) cerrarModalSeleccion();
    });

    // =========================================
    // 4. CONFIRMAR EXPORTACIÓN
    // =========================================
    btnConfirmarExportar.addEventListener('click', async () => {
        // Obtenemos el tipo de reporte seleccionado
        const radioSeleccionado = document.querySelector('input[name="tipoReporte"]:checked');
        if (!radioSeleccionado) {
            mostrarModal('Selección Requerida', 'Debes seleccionar un tipo de reporte.');
            return;
        }

        const tipoReporte = radioSeleccionado.value;
        const formato = formatoSeleccionado;

        cerrarModalSeleccion();

        console.log(`📤 Exportando reporte: ${tipoReporte} en formato ${formato}`);

        mostrarModal('Generando Reporte...', 'Preparando el archivo para descarga...');

        if (MODO_SIMULACION) {
            setTimeout(() => {
                cerrarModal();
                mostrarModal(
                    '✅ Reporte Generado',
                    `El reporte de "${tipoReporte}" en formato ${formato.toUpperCase()} se ha generado correctamente (simulado).`
                );
            }, 1500);
            return;
        }

        // 🔌 REAL: Descargamos el archivo
        try {
            const url = ENDPOINTS.exportar(tipoReporte, formato);
            console.log('🌐 Descargando: ' + url);

            // Creamos un enlace temporal para descargar el archivo
            const link = document.createElement('a');
            link.href = url;
            link.download = `reporte_${tipoReporte}_${Date.now()}.${formato === 'pdf' ? 'pdf' : 'xlsx'}`;
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);

            cerrarModal();
            mostrarModal(
                '✅ Descarga Iniciada',
                'El reporte se está descargando. Revisa tu carpeta de descargas.'
            );
        } catch (error) {
            cerrarModal();
            mostrarModal('Error', 'No se pudo generar el reporte. Intente de nuevo.');
        }
    });

    // =========================================
    // 5. INICIALIZAR
    // =========================================
    cargarEstadisticas();

    // =========================================
    // 6. CERRAR MODALES CON ESC
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