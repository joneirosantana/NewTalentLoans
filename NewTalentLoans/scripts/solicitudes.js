document.addEventListener('DOMContentLoaded', function () {
    var formulario = document.getElementById('formSolicitud');
    var mensaje = document.getElementById('mensaje');
    var tabla = document.getElementById('listaSolicitudes');
    var tipo = document.getElementById('tipoPrestamo');
    var metodo = document.getElementById('metodoPago');
    var grupoGarante = document.getElementById('grupoGarante');
    var sueldoMensual = 0;
    var metodosDisponibles = [];
    var usuario = null;
    try { usuario = JSON.parse(localStorage.getItem('usuario') || 'null'); } catch (error) { usuario = null; }
    if (usuario) document.getElementById('nombreUsuario').textContent = (usuario.nombre || '') + ' ' + (usuario.apellido || '');

    function dinero(valor) { return Number(valor || 0).toLocaleString('es-DO', { style: 'currency', currency: 'DOP' }); }
    function pedir(url, opciones) {
        return fetch(url, opciones || {}).then(function (respuesta) {
            return respuesta.json().then(function (datos) { if (!respuesta.ok || !datos.success) throw new Error(datos.message || 'No se pudo completar la operación.'); return datos; });
        });
    }
    function seleccionar(select, registros, campoId, campoNombre) {
        select.innerHTML = '<option value="">Seleccione…</option>';
        registros.forEach(function (registro) { var opcion = document.createElement('option'); opcion.value = registro[campoId]; opcion.textContent = registro[campoNombre]; select.appendChild(opcion); });
    }
    function actualizarGarante() {
        var requiere = Number(document.getElementById('monto').value || 0) > sueldoMensual;
        grupoGarante.hidden = !requiere;
        ['garanteNombre', 'garanteCedula', 'garanteTelefono'].forEach(function (id) { document.getElementById(id).required = requiere; });
    }
    function actualizarProyeccion() {
        var campoMonto = Number(document.getElementById('monto').value || 0);
        var meses = Number(document.getElementById('plazo').value || 0);
        var registroTipo = tipo.options[tipo.selectedIndex];
        var tasaAnual = registroTipo ? Number(registroTipo.getAttribute('data-tasa') || 0) : 0;
        var salida = document.getElementById('resultadoProyeccion');
        if (campoMonto <= 0 || meses <= 0 || !tipo.value) { salida.hidden = false; salida.textContent = 'Indique tipo, monto y plazo para calcular la proyección.'; return; }
        var tasaMensual = tasaAnual / 100 / 12;
        var cuota = tasaMensual === 0 ? campoMonto / meses : campoMonto * tasaMensual / (1 - Math.pow(1 + tasaMensual, -meses));
        salida.hidden = false;
        salida.innerHTML = '<strong>Cuota mensual estimada:</strong> ' + dinero(cuota) + '<br><strong>Total estimado:</strong> ' + dinero(cuota * meses) + '<br><strong>Interés estimado:</strong> ' + dinero(cuota * meses - campoMonto) + '<br><small>Estimación con una tasa anual de ' + tasaAnual.toFixed(2) + '%. Puede variar al aprobarse.</small>';
    }
    function cargarCatalogos() {
        return Promise.all([pedir('php/api.php?recurso=tipos-prestamo'), pedir('php/api.php?recurso=metodos-pago'), pedir('php/api.php?recurso=mi-perfil')]).then(function (respuestas) {
            seleccionar(tipo, respuestas[0].datos, 'TipoPrestamo_ID', 'TipoPrestamo_Nombre');
            respuestas[0].datos.forEach(function (registro, indice) { tipo.options[indice + 1].setAttribute('data-tasa', registro.TipoPrestamo_TasaBase || 0); });
            metodosDisponibles = respuestas[1].datos;
            seleccionar(metodo, metodosDisponibles, 'MetodoPago_ID', 'MetodoPago_Nombre');
            seleccionar(document.getElementById('metodoPagoActivo'), metodosDisponibles, 'MetodoPago_ID', 'MetodoPago_Nombre');
            sueldoMensual = Number(respuestas[2].sueldo || 0);
            document.getElementById('sueldoCliente').textContent = 'Sueldo mensual registrado: ' + dinero(sueldoMensual);
        });
    }
    function cargarSolicitudes() {
        return pedir('php/api.php?recurso=solicitudes').then(function (respuesta) {
            tabla.innerHTML = '';
            if (!respuesta.datos || !respuesta.datos.length) { tabla.innerHTML = '<tr><td colspan="5">Todavía no tiene solicitudes.</td></tr>'; return; }
            respuesta.datos.forEach(function (registro) {
                var fila = document.createElement('tr');
                [registro.Solicitud_Fecha, dinero(registro.Solicitud_Monto), registro.Solicitud_Plazo, registro.Solicitud_Motivo, registro.Solicitud_Estado].forEach(function (valor) { var celda = document.createElement('td'); celda.textContent = valor === null || valor === undefined ? '' : String(valor); fila.appendChild(celda); });
                tabla.appendChild(fila);
            });
        });
    }
    function cargarPrestamoActivo() {
        return pedir('php/api.php?recurso=mi-prestamo').then(function (respuesta) {
            if (!respuesta.dato) return;
            document.getElementById('panelPrestamoActivo').hidden = false;
            var p = respuesta.dato;
            var monto = Number(p.Prestamo_Monto || 0), saldo = Number(p.Prestamo_Saldo || 0), tasaAnual = Number(p.Prestamo_Tasa || 0), meses = Number(p.Prestamo_Plazo || 1);
            var i = tasaAnual / 1200, cuota = i ? monto * i / (1 - Math.pow(1 + i, -meses)) : monto / meses;
            document.getElementById('resumenPrestamo').innerHTML = '<p><b>Monto:</b> ' + dinero(monto) + '</p><p><b>Saldo pendiente:</b> ' + dinero(saldo) + '</p><p><b>Tasa anual:</b> ' + tasaAnual.toFixed(2) + '%</p><p><b>Cuota mensual estimada:</b> ' + dinero(cuota) + '</p>';
            document.getElementById('montoPago').max = saldo;
            if (p.Solicitud_MetodoPagoId) document.getElementById('metodoPagoActivo').value = p.Solicitud_MetodoPagoId;
        });
    }
    document.getElementById('monto').addEventListener('input', actualizarGarante);
    document.getElementById('btnContacto').addEventListener('click', function () { document.getElementById('datosContacto').hidden = !document.getElementById('datosContacto').hidden; });
    document.getElementById('btnProyeccion').addEventListener('click', actualizarProyeccion);
    document.getElementById('cerrarSesion').addEventListener('click', function (evento) { evento.preventDefault(); fetch('php/api.php?recurso=cerrar-sesion', { method: 'POST', keepalive: true }); localStorage.removeItem('usuario'); window.location.href = 'index.html'; });
    formulario.addEventListener('submit', function (evento) {
        evento.preventDefault(); actualizarGarante();
        var datos = { Solicitud_Fecha: new Date().toISOString().slice(0, 10), Solicitud_Monto: document.getElementById('monto').value, Solicitud_Plazo: document.getElementById('plazo').value, Solicitud_Motivo: document.getElementById('motivo').value.trim(), Solicitud_Estado: 'Pendiente', Solicitud_TipoPrestamoId: tipo.value, Solicitud_MetodoPagoId: metodo.value, Solicitud_GaranteNombre: document.getElementById('garanteNombre').value.trim(), Solicitud_GaranteCedula: document.getElementById('garanteCedula').value.trim(), Solicitud_GaranteTelefono: document.getElementById('garanteTelefono').value.trim() };
        document.getElementById('btnEnviar').disabled = true; mensaje.textContent = 'Enviando solicitud…';
        pedir('php/api.php?recurso=solicitudes', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(datos) }).then(function () { formulario.reset(); grupoGarante.hidden = true; document.getElementById('resultadoProyeccion').hidden = true; mensaje.textContent = 'Solicitud enviada. Puede consultar su estado en la tabla.'; return cargarSolicitudes(); }).catch(function (error) { mensaje.textContent = error.message; }).then(function () { document.getElementById('btnEnviar').disabled = false; });
    });
    document.getElementById('formPago').addEventListener('submit', function (evento) {
        evento.preventDefault(); var btn = document.getElementById('btnRegistrarPago'); btn.disabled = true;
        var datos = { monto: document.getElementById('montoPago').value, metodoPagoId: document.getElementById('metodoPagoActivo').value, tipo: document.getElementById('tipoPago').value };
        pedir('php/api.php?recurso=pago-cliente', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(datos) }).then(function (respuesta) { document.getElementById('mensajePago').textContent = 'Operación aplicada. Nuevo saldo: ' + dinero(respuesta.resultado.saldo); return cargarPrestamoActivo(); }).catch(function (error) { document.getElementById('mensajePago').textContent = error.message; }).then(function () { btn.disabled = false; });
    });
    cargarCatalogos().then(function () { return Promise.all([cargarSolicitudes(), cargarPrestamoActivo()]); }).catch(function (error) { mensaje.textContent = error.message; if (/sesión|inicie sesión/i.test(error.message)) window.setTimeout(function () { window.location.href = 'index.html'; }, 1500); });
});
