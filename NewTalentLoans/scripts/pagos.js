// ==========================================================
// SISTEMA DE GESTIÓN DE PAGOS - New Talent Loans
// ==========================================================

document.addEventListener('DOMContentLoaded', () => {

    // ==========================================================
    // 🔌 CONFIGURACIÓN DEL BACKEND
    // ==========================================================
    const API_URL = 'http://localhost:3000';

    const ENDPOINTS = {
        listar:     `${API_URL}/api/pagos`,
        obtener:    (id) => `${API_URL}/api/pagos/${id}`,
        crear:      `${API_URL}/api/pagos`,
        actualizar: (id) => `${API_URL}/api/pagos/${id}`,
        eliminar:   (id) => `${API_URL}/api/pagos/${id}`,
        prestamos:  `${API_URL}/api/prestamos`
    };

    // 👇 Cambia a FALSE cuando tengas tu backend listo
    const MODO_SIMULACION = true;

    // =========================================
    // REFERENCIAS DEL DOM
    // =========================================
    const btnNuevoPago = document.getElementById('btnNuevoPago');
    const tbodyPagos = document.getElementById('tbodyPagos');

    // Modal de mensajes
    const modalOverlay = document.getElementById('modalOverlay');
    const modalTitle = document.getElementById('modalTitle');
    const modalMessage = document.getElementById('modalMessage');
    const modalBtn = document.getElementById('modalBtn');

    // Modal con formulario
    const modalFormPago = document.getElementById('modalFormPago');
    const cerrarFormPago = document.getElementById('cerrarFormPago');
    const btnCancelarForm = document.getElementById('btnCancelarForm');
    const formPago = document.getElementById('formPago');
    const tituloFormPago = document.getElementById('tituloFormPago');
    const btnGuardarPago = document.getElementById('btnGuardarPago');

    // Campos del formulario
    const inputPagoId = document.getElementById('pagoId');
    const selectPrestamo = document.getElementById('prestamo');
    const inputMontoPagado = document.getElementById('montoPagado');
    const inputFechaPago = document.getElementById('fechaPago');
    const selectMetodo = document.getElementById('metodo');

    let modoFormulario = 'nuevo';
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
    // MODAL DEL FORMULARIO
    // =========================================
    function abrirFormulario(modo = 'nuevo', datos = null) {
        modoFormulario = modo;
        formPago.reset();

        if (modo === 'nuevo') {
            tituloFormPago.textContent = 'Registrar Pago';
            btnGuardarPago.innerHTML = '<ion-icon name="save-outline"></ion-icon> Guardar Pago';
            inputPagoId.value = '';
            // Fecha por defecto: hoy
            inputFechaPago.valueAsDate = new Date();
        } else if (modo === 'editar' && datos) {
            tituloFormPago.textContent = 'Editar Pago';
            btnGuardarPago.innerHTML = '<ion-icon name="save-outline"></ion-icon> Actualizar Pago';
            inputPagoId.value = datos.id || '';
            selectPrestamo.value = datos.prestamo_id || '';
            inputMontoPagado.value = datos.monto_pagado || '';
            inputFechaPago.value = datos.fecha_pago ? datos.fecha_pago.split('T')[0] : '';
            selectMetodo.value = datos.metodo || '';
        }

        // Actualizamos el placeholder de los selects
        actualizarPlaceholders();
        modalFormPago.classList.add('active');
    }

    function cerrarFormulario() {
        modalFormPago.classList.remove('active');
        formPago.reset();
    }

    cerrarFormPago.addEventListener('click', cerrarFormulario);
    btnCancelarForm.addEventListener('click', cerrarFormulario);

    modalFormPago.addEventListener('click', (e) => {
        if (e.target === modalFormPago) cerrarFormulario();
    });

    // =========================================
    // MANEJO DEL PLACEHOLDER DE LOS SELECTS
    // =========================================
    function actualizarPlaceholders() {
        [selectPrestamo, selectMetodo].forEach(select => {
            if (!select.value || select.value === '') {
                select.classList.add('placeholder-activo');
            } else {
                select.classList.remove('placeholder-activo');
            }
        });
    }

    [selectPrestamo, selectMetodo].forEach(select => {
        select.addEventListener('focus', () => {
            select.classList.remove('placeholder-activo');
        });

        select.addEventListener('change', actualizarPlaceholders);

        select.addEventListener('blur', () => {
            setTimeout(actualizarPlaceholders, 100);
        });
    });

    // =========================================
    // CARGAR PRÉSTAMOS EN EL SELECT
    // =========================================
    async function cargarPrestamosEnSelect() {
        console.log('📋 [API] GET ' + ENDPOINTS.prestamos);

        if (MODO_SIMULACION) {
            const prestamosEjemplo = [
                { id: 1, descripcion: '#001 - Cliente Ejemplo' },
                { id: 2, descripcion: '#002 - Juan Pérez' },
                { id: 3, descripcion: '#003 - María Gómez' }
            ];
            llenarSelectPrestamos(prestamosEjemplo);
            return;
        }

        const { ok, data } = await peticionAPI(ENDPOINTS.prestamos);
        if (ok && data.success) {
            const prestamos = data.datos.map(p => ({
                id: p.id,
                descripcion: `#${String(p.id).padStart(3, '0')} - ${p.cliente_nombre || 'Cliente'}`
            }));
            llenarSelectPrestamos(prestamos);
        }
    }

    function llenarSelectPrestamos(prestamos) {
        selectPrestamo.innerHTML = '<option value="" disabled selected>Seleccione un préstamo</option>';

        prestamos.forEach(prestamo => {
            const option = document.createElement('option');
            option.value = prestamo.id;
            option.textContent = prestamo.descripcion;
            selectPrestamo.appendChild(option);
        });

        actualizarPlaceholders();
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
    // 1. CARGAR PAGOS
    // =========================================
    async function cargarPagos() {
        console.log('📋 [API] GET ' + ENDPOINTS.listar);
        mostrarModal('Cargando...', 'Obteniendo la lista de pagos...');

        if (MODO_SIMULACION) {
            setTimeout(() => {
                cerrarModal();
                renderizarPagos([]);
            }, 800);
            return;
        }

        const { ok, data } = await peticionAPI(ENDPOINTS.listar);
        cerrarModal();

        if (ok && data.success) {
            renderizarPagos(data.datos || []);
        } else {
            mostrarModal('Error', data.message || 'No se pudieron cargar los pagos.');
        }
    }

    // =========================================
    // 2. RENDERIZAR PAGOS EN LA TABLA
    // =========================================
    function renderizarPagos(pagos) {
        tbodyPagos.innerHTML = '';

        if (!pagos || pagos.length === 0) {
            const row = document.createElement('tr');
            row.innerHTML = `<td colspan="6" class="tabla-vacia">No hay pagos registrados todavía</td>`;
            tbodyPagos.appendChild(row);
            return;
        }

        pagos.forEach(pago => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>#${String(pago.id).padStart(5, '0')}</td>
                <td>#${String(pago.prestamo_id).padStart(3, '0')}</td>
                <td>${pago.cliente_nombre || 'Cliente'}</td>
                <td>$${Number(pago.monto_pagado).toLocaleString('es-CO')}</td>
                <td>${new Date(pago.fecha_pago).toLocaleDateString('es-CO')}</td>
                <td>${pago.metodo}</td>
            `;
            tbodyPagos.appendChild(row);
        });
    }

    // =========================================
    // 3. NUEVO PAGO
    // =========================================
    if (btnNuevoPago) {
        btnNuevoPago.addEventListener('click', async () => {
            console.log('➕ Abriendo formulario para nuevo pago');
            await cargarPrestamosEnSelect();
            abrirFormulario('nuevo');
        });
    }

    // =========================================
    // 4. GUARDAR / ACTUALIZAR PAGO
    // =========================================
    formPago.addEventListener('submit', async (e) => {
        e.preventDefault();

        const datos = {
            prestamo_id: selectPrestamo.value,
            monto_pagado: inputMontoPagado.value.trim(),
            fecha_pago: inputFechaPago.value,
            metodo: selectMetodo.value
        };

        const camposVacios = Object.keys(datos).filter(k => !datos[k]);
        if (camposVacios.length > 0) {
            mostrarModal('Campos Incompletos', 'Por favor complete todos los campos.');
            return;
        }

        if (parseFloat(datos.monto_pagado) <= 0) {
            mostrarModal('Monto Inválido', 'El monto debe ser mayor a 0.');
            return;
        }

        const esEdicion = modoFormulario === 'editar';
        const id = inputPagoId.value;

        cerrarFormulario();
        mostrarModal(esEdicion ? 'Actualizando...' : 'Guardando...', 'Enviando datos al servidor...');

        if (MODO_SIMULACION) {
            setTimeout(() => {
                cerrarModal();
                mostrarModal(
                    esEdicion ? '¡Pago Actualizado!' : '¡Pago Registrado!',
                    `El pago se ha ${esEdicion ? 'actualizado' : 'guardado'} correctamente (simulado).`
                );
            }, 1000);
            return;
        }

        const url = esEdicion ? ENDPOINTS.actualizar(id) : ENDPOINTS.crear;
        const metodo = esEdicion ? 'PUT' : 'POST';

        const { ok, data } = await peticionAPI(url, {
            method: metodo,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(datos)
        });

        cerrarModal();

        if (ok && data.success) {
            mostrarModal(
                esEdicion ? '¡Pago Actualizado!' : '¡Pago Registrado!',
                data.message || 'Operación exitosa.',
                () => cargarPagos()
            );
        } else {
            mostrarModal('Error', data.message || 'No se pudo guardar el pago.');
        }
    });

    // =========================================
    // 5. INICIALIZAR
    // =========================================
    cargarPagos();

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