document.addEventListener('DOMContentLoaded', function () {
    var tbody = document.getElementById('tbodyClientes');
    var formulario = document.getElementById('formCliente');
    var modalFormulario = document.getElementById('modalFormCliente');
    var modalMensaje = document.getElementById('modalOverlay');
    var modalTitulo = document.getElementById('modalTitle');
    var modalTexto = document.getElementById('modalMessage');
    var modalBoton = document.getElementById('modalBtn');
    var clienteId = document.getElementById('clienteId');
    var modo = 'nuevo';
    var accionModal = null;

    function mostrarMensaje(titulo, mensaje, accion) {
        modalTitulo.textContent = titulo;
        modalTexto.textContent = mensaje;
        modalMensaje.classList.add('active');
        accionModal = accion || null;
    }

    function cerrarMensaje() {
        modalMensaje.classList.remove('active');
        accionModal = null;
    }

    modalBoton.addEventListener('click', function () {
        var accion = accionModal;
        cerrarMensaje();
        if (accion) accion();
    });
    modalMensaje.addEventListener('click', function (evento) {
        if (evento.target === modalMensaje) cerrarMensaje();
    });

    async function peticion(url, opciones) {
        var respuesta = await fetch(url, opciones || {});
        var datos = await respuesta.json();
        if (!respuesta.ok || !datos.success) throw new Error(datos.message || 'No se pudo completar la operación.');
        return datos;
    }

    function mostrarUsuario() {
        try {
            var usuario = JSON.parse(localStorage.getItem('usuario') || 'null');
            if (!usuario) return;
            var nombre = (usuario.nombre || '') + ' ' + (usuario.apellido || '');
            var elemento = document.querySelector('.user-name');
            var pie = document.querySelector('.logged-user');
            if (elemento) elemento.textContent = nombre.trim();
            if (pie) pie.textContent = nombre.trim();
        } catch (error) { }
    }

    function cerrarFormulario() {
        modalFormulario.classList.remove('active');
        formulario.reset();
        clienteId.value = '';
    }

    function abrirFormulario(tipo, cliente) {
        modo = tipo;
        formulario.reset();
        var estaEditando = tipo === 'editar';
        clienteId.value = estaEditando ? cliente.id : '';
        document.getElementById('tituloFormCliente').textContent = estaEditando ? 'Editar Cliente' : 'Nuevo Cliente';
        document.getElementById('btnGuardarCliente').innerHTML = estaEditando ? '<ion-icon name="save-outline"></ion-icon> Actualizar Cliente' : '<ion-icon name="save-outline"></ion-icon> Crear cuenta de cliente';
        formulario.querySelectorAll('[data-solo-creacion]').forEach(function (grupo) {
            grupo.hidden = estaEditando;
            grupo.querySelectorAll('input').forEach(function (campo) { campo.required = !estaEditando; });
        });
        if (estaEditando) {
            document.getElementById('cedula').value = cliente.cedula || '';
            document.getElementById('nombre').value = cliente.nombre || '';
            document.getElementById('apellido').value = cliente.apellido || '';
            document.getElementById('telefono').value = cliente.telefono || '';
            document.getElementById('correo').value = cliente.correo || '';
            document.getElementById('direccion').value = cliente.direccion || '';
        document.getElementById('sueldo').value = cliente.sueldo || 0;
        }
        modalFormulario.classList.add('active');
    }

    async function cargarClientes() {
        tbody.innerHTML = '<tr><td colspan="6" class="tabla-vacia">Cargando clientes...</td></tr>';
        try {
            var resultado = await peticion('php/api.php?recurso=clientes');
            renderizarClientes(resultado.datos || []);
        } catch (error) {
            tbody.innerHTML = '<tr><td colspan="6" class="tabla-vacia">' + error.message + '</td></tr>';
        }
    }

    function renderizarClientes(clientes) {
        tbody.innerHTML = '';
        if (clientes.length === 0) {
            tbody.innerHTML = '<tr><td colspan="6" class="tabla-vacia">No hay clientes activos registrados.</td></tr>';
            return;
        }
        clientes.forEach(function (cliente) {
            var fila = document.createElement('tr');
            [cliente.cedula, (cliente.nombre || '') + ' ' + (cliente.apellido || ''), cliente.telefono, cliente.correo, Number(cliente.sueldo || 0).toLocaleString('es-DO', { style: 'currency', currency: 'DOP' })].forEach(function (valor) {
                var celda = document.createElement('td');
                celda.textContent = valor || '';
                fila.appendChild(celda);
            });
            var acciones = document.createElement('td');
            acciones.className = 'acciones-cell';
            var editar = document.createElement('button');
            editar.type = 'button';
            editar.className = 'btn-accion btn-editar';
            editar.dataset.id = cliente.id;
            editar.title = 'Editar';
            editar.innerHTML = '<ion-icon name="create-outline"></ion-icon>';
            var desactivar = document.createElement('button');
            desactivar.type = 'button';
            desactivar.className = 'btn-accion btn-eliminar';
            desactivar.dataset.id = cliente.id;
            desactivar.title = 'Desactivar cuenta';
            desactivar.innerHTML = '<ion-icon name="person-remove-outline"></ion-icon>';
            acciones.appendChild(editar);
            acciones.appendChild(desactivar);
            fila.appendChild(acciones);
            tbody.appendChild(fila);
        });
    }

    async function editarCliente(id) {
        try {
            var respuesta = await peticion('php/api.php?recurso=clientes&id=' + encodeURIComponent(id));
            abrirFormulario('editar', respuesta.cliente);
        } catch (error) {
            mostrarMensaje('No se pudo abrir el cliente', error.message);
        }
    }

    async function desactivarCliente(id) {
        mostrarMensaje('Desactivar cliente', 'La cuenta se desactivará y dejará de aparecer en la lista. ¿Desea continuar?', async function () {
            try {
                await peticion('php/api.php?recurso=clientes&id=' + encodeURIComponent(id), { method: 'DELETE' });
                await cargarClientes();
                mostrarMensaje('Cuenta desactivada', 'El cliente ya no podrá iniciar sesión.');
            } catch (error) {
                mostrarMensaje('No se pudo desactivar', error.message);
            }
        });
    }

    document.getElementById('btnNuevoCliente').addEventListener('click', function () { abrirFormulario('nuevo', null); });
    document.getElementById('cerrarFormCliente').addEventListener('click', cerrarFormulario);
    document.getElementById('btnCancelarForm').addEventListener('click', cerrarFormulario);
    modalFormulario.addEventListener('click', function (evento) { if (evento.target === modalFormulario) cerrarFormulario(); });
    tbody.addEventListener('click', function (evento) {
        var boton = evento.target.closest('button[data-id]');
        if (!boton) return;
        if (boton.classList.contains('btn-editar')) editarCliente(boton.dataset.id);
        if (boton.classList.contains('btn-eliminar')) desactivarCliente(boton.dataset.id);
    });

    formulario.addEventListener('submit', async function (evento) {
        evento.preventDefault();
        var datos = {
            cedula: document.getElementById('cedula').value.trim(),
            nombre: document.getElementById('nombre').value.trim(),
            apellido: document.getElementById('apellido').value.trim(),
            telefono: document.getElementById('telefono').value.trim(),
            correo: document.getElementById('correo').value.trim(),
            direccion: document.getElementById('direccion').value.trim(),
            sueldo: document.getElementById('sueldo').value
        };
        var creando = modo === 'nuevo';
        if (creando) {
            datos.pais = document.getElementById('pais').value.trim();
            datos.provincia = document.getElementById('provincia').value.trim();
            datos.ciudad = document.getElementById('ciudad').value.trim();
            datos.contrasena = document.getElementById('contrasenaCliente').value;
        }
        var url = creando ? 'php/api.php?recurso=clientes' : 'php/api.php?recurso=clientes&id=' + encodeURIComponent(clienteId.value);
        var metodo = creando ? 'POST' : 'PUT';
        try {
            document.getElementById('btnGuardarCliente').disabled = true;
            await peticion(url, { method: metodo, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(datos) });
            cerrarFormulario();
            await cargarClientes();
            mostrarMensaje(creando ? 'Cliente creado' : 'Cliente actualizado', creando ? 'La cuenta ya puede iniciar sesión con el correo y contraseña definidos.' : 'Los datos del cliente se guardaron.');
        } catch (error) {
            mostrarMensaje('No se pudo guardar', error.message);
        } finally {
            document.getElementById('btnGuardarCliente').disabled = false;
        }
    });

    var menuToggle = document.querySelector('.menu-toggle');
    var sidebar = document.querySelector('.sidebar');
    if (menuToggle && sidebar) menuToggle.addEventListener('click', function () { sidebar.classList.toggle('open'); });

    var logoutLink = document.querySelector('.logout-link');
    if (logoutLink) logoutLink.addEventListener('click', function (evento) {
        evento.preventDefault();
        mostrarMensaje('Cerrar sesión', '¿Desea cerrar su sesión?', function () {
            fetch('php/api.php?recurso=cerrar-sesion', { method: 'POST', keepalive: true });
            localStorage.removeItem('usuario');
            window.location.href = 'sesion-cerrada.php';
        });
    });

    mostrarUsuario();
    cargarClientes();
});