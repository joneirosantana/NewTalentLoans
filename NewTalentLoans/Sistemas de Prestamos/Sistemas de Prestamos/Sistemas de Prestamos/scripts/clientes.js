// ==========================================================
// SISTEMA DE GESTIÓN DE CLIENTES - New Talent Loans
// ==========================================================

document.addEventListener('DOMContentLoaded', () => {

    // ==========================================================
    // 🔌 CONFIGURACIÓN DEL BACKEND
    // ==========================================================
    const API_URL = 'http://localhost:3000';

    const ENDPOINTS = {
        listar:     `${API_URL}/api/clientes`,
        obtener:    (id) => `${API_URL}/api/clientes/${id}`,
        crear:      `${API_URL}/api/clientes`,
        actualizar: (id) => `${API_URL}/api/clientes/${id}`,
        eliminar:   (id) => `${API_URL}/api/clientes/${id}`
    };

    // 👇 Cambia a FALSE cuando tengas tu backend listo
    const MODO_SIMULACION = true;

    // =========================================
    // REFERENCIAS DEL DOM
    // =========================================
    const btnNuevoCliente = document.getElementById('btnNuevoCliente');
    const tbodyClientes = document.getElementById('tbodyClientes');

    // Modal de mensajes
    const modalOverlay = document.getElementById('modalOverlay');
    const modalTitle = document.getElementById('modalTitle');
    const modalMessage = document.getElementById('modalMessage');
    const modalBtn = document.getElementById('modalBtn');

    // Modal con formulario
    const modalFormCliente = document.getElementById('modalFormCliente');
    const cerrarFormCliente = document.getElementById('cerrarFormCliente');
    const btnCancelarForm = document.getElementById('btnCancelarForm');
    const formCliente = document.getElementById('formCliente');
    const tituloFormCliente = document.getElementById('tituloFormCliente');
    const btnGuardarCliente = document.getElementById('btnGuardarCliente');

    // Campos del formulario
    const inputClienteId = document.getElementById('clienteId');
    const inputCedula = document.getElementById('cedula');
    const inputNombre = document.getElementById('nombre');
    const inputApellido = document.getElementById('apellido');
    const inputTelefono = document.getElementById('telefono');
    const inputCorreo = document.getElementById('correo');
    const inputDireccion = document.getElementById('direccion');

    let modoFormulario = 'nuevo';

    // Variable global para saber qué hace el botón del modal
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

    // Mostrar nombre del usuario logueado
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
    // SISTEMA DE MODAL (Función unificada)
    // =========================================
    // Función que muestra el modal y define qué hace el botón Aceptar
    function mostrarModal(titulo, mensaje, accionAceptar = null) {
        modalTitle.textContent = titulo;
        modalMessage.textContent = mensaje;
        modalOverlay.classList.add('active');

        // Guardamos la acción que ejecutará el botón
        accionModalActual = accionAceptar;
    }

    function cerrarModal() {
        modalOverlay.classList.remove('active');
        accionModalActual = null;
    }

    // El botón Aceptar del modal SIEMPRE ejecuta esto
    // (se registra una sola vez)
    modalBtn.addEventListener('click', () => {
        const accion = accionModalActual;
        cerrarModal();
        if (accion) accion();
    });

    // Cerrar el modal al hacer clic fuera
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
                    // Esta función se ejecuta al hacer clic en "Aceptar"
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
        formCliente.reset();

        if (modo === 'nuevo') {
            tituloFormCliente.textContent = 'Nuevo Cliente';
            btnGuardarCliente.innerHTML = '<ion-icon name="save-outline"></ion-icon> Guardar Cliente';
            inputClienteId.value = '';
        } else if (modo === 'editar' && datos) {
            tituloFormCliente.textContent = 'Editar Cliente';
            btnGuardarCliente.innerHTML = '<ion-icon name="save-outline"></ion-icon> Actualizar Cliente';
            inputClienteId.value = datos.id || '';
            inputCedula.value = datos.cedula || '';
            inputNombre.value = datos.nombre || '';
            inputApellido.value = datos.apellido || '';
            inputTelefono.value = datos.telefono || '';
            inputCorreo.value = datos.correo || '';
            inputDireccion.value = datos.direccion || '';
        }

        modalFormCliente.classList.add('active');
    }

    function cerrarFormulario() {
        modalFormCliente.classList.remove('active');
        formCliente.reset();
    }

    cerrarFormCliente.addEventListener('click', cerrarFormulario);
    btnCancelarForm.addEventListener('click', cerrarFormulario);

    modalFormCliente.addEventListener('click', (e) => {
        if (e.target === modalFormCliente) cerrarFormulario();
    });

    // =========================================
    // FUNCIÓN AUXILIAR: PETICIÓN A LA API
    // =========================================
    async function peticionAPI(url, opciones = {}) {
        try {
            // 🔐 Descomenta cuando tengas JWT:
            // const token = localStorage.getItem('token');
            // opciones.headers = {
            //     ...opciones.headers,
            //     'Authorization': `Bearer ${token}`
            // };

            const response = await fetch(url, opciones);
            const data = await response.json();
            return { ok: response.ok, status: response.status, data };
        } catch (error) {
            console.error('❌ Error en la petición:', error);
            return { ok: false, status: 0, data: { message: 'Error de conexión con el servidor' } };
        }
    }

    // =========================================
    // 1. CARGAR CLIENTES
    // =========================================
    async function cargarClientes() {
        console.log('📋 [API] GET ' + ENDPOINTS.listar);
        mostrarModal('Cargando...', 'Obteniendo la lista de clientes...');

        if (MODO_SIMULACION) {
            setTimeout(() => {
                cerrarModal();
                renderizarClientes([]);
            }, 800);
            return;
        }

        const { ok, data } = await peticionAPI(ENDPOINTS.listar);
        cerrarModal();

        if (ok && data.success) {
            renderizarClientes(data.datos || []);
        } else {
            mostrarModal('Error', data.message || 'No se pudieron cargar los clientes.');
        }
    }

    // =========================================
    // 2. RENDERIZAR CLIENTES
    // =========================================
    function renderizarClientes(clientes) {
        tbodyClientes.innerHTML = '';

        if (!clientes || clientes.length === 0) {
            const row = document.createElement('tr');
            row.innerHTML = `<td colspan="5" class="tabla-vacia">No hay clientes registrados todavía</td>`;
            tbodyClientes.appendChild(row);
            return;
        }

        clientes.forEach(cliente => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>${cliente.cedula}</td>
                <td>${cliente.nombre} ${cliente.apellido}</td>
                <td>${cliente.telefono}</td>
                <td>${cliente.correo}</td>
                <td>
                    <div class="acciones-cell">
                        <button class="btn-accion btn-editar" data-id="${cliente.id}" title="Editar">
                            <ion-icon name="create-outline"></ion-icon>
                        </button>
                        <button class="btn-accion btn-eliminar" data-id="${cliente.id}" title="Eliminar">
                            <ion-icon name="trash-outline"></ion-icon>
                        </button>
                    </div>
                </td>
            `;
            tbodyClientes.appendChild(row);
        });

        document.querySelectorAll('.btn-editar').forEach(btn => {
            btn.addEventListener('click', () => editarCliente(btn.dataset.id));
        });

        document.querySelectorAll('.btn-eliminar').forEach(btn => {
            btn.addEventListener('click', () => eliminarCliente(btn.dataset.id));
        });
    }

    // =========================================
    // 3. NUEVO CLIENTE
    // =========================================
    if (btnNuevoCliente) {
        btnNuevoCliente.addEventListener('click', () => {
            console.log('➕ Abriendo formulario para nuevo cliente');
            abrirFormulario('nuevo');
        });
    }

    // =========================================
    // 4. GUARDAR / ACTUALIZAR CLIENTE
    // =========================================
    formCliente.addEventListener('submit', async (e) => {
        e.preventDefault();

        const datos = {
            cedula: inputCedula.value.trim(),
            nombre: inputNombre.value.trim(),
            apellido: inputApellido.value.trim(),
            telefono: inputTelefono.value.trim(),
            correo: inputCorreo.value.trim(),
            direccion: inputDireccion.value.trim()
        };

        const camposVacios = Object.keys(datos).filter(k => !datos[k]);
        if (camposVacios.length > 0) {
            mostrarModal('Campos Incompletos', 'Por favor complete todos los campos.');
            return;
        }

        const regexCorreo = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!regexCorreo.test(datos.correo)) {
            mostrarModal('Correo Inválido', 'Ingrese un correo electrónico válido.');
            return;
        }

        const esEdicion = modoFormulario === 'editar';
        const id = inputClienteId.value;

        cerrarFormulario();
        mostrarModal(esEdicion ? 'Actualizando...' : 'Guardando...', 'Enviando datos al servidor...');

        if (MODO_SIMULACION) {
            setTimeout(() => {
                cerrarModal();
                mostrarModal(
                    esEdicion ? '¡Cliente Actualizado!' : '¡Cliente Registrado!',
                    `El cliente ${datos.nombre} ${datos.apellido} se ha ${esEdicion ? 'actualizado' : 'guardado'} correctamente (simulado).`
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
                esEdicion ? '¡Cliente Actualizado!' : '¡Cliente Registrado!',
                data.message || 'Operación exitosa.',
                () => cargarClientes()
            );
        } else {
            mostrarModal('Error', data.message || 'No se pudo guardar el cliente.');
        }
    });

    // =========================================
    // 5. EDITAR CLIENTE
    // =========================================
    async function editarCliente(id) {
        console.log(`✏️ [API] GET ${ENDPOINTS.obtener(id)}`);
        mostrarModal('Cargando...', `Obteniendo datos del cliente #${id}...`);

        if (MODO_SIMULACION) {
            setTimeout(() => {
                cerrarModal();
                abrirFormulario('editar', {
                    id: id,
                    cedula: '1234567890',
                    nombre: 'Cliente',
                    apellido: 'Ejemplo',
                    telefono: '3001234567',
                    correo: 'cliente@ejemplo.com',
                    direccion: 'Calle 123 #45-67'
                });
            }, 800);
            return;
        }

        const { ok, data } = await peticionAPI(ENDPOINTS.obtener(id));
        cerrarModal();

        if (ok && data.success) {
            abrirFormulario('editar', data.cliente);
        } else {
            mostrarModal('Error', data.message || 'No se pudo obtener el cliente.');
        }
    }

    // =========================================
    // 6. ELIMINAR CLIENTE
    // =========================================
    function eliminarCliente(id) {
        console.log(`🗑️ [API] DELETE ${ENDPOINTS.eliminar(id)}`);

        mostrarModal(
            'Eliminar Cliente',
            '¿Estás seguro de que deseas eliminar este cliente?',
            async () => {
                mostrarModal('Eliminando...', `Eliminando el cliente #${id}...`);

                if (MODO_SIMULACION) {
                    setTimeout(() => {
                        cerrarModal();
                        mostrarModal('Cliente Eliminado', `El cliente #${id} ha sido eliminado (simulado).`);
                    }, 800);
                    return;
                }

                const { ok, data } = await peticionAPI(ENDPOINTS.eliminar(id), {
                    method: 'DELETE'
                });

                cerrarModal();

                if (ok && data.success) {
                    mostrarModal(
                        '¡Cliente Eliminado!',
                        data.message || 'El cliente ha sido eliminado correctamente.',
                        () => cargarClientes()
                    );
                } else {
                    mostrarModal('Error', data.message || 'No se pudo eliminar el cliente.');
                }
            }
        );
    }

    // =========================================
    // 7. INICIALIZAR
    // =========================================
    cargarClientes();

    // =========================================
    // 8. CERRAR MODALES CON ESC
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