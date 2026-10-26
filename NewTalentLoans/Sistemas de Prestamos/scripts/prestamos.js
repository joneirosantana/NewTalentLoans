// ==========================================================
// SISTEMA DE GESTIÓN DE PRÉSTAMOS - New Talent Loans
// ==========================================================

document.addEventListener('DOMContentLoaded', () => {

    // ==========================================================
    // 🔌 CONFIGURACIÓN DEL BACKEND
    // ==========================================================
    const API_URL = 'http://localhost:3000';

    const ENDPOINTS = {
        listar:     `${API_URL}/api/prestamos`,
        obtener:    (id) => `${API_URL}/api/prestamos/${id}`,
        crear:      `${API_URL}/api/prestamos`,
        actualizar: (id) => `${API_URL}/api/prestamos/${id}`,
        eliminar:   (id) => `${API_URL}/api/prestamos/${id}`,
        clientes:   `${API_URL}/api/clientes`
    };

    // 👇 Cambia a FALSE cuando tengas tu backend listo
    const MODO_SIMULACION = true;

    // =========================================
    // REFERENCIAS DEL DOM
    // =========================================
    const btnNuevoPrestamo = document.getElementById('btnNuevoPrestamo');
    const tbodyPrestamos = document.getElementById('tbodyPrestamos');

    // Modal de mensajes
    const modalOverlay = document.getElementById('modalOverlay');
    const modalTitle = document.getElementById('modalTitle');
    const modalMessage = document.getElementById('modalMessage');
    const modalBtn = document.getElementById('modalBtn');

    // Modal con formulario
    const modalFormPrestamo = document.getElementById('modalFormPrestamo');
    const cerrarFormPrestamo = document.getElementById('cerrarFormPrestamo');
    const btnCancelarForm = document.getElementById('btnCancelarForm');
    const formPrestamo = document.getElementById('formPrestamo');
    const tituloFormPrestamo = document.getElementById('tituloFormPrestamo');
    const btnGuardarPrestamo = document.getElementById('btnGuardarPrestamo');

    // Campos del formulario
    const inputPrestamoId = document.getElementById('prestamoId');
    const selectCliente = document.getElementById('cliente');
    const inputMonto = document.getElementById('monto');
    const inputInteres = document.getElementById('interes');
    const inputPlazo = document.getElementById('plazo');
    const inputCuotaMensual = document.getElementById('cuotaMensual');
    const selectEstado = document.getElementById('estado');

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

    // Nombre del usuario
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
    // MODAL DEL FORMULARIO
    // =========================================
    function abrirFormulario(modo = 'nuevo', datos = null) {
        modoFormulario = modo;
        formPrestamo.reset();

        if (modo === 'nuevo') {
            tituloFormPrestamo.textContent = 'Nuevo Préstamo';
            btnGuardarPrestamo.innerHTML = '<ion-icon name="save-outline"></ion-icon> Guardar Préstamo';
            inputPrestamoId.value = '';
            selectEstado.value = 'activo';
            selectCliente.value = '';
            // 👇 Activar el placeholder del cliente
            selectCliente.classList.add('placeholder-activo');
        } else if (modo === 'editar' && datos) {
            tituloFormPrestamo.textContent = 'Editar Préstamo';
            btnGuardarPrestamo.innerHTML = '<ion-icon name="save-outline"></ion-icon> Actualizar Préstamo';
            inputPrestamoId.value = datos.id || '';
            selectCliente.value = datos.cliente_id || '';
            inputMonto.value = datos.monto || '';
            inputInteres.value = datos.interes || '';
            inputPlazo.value = datos.plazo || '';
            inputCuotaMensual.value = datos.cuota_mensual || '';
            selectEstado.value = datos.estado || 'activo';
            // Quitar el placeholder si hay valor
            selectCliente.classList.remove('placeholder-activo');
        }

        modalFormPrestamo.classList.add('active');
    }

    function cerrarFormulario() {
        modalFormPrestamo.classList.remove('active');
        formPrestamo.reset();
    }

    cerrarFormPrestamo.addEventListener('click', cerrarFormulario);
    btnCancelarForm.addEventListener('click', cerrarFormulario);

    modalFormPrestamo.addEventListener('click', (e) => {
        if (e.target === modalFormPrestamo) cerrarFormulario();
    });

    // =========================================
    // CALCULAR CUOTA MENSUAL AUTOMÁTICAMENTE
    // =========================================
    function calcularCuota() {
        const monto = parseFloat(inputMonto.value) || 0;
        const interes = parseFloat(inputInteres.value) || 0;
        const plazo = parseInt(inputPlazo.value) || 0;

        if (monto > 0 && plazo > 0) {
            const interesMensual = interes / 100;
            const totalInteres = monto * interesMensual * plazo;
            const totalPagar = monto + totalInteres;
            const cuota = totalPagar / plazo;
            inputCuotaMensual.value = cuota.toFixed(2);
        } else {
            inputCuotaMensual.value = '';
        }
    }

    inputMonto.addEventListener('input', calcularCuota);
    inputInteres.addEventListener('input', calcularCuota);
    inputPlazo.addEventListener('input', calcularCuota);

    // =========================================
    // CARGAR CLIENTES EN EL SELECT
    // =========================================
    async function cargarClientesEnSelect() {
        console.log('📋 [API] GET ' + ENDPOINTS.clientes);

        if (MODO_SIMULACION) {
            // 🔸 Clientes de ejemplo
            const clientesEjemplo = [
                { id: 1, nombre: 'Cliente', apellido: 'Ejemplo' },
                { id: 2, nombre: 'Juan', apellido: 'Pérez' },
                { id: 3, nombre: 'María', apellido: 'Gómez' }
            ];
            llenarSelectClientes(clientesEjemplo);
            return;
        }

        // 🔌 REAL
        const { ok, data } = await peticionAPI(ENDPOINTS.clientes);
        if (ok && data.success) {
            llenarSelectClientes(data.datos || []);
        }
    }

    function llenarSelectClientes(clientes) {
        // Limpiamos el select
        selectCliente.innerHTML = '<option value=""></option>';

        clientes.forEach(cliente => {
            const option = document.createElement('option');
            option.value = cliente.id;
            option.textContent = `${cliente.nombre} ${cliente.apellido}`;
            selectCliente.appendChild(option);
        });

        // 👇 MUY IMPORTANTE: Activar el placeholder
        selectCliente.value = '';
        selectCliente.classList.add('placeholder-activo');
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
    // 1. CARGAR PRÉSTAMOS
    // =========================================
    async function cargarPrestamos() {
        console.log('📋 [API] GET ' + ENDPOINTS.listar);
        mostrarModal('Cargando...', 'Obteniendo la lista de préstamos...');

        if (MODO_SIMULACION) {
            setTimeout(() => {
                cerrarModal();
                renderizarPrestamos([]);
            }, 800);
            return;
        }

        const { ok, data } = await peticionAPI(ENDPOINTS.listar);
        cerrarModal();

        if (ok && data.success) {
            renderizarPrestamos(data.datos || []);
        } else {
            mostrarModal('Error', data.message || 'No se pudieron cargar los préstamos.');
        }
    }

    // =========================================
    // 2. RENDERIZAR PRÉSTAMOS EN LA TABLA
    // =========================================
    function renderizarPrestamos(prestamos) {
        tbodyPrestamos.innerHTML = '';

        if (!prestamos || prestamos.length === 0) {
            const row = document.createElement('tr');
            row.innerHTML = `<td colspan="7" class="tabla-vacia">No hay préstamos registrados todavía</td>`;
            tbodyPrestamos.appendChild(row);
            return;
        }

        prestamos.forEach(prestamo => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>#${prestamo.id}</td>
                <td>${prestamo.cliente_nombre || 'Cliente'}</td>
                <td>$${Number(prestamo.monto).toLocaleString('es-CO')}</td>
                <td>${prestamo.interes}%</td>
                <td>${prestamo.plazo}</td>
                <td>$${Number(prestamo.cuota_mensual).toLocaleString('es-CO')}</td>
                <td>
                    <span class="estado-badge estado-${prestamo.estado}">
                        ${prestamo.estado}
                    </span>
                </td>
            `;
            tbodyPrestamos.appendChild(row);
        });
    }

    // =========================================
    // 3. NUEVO PRÉSTAMO
    // =========================================
    if (btnNuevoPrestamo) {
        btnNuevoPrestamo.addEventListener('click', async () => {
            console.log('➕ Abriendo formulario para nuevo préstamo');
            await cargarClientesEnSelect();
            abrirFormulario('nuevo');
        });
    }

    // =========================================
    // 4. GUARDAR / ACTUALIZAR PRÉSTAMO
    // =========================================
    formPrestamo.addEventListener('submit', async (e) => {
        e.preventDefault();

        const datos = {
            cliente_id: selectCliente.value,
            monto: inputMonto.value.trim(),
            interes: inputInteres.value.trim(),
            plazo: inputPlazo.value.trim(),
            cuota_mensual: inputCuotaMensual.value.trim(),
            estado: selectEstado.value
        };

        if (!datos.cliente_id || !datos.monto || !datos.interes || !datos.plazo) {
            mostrarModal('Campos Incompletos', 'Por favor complete todos los campos.');
            return;
        }

        const esEdicion = modoFormulario === 'editar';
        const id = inputPrestamoId.value;

        cerrarFormulario();
        mostrarModal(esEdicion ? 'Actualizando...' : 'Guardando...', 'Enviando datos al servidor...');

        if (MODO_SIMULACION) {
            setTimeout(() => {
                cerrarModal();
                mostrarModal(
                    esEdicion ? '¡Préstamo Actualizado!' : '¡Préstamo Registrado!',
                    `El préstamo se ha ${esEdicion ? 'actualizado' : 'guardado'} correctamente (simulado).`
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
                esEdicion ? '¡Préstamo Actualizado!' : '¡Préstamo Registrado!',
                data.message || 'Operación exitosa.',
                () => cargarPrestamos()
            );
        } else {
            mostrarModal('Error', data.message || 'No se pudo guardar el préstamo.');
        }
    });

    // =========================================
    // 5. INICIALIZAR
    // =========================================
    cargarPrestamos();

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