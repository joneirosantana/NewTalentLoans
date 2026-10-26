document.addEventListener('DOMContentLoaded', function () {
    var definiciones = {
        'solicitudes': { id: 'Solicitud_ID', campos: ['Solicitud_UsuarioId', 'Solicitud_Fecha', 'Solicitud_Monto', 'Solicitud_Plazo', 'Solicitud_Motivo', 'Solicitud_Estado'], permitirCrear: false },
        'prestamos': { id: 'Prestamo_ID', campos: ['Prestamo_SolicitudId', 'Prestamo_TipoPrestamoId', 'Prestamo_EstadoPrestamoId', 'Prestamo_Monto', 'Prestamo_Tasa', 'Prestamo_Plazo', 'Prestamo_FechaDesembolso', 'Prestamo_Saldo'] },
        'tipos-prestamo': { id: 'TipoPrestamo_ID', campos: ['TipoPrestamo_Nombre', 'TipoPrestamo_TasaBase'] },
        'estados-prestamo': { id: 'EstadoPrestamo_ID', campos: ['EstadoPrestamo_Nombre'] },
        'cuotas': { id: 'Cuota_ID', campos: ['Cuota_PrestamoId', 'Cuota_FechaVencimiento', 'Cuota_Capital', 'Cuota_Interes', 'Cuota_Monto', 'Cuota_Saldo', 'Cuota_Estado'] },
        'pagos': { id: 'Pago_ID', campos: ['Pago_PrestamoId', 'Pago_MetodoPagoId', 'Pago_Fecha', 'Pago_Monto', 'Pago_UsuarioId'] },
        'metodos-pago': { id: 'MetodoPago_ID', campos: ['MetodoPago_Nombre', 'MetodoPago_Descripcion'] },
        'garantes': { id: 'Garante_ID', campos: ['Garante_PrestamoId', 'Garante_Nombre', 'Garante_Cedula', 'Garante_Telefono'] },
        'facturacion': { id: 'Facturacion_ID', campos: ['Facturacion_MetodoPagoId', 'Facturacion_Fecha', 'Facturacion_Monto', 'Facturacion_Descripcion', 'Facturacion_Estado'] }
    };
    var selector = document.getElementById('recurso');
    var formulario = document.getElementById('formularioRegistro');
    var camposFormulario = document.getElementById('camposFormulario');
    var encabezadoTabla = document.getElementById('encabezadoTabla');
    var cuerpoTabla = document.getElementById('cuerpoTabla');
    var estado = document.getElementById('estado');
    var botonGuardar = document.getElementById('guardar');
    var registroActual = null;
    var tiposPrestamo = [];

    var recursoInicial = new URLSearchParams(window.location.search).get('recurso');
    if (recursoInicial && definiciones[recursoInicial]) selector.value = recursoInicial;
    try {
        var usuario = JSON.parse(localStorage.getItem('usuario') || 'null');
        if (usuario) document.getElementById('usuarioActual').textContent = (usuario.nombre || '') + ' ' + (usuario.apellido || '');
    } catch (error) { }

    document.getElementById('cerrarSesion').addEventListener('click', function (evento) {
        evento.preventDefault();
        fetch('php/api.php?recurso=cerrar-sesion', { method: 'POST', keepalive: true });
        localStorage.removeItem('usuario');
        window.location.href = 'index.html';
    });

    function definicionActual() { return definiciones[selector.value]; }

    async function pedir(url, opciones) {
        var respuesta = await fetch(url, opciones || {});
        var contenido = await respuesta.json();
        if (!respuesta.ok || !contenido.success) throw new Error(contenido.message || 'No se pudo completar la operación.');
        return contenido;
    }

    function dibujarFormulario(registro) {
        var definicion = definicionActual();
        camposFormulario.innerHTML = '';
        definicion.campos.forEach(function (campo) {
            var grupo = document.createElement('div');
            grupo.className = 'campo';
            var etiqueta = document.createElement('label');
            etiqueta.htmlFor = 'campo_' + campo;
            etiqueta.textContent = campo;
            var entrada = document.createElement('input');
            entrada.id = 'campo_' + campo;
            entrada.name = campo;
            entrada.type = campo.indexOf('Fecha') >= 0 ? 'date' : 'text';
            entrada.value = registro && registro[campo] !== null && registro[campo] !== undefined ? String(registro[campo]).substring(0, 10) : '';
            grupo.appendChild(etiqueta);
            grupo.appendChild(entrada);
            camposFormulario.appendChild(grupo);
        });
        registroActual = registro ? registro[definicion.id] : null;
        document.getElementById('tituloFormulario').textContent = registroActual ? 'Editar registro #' + registroActual : 'Nuevo registro';
        botonGuardar.textContent = registroActual ? 'Guardar cambios' : 'Crear registro';
        botonGuardar.disabled = !registroActual && definicion.permitirCrear === false;
        if (definicion.permitirCrear === false && !registroActual) {
            document.getElementById('tituloFormulario').textContent = 'Las solicitudes se crean desde el acceso del cliente.';
        }
    }

    function agregarCelda(fila, valor) {
        var celda = document.createElement('td');
        celda.textContent = valor === null || valor === undefined ? '' : String(valor);
        fila.appendChild(celda);
    }

    function dibujarAcciones(fila, registro) {
        var celda = document.createElement('td');
        celda.className = 'acciones-celda';
        if (selector.value === 'solicitudes') {
            if (String(registro.Solicitud_Estado || '').toLowerCase() !== 'pendiente') {
                celda.textContent = 'Solicitud revisada';
            } else {
                var selectorTipo = document.createElement('select');
                selectorTipo.className = 'tipo-aprobacion';
                selectorTipo.setAttribute('aria-label', 'Tipo de préstamo para aprobar');
                var opcionInicial = document.createElement('option');
                opcionInicial.value = '';
                opcionInicial.textContent = 'Tipo de préstamo';
                selectorTipo.appendChild(opcionInicial);
                tiposPrestamo.forEach(function (tipo) {
                    var opcion = document.createElement('option');
                    opcion.value = tipo.TipoPrestamo_ID;
                    opcion.textContent = tipo.TipoPrestamo_Nombre;
                    if (String(tipo.TipoPrestamo_ID) === String(registro.Solicitud_TipoPrestamoId)) opcion.selected = true;
                    selectorTipo.appendChild(opcion);
                });
                var aprobar = document.createElement('button');
                aprobar.type = 'button';
                aprobar.className = 'editar';
                aprobar.textContent = 'Aprobar';
                aprobar.addEventListener('click', function () { resolverSolicitud(registro.Solicitud_ID, 'Aprobada', selectorTipo.value); });
                var rechazar = document.createElement('button');
                rechazar.type = 'button';
                rechazar.className = 'eliminar';
                rechazar.textContent = 'Rechazar';
                rechazar.addEventListener('click', function () { resolverSolicitud(registro.Solicitud_ID, 'Rechazada', null); });
                celda.appendChild(selectorTipo);
                celda.appendChild(aprobar);
                celda.appendChild(rechazar);
            }
        } else {
            var editar = document.createElement('button');
            editar.type = 'button';
            editar.className = 'editar';
            editar.textContent = 'Editar';
            editar.addEventListener('click', function () { dibujarFormulario(registro); window.scrollTo(0, 0); });
            var eliminar = document.createElement('button');
            eliminar.type = 'button';
            eliminar.className = 'eliminar';
            eliminar.textContent = 'Eliminar';
            eliminar.addEventListener('click', function () { eliminarRegistro(registro[definicionActual().id]); });
            celda.appendChild(editar);
            celda.appendChild(eliminar);
        }
        fila.appendChild(celda);
    }

    function dibujarTabla(registros) {
        var definicion = definicionActual();
        var columnas = [definicion.id].concat(definicion.campos);
        encabezadoTabla.innerHTML = '';
        var filaEncabezado = document.createElement('tr');
        columnas.concat(['Acciones']).forEach(function (columna) { agregarCelda(filaEncabezado, columna); });
        encabezadoTabla.appendChild(filaEncabezado);
        cuerpoTabla.innerHTML = '';
        if (!registros || registros.length === 0) {
            var vacio = document.createElement('tr');
            var celdaVacia = document.createElement('td');
            celdaVacia.colSpan = columnas.length + 1;
            celdaVacia.textContent = selector.value === 'solicitudes' ? 'No hay solicitudes pendientes o registradas.' : 'No hay registros para mostrar.';
            vacio.appendChild(celdaVacia);
            cuerpoTabla.appendChild(vacio);
            return;
        }
        registros.forEach(function (registro) {
            var fila = document.createElement('tr');
            columnas.forEach(function (columna) { agregarCelda(fila, registro[columna]); });
            dibujarAcciones(fila, registro);
            cuerpoTabla.appendChild(fila);
        });
    }

    async function cargarTiposPrestamo() {
        var respuesta = await pedir('php/api.php?recurso=tipos-prestamo');
        tiposPrestamo = respuesta.datos || [];
    }

    async function cargarRegistros() {
        estado.textContent = 'Cargando registros...';
        try {
            if (selector.value === 'solicitudes') await cargarTiposPrestamo();
            var respuesta = await pedir('php/api.php?recurso=' + encodeURIComponent(selector.value));
            estado.textContent = '';
            dibujarTabla(respuesta.datos || []);
        } catch (error) {
            estado.textContent = error.message;
            dibujarTabla([]);
        }
    }

    async function resolverSolicitud(id, decision, tipoPrestamoId) {
        if (decision === 'Aprobada' && !tipoPrestamoId) {
            estado.textContent = 'Selecciona un tipo de préstamo antes de aprobar.';
            return;
        }
        if (decision === 'Rechazada' && !window.confirm('¿Confirmas que deseas rechazar esta solicitud?')) return;
        try {
            estado.textContent = 'Guardando decisión...';
            var resultado = await pedir('php/api.php?recurso=resolver-solicitud&id=' + encodeURIComponent(id), {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ decision: decision, tipoPrestamoId: tipoPrestamoId })
            });
            estado.textContent = resultado.message;
            await cargarRegistros();
        } catch (error) {
            estado.textContent = error.message;
        }
    }

    async function eliminarRegistro(id) {
        if (!window.confirm('¿Deseas eliminar el registro #' + id + '?')) return;
        try {
            var respuesta = await pedir('php/api.php?recurso=' + encodeURIComponent(selector.value) + '&id=' + encodeURIComponent(id), { method: 'DELETE' });
            estado.textContent = respuesta.message;
            dibujarFormulario(null);
            await cargarRegistros();
        } catch (error) {
            estado.textContent = error.message;
        }
    }

    formulario.addEventListener('submit', async function (evento) {
        evento.preventDefault();
        var definicion = definicionActual();
        if (!registroActual && definicion.permitirCrear === false) return;
        var datos = {};
        definicion.campos.forEach(function (campo) { datos[campo] = document.getElementById('campo_' + campo).value; });
        var metodo = registroActual ? 'PUT' : 'POST';
        var url = 'php/api.php?recurso=' + encodeURIComponent(selector.value);
        if (registroActual) url += '&id=' + encodeURIComponent(registroActual);
        try {
            estado.textContent = 'Guardando...';
            var respuesta = await pedir(url, { method: metodo, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(datos) });
            estado.textContent = respuesta.message || 'Registro guardado.';
            dibujarFormulario(null);
            await cargarRegistros();
        } catch (error) {
            estado.textContent = error.message;
        }
    });

    document.getElementById('cancelar').addEventListener('click', function () { dibujarFormulario(null); });
    selector.addEventListener('change', function () { dibujarFormulario(null); cargarRegistros(); });
    dibujarFormulario(null);
    cargarRegistros();
});