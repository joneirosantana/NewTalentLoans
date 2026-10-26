// ==========================================================
// SISTEMA DE GESTIÓN DE USUARIOS - New Talent Loans
// ==========================================================

document.addEventListener('DOMContentLoaded', () => {

    // ==========================================================
    // 🔌 CONFIGURACIÓN DEL BACKEND
    // ==========================================================
    const API_URL = 'http://localhost:3000';

    const ENDPOINTS = {
        listar:     `${API_URL}/api/usuarios`,
        obtener:    (id) => `${API_URL}/api/usuarios/${id}`,
        crear:      `${API_URL}/api/usuarios`,
        actualizar: (id) => `${API_URL}/api/usuarios/${id}`,
        eliminar:   (id) => `${API_URL}/api/usuarios/${id}`
    };

    // 👇 Cambia a FALSE cuando tengas tu backend listo
    const MODO_SIMULACION = true;

    // =========================================
    // REFERENCIAS DEL DOM
    // =========================================
    const btnNuevoUsuario = document.getElementById('btnNuevoUsuario');
    const tbodyUsuarios = document.getElementById('tbodyUsuarios');

    // Modal de mensajes
    const modalOverlay = document.getElementById('modalOverlay');
    const modalTitle = document.getElementById('modalTitle');
    const modalMessage = document.getElementById('modalMessage');
    const modalBtn = document.getElementById('modalBtn');

    // Modal con formulario
    const modalFormUsuario = document.getElementById('modalFormUsuario');
    const cerrarFormUsuario = document.getElementById('cerrarFormUsuario');
    const btnCancelarForm = document.getElementById('btnCancelarForm');
    const formUsuario = document.getElementById('formUsuario');
    const tituloFormUsuario = document.getElementById('tituloFormUsuario');
    const btnGuardarUsuario = document.getElementById('btnGuardarUsuario');

    // Campos del formulario
    const inputUsuarioId = document.getElementById('usuarioId');
    const inputNombre = document.getElementById('nombre');
    const inputApellido = document.getElementById('apellido');
    const inputCorreo = document.getElementById('correo');
    const inputCedula = document.getElementById('cedula');
    const inputTelefono = document.getElementById('telefono');
    const selectRol = document.getElementById('rol');
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
                    window.location.href = 'CerrarSesionExitoso.html';
                }
            );
        });
    }

    // =========================================
    // MANEJO DE PLACEHOLDER DE LOS SELECTS
    // =========================================
    function actualizarPlaceholders() {
        [selectRol, selectEstado].forEach(select => {
            if (!select.value || select.value === '') {
                select.classList.add('placeholder-activo');
            } else {
                select.classList.remove('placeholder-activo');
            }
        });
    }

    [selectRol, selectEstado].forEach(select => {
        select.addEventListener('focus', () => {
            select.classList.remove('placeholder-activo');
        });

        select.addEventListener('change', actualizarPlaceholders);

        select.addEventListener('blur', () => {
            setTimeout(actualizarPlaceholders, 100);
        });
    });

    // =========================================
    // MODAL DEL FORMULARIO
    // =========================================
    function abrirFormulario(modo = 'nuevo', datos = null) {
        modoFormulario = modo;
        formUsuario.reset();

        if (modo === 'nuevo') {
            tituloFormUsuario.textContent = 'Nuevo Usuario';
            btnGuardarUsuario.innerHTML = '<ion-icon name="save-outline"></ion-icon> Guardar Usuario';
            inputUsuarioId.value = '';
            selectEstado.value = 'activo';
            selectRol.value = '';
        } else if (modo === 'editar' && datos) {
            tituloFormUsuario.textContent = 'Editar Usuario';
            btnGuardarUsuario.innerHTML = '<ion-icon name="save-outline"></ion-icon> Actualizar Usuario';
            inputUsuarioId.value = datos.id || '';
            inputNombre.value = datos.nombre || '';
            inputApellido.value = datos.apellido || '';
            inputCorreo.value = datos.correo || '';
            inputCedula.value = datos.cedula || '';
            inputTelefono.value = datos.telefono || '';
            selectRol.value = datos.rol || '';
            selectEstado.value = datos.estado || 'activo';
        }

        actualizarPlaceholders();
        modalFormUsuario.classList.add('active');
    }

    function cerrarFormulario() {
        modalFormUsuario.classList.remove('active');
        formUsuario.reset();
    }

    cerrarFormUsuario.addEventListener('click', cerrarFormulario);
    btnCancelarForm.addEventListener('click', cerrarFormulario);

    modalFormUsuario.addEventListener('click', (e) => {
        if (e.target === modalFormUsuario) cerrarFormulario();
    });

    // =========================================
    // FUNCIÓN AUXILIAR: PETICIÓN A LA API
    // =========================================
    async function peticionAPI(url, opciones = {}) {
        try {
            const token = localStorage.getItem('token');
            if (token) {
                opciones.headers = {
                    ...opciones.headers,
                    'Authorization': `Bearer ${token}`
                };
            }

            const response = await fetch(url, opciones);
            const data = await response.json();
            return { ok: response.ok, status: response.status, data };
        } catch (error) {
            console.error('❌ Error en la petición:', error);
            return { ok: false, status: 0, data: { message: 'Error de conexión con el servidor' } };
        }
    }

    // =========================================
    // HELPERS: Badges de Rol y Estado
    // =========================================
    function getRolBadge(rol) {
        const rolesMap = {
            'admin': { texto: 'Administrador', clase: 'rol-admin' },
            'gerente': { texto: 'Gerente', clase: 'rol-gerente' },
            'analista': { texto: 'Analista', clase: 'rol-analista' },
            'cajero': { texto: 'Cajero', clase: 'rol-cajero' },
            'auditor': { texto: 'Auditor', clase: 'rol-auditor' },
            'cliente': { texto: 'Cliente', clase: 'rol-cliente' }
        };
        const info = rolesMap[rol] || { texto: rol, clase: 'rol-cliente' };
        return `<span class="rol-badge ${info.clase}">${info.texto}</span>`;
    }

    function getEstadoBadge(estado) {
        const clase = estado === 'activo' ? 'estado-activo' : 'estado-inactivo';
        return `<span class="estado-badge ${clase}">${estado}</span>`;
    }

    // =========================================
    // 1. CARGAR USUARIOS
    // =========================================
    async function cargarUsuarios() {
        console.log('📋 [API] GET ' + ENDPOINTS.listar);
        mostrarModal('Cargando...', 'Obteniendo la lista de usuarios...');

        if (MODO_SIMULACION) {
            setTimeout(() => {
                cerrarModal();
                renderizarUsuarios([]);
            }, 800);
            return;
        }

        const { ok, data } = await peticionAPI(ENDPOINTS.listar);
        cerrarModal();

        if (ok && data.success) {
            renderizarUsuarios(data.datos || []);
        } else {
            mostrarModal('Error', data.message || 'No se pudieron cargar los usuarios.');
        }
    }

    // =========================================
    // 2. RENDERIZAR USUARIOS EN LA TABLA
    // =========================================
    function renderizarUsuarios(usuarios) {
        tbodyUsuarios.innerHTML = '';

        if (!usuarios || usuarios.length === 0) {
            const row = document.createElement('tr');
            row.innerHTML = `<td colspan="6" class="tabla-vacia">No hay usuarios registrados todavía</td>`;
            tbodyUsuarios.appendChild(row);
            return;
        }

        usuarios.forEach(usuario => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>#${usuario.id}</td>
                <td>${usuario.nombre} ${usuario.apellido}</td>
                <td>${usuario.correo}</td>
                <td>${getRolBadge(usuario.rol)}</td>
                <td>${getEstadoBadge(usuario.estado)}</td>
                <td>
                    <div class="acciones-cell">
                        <button class="btn-accion btn-editar" data-id="${usuario.id}" title="Editar">
                            <ion-icon name="create-outline"></ion-icon>
                        </button>
                        <button class="btn-accion btn-eliminar" data-id="${usuario.id}" title="Eliminar">
                            <ion-icon name="trash-outline"></ion-icon>
                        </button>
                    </div>
                </td>
            `;
            tbodyUsuarios.appendChild(row);
        });

        document.querySelectorAll('.btn-editar').forEach(btn => {
            btn.addEventListener('click', () => editarUsuario(btn.dataset.id));
        });

        document.querySelectorAll('.btn-eliminar').forEach(btn => {
            btn.addEventListener('click', () => eliminarUsuario(btn.dataset.id));
        });
    }

    // =========================================
    // 3. NUEVO USUARIO
    // =========================================
    if (btnNuevoUsuario) {
        btnNuevoUsuario.addEventListener('click', () => {
            console.log('➕ Abriendo formulario para nuevo usuario');
            abrirFormulario('nuevo');
        });
    }

    // =========================================
    // 4. GUARDAR / ACTUALIZAR USUARIO
    // =========================================
    formUsuario.addEventListener('submit', async (e) => {
        e.preventDefault();

        const datos = {
            nombre: inputNombre.value.trim(),
            apellido: inputApellido.value.trim(),
            correo: inputCorreo.value.trim(),
            cedula: inputCedula.value.trim(),
            telefono: inputTelefono.value.trim(),
            rol: selectRol.value,
            estado: selectEstado.value
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
        const id = inputUsuarioId.value;

        cerrarFormulario();
        mostrarModal(esEdicion ? 'Actualizando...' : 'Guardando...', 'Enviando datos al servidor...');

        if (MODO_SIMULACION) {
            setTimeout(() => {
                cerrarModal();
                mostrarModal(
                    esEdicion ? '¡Usuario Actualizado!' : '¡Usuario Registrado!',
                    `El usuario se ha ${esEdicion ? 'actualizado' : 'guardado'} correctamente (simulado).`
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
                esEdicion ? '¡Usuario Actualizado!' : '¡Usuario Registrado!',
                data.message || 'Operación exitosa.',
                () => cargarUsuarios()
            );
        } else {
            mostrarModal('Error', data.message || 'No se pudo guardar el usuario.');
        }
    });

    // =========================================
    // 5. EDITAR USUARIO
    // =========================================
    async function editarUsuario(id) {
        console.log(`✏️ [API] GET ${ENDPOINTS.obtener(id)}`);
        mostrarModal('Cargando...', `Obteniendo datos del usuario #${id}...`);

        if (MODO_SIMULACION) {
            setTimeout(() => {
                cerrarModal();
                abrirFormulario('editar', {
                    id: id,
                    nombre: 'Juan',
                    apellido: 'Pérez',
                    correo: 'juan@ejemplo.com',
                    cedula: '1234567890',
                    telefono: '3001234567',
                    rol: 'admin',
                    estado: 'activo'
                });
            }, 800);
            return;
        }

        const { ok, data } = await peticionAPI(ENDPOINTS.obtener(id));
        cerrarModal();

        if (ok && data.success) {
            abrirFormulario('editar', data.usuario);
        } else {
            mostrarModal('Error', data.message || 'No se pudo obtener el usuario.');
        }
    }

    // =========================================
    // 6. ELIMINAR USUARIO
    // =========================================
    function eliminarUsuario(id) {
        console.log(`🗑️ [API] DELETE ${ENDPOINTS.eliminar(id)}`);

        mostrarModal('Eliminar Usuario', '¿Estás seguro de que deseas eliminar este usuario?', async function() {
            
            mostrarModal('Eliminando...', `Eliminando el usuario #${id}...`);

            if (MODO_SIMULACION) {
                setTimeout(() => {
                    cerrarModal();
                    mostrarModal('Usuario Eliminado', `El usuario #${id} ha sido eliminado (simulado).`);
                }, 800);
                return;
            }

            const { ok, data } = await peticionAPI(ENDPOINTS.eliminar(id), {
                method: 'DELETE'
            });

            cerrarModal();

            if (ok && data.success) {
                mostrarModal(
                    '¡Usuario Eliminado!',
                    data.message || 'El usuario ha sido eliminado correctamente.',
                    () => cargarUsuarios()
                );
            } else {
                mostrarModal('Error', data.message || 'No se pudo eliminar el usuario.');
            }
        });
    }

    // =========================================
    // 7. INICIALIZAR
    // =========================================
    cargarUsuarios();

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