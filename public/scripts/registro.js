document.addEventListener('DOMContentLoaded', function () {
    var formulario = document.getElementById('formRegistro');
    var botonSiguiente = document.getElementById('btnSiguiente');
    var botonVolver = document.getElementById('btnVolver');
    var pasos = [document.getElementById('paso-1'), document.getElementById('paso-2'), document.getElementById('paso-3')];
    var modal = document.getElementById('modalOverlay');
    var modalTitulo = document.getElementById('modalTitle');
    var modalMensaje = document.getElementById('modalMessage');
    var modalBoton = document.getElementById('modalBtn');
    var modalTerminos = document.getElementById('modalTerminos');
    var pasoActual = 0;
    var empleadoNotice = document.getElementById('empleadoNotice');
    NTLApi.fetch('http://api.newtalentloans.local/?recurso=empresas-publicas').then(function (r) { return r.json(); }).then(function (j) {
        var select = document.getElementById('empresaId');
        (j.datos || []).forEach(function (empresa) { var option = document.createElement('option'); option.value = empresa.Empresa_ID; option.textContent = empresa.Empresa_Nombre + ' — RNC ' + empresa.Empresa_RNC; select.appendChild(option); });
    }).catch(function () {});

    function mostrarMensaje(titulo, mensaje, accion) {
        modalTitulo.textContent = titulo;
        modalMensaje.textContent = mensaje;
        modal.classList.add('active');
        var nuevoBoton = modalBoton.cloneNode(true);
        modalBoton.parentNode.replaceChild(nuevoBoton, modalBoton);
        modalBoton = nuevoBoton;
        modalBoton.addEventListener('click', function () {
            modal.classList.remove('active');
            if (accion) accion();
        });
    }

    function mostrarPaso(indice) {
        pasos.forEach(function (paso) { paso.classList.remove('activo'); });
        pasos[indice].classList.add('activo');
        botonSiguiente.textContent = indice === pasos.length - 1 ? 'Registrar' : 'Siguiente';
    }

    function validarPaso(indice) {
        var campos = pasos[indice].querySelectorAll('input[required]');
        var faltantes = [];
        campos.forEach(function (campo) {
            if (campo.type === 'checkbox') {
                if (!campo.checked) faltantes.push('aceptar los términos');
            } else if (campo.value.trim() === '') {
                faltantes.push(campo.nextElementSibling ? campo.nextElementSibling.textContent.replace(':', '') : campo.name);
                campo.style.borderColor = 'red';
            }
        });
        if (faltantes.length > 0) {
            mostrarMensaje('Información incompleta', 'Revise estos datos: ' + faltantes.join(', '));
            return false;
        }
        if (indice === 2) {
            var correo = document.getElementById('correo').value.trim();
            var clave = document.getElementById('password').value;
            var confirmarClave = document.getElementById('confirmPassword').value;
            if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(correo)) {
                mostrarMensaje('Correo no válido', 'Escriba una dirección de correo válida.');
                return false;
            }
            if (clave.length < 8) {
                mostrarMensaje('Contraseña corta', 'La contraseña debe tener al menos 8 caracteres.');
                return false;
            }
            if (clave !== confirmarClave) {
                mostrarMensaje('Las contraseñas no coinciden', 'Vuelva a escribir la contraseña en ambos campos.');
                return false;
            }
        }
        return true;
    }

    function enviarRegistro(datos) {
        botonSiguiente.disabled = true;
        botonSiguiente.textContent = 'Enviando...';
        NTLApi.fetch('http://api.newtalentloans.local/?recurso=registro', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(datos)
        }).then(function (respuesta) {
            return respuesta.json().then(function (contenido) {
                return { ok: respuesta.ok, contenido: contenido };
            });
        }).then(function (resultado) {
            if (!resultado.ok || !resultado.contenido.success) {
                throw new Error(resultado.contenido.message || 'No se pudo completar el registro.');
            }
            var usuario = resultado.contenido.usuario || {};
            if (usuario.tipo === 'empleado' && empleadoNotice) {
                empleadoNotice.hidden = false;
                empleadoNotice.querySelector('button').onclick = function () { empleadoNotice.hidden = true; };
            }
            mostrarMensaje(usuario.tipo === 'empleado' ? 'Solicitud enviada a RRHH' : 'Registro exitoso', usuario.tipo === 'empleado'
                ? 'Tu registro inició como empleado y quedó pendiente de revisión por RRHH.'
                : 'La cuenta fue creada. Ya puede iniciar sesión.', function () {
                window.location.href = 'iniciar-sesion.html';
            });
        }).catch(function (error) {
            mostrarMensaje('No se pudo registrar', error.message || 'No se pudo conectar con el servidor PHP.');
        }).then(function () {
            botonSiguiente.disabled = false;
            botonSiguiente.textContent = 'Registrar';
        });
    }

    formulario.addEventListener('submit', function (evento) {
        evento.preventDefault();
        if (!validarPaso(pasoActual)) return;
        if (pasoActual < pasos.length - 1) {
            pasoActual++;
            mostrarPaso(pasoActual);
            return;
        }
        var datos = {
            nombre: document.getElementById('nombre').value.trim(),
            apellido: document.getElementById('apellido').value.trim(),
            calle: document.getElementById('calle').value.trim(),
            numero: document.getElementById('numero').value.trim(),
            sector: document.getElementById('sector').value.trim(),
            referencia: document.getElementById('referencia').value.trim(),
            provincia: document.getElementById('provincia').value.trim(),
            ciudad: document.getElementById('ciudad').value.trim(),
            telefono: document.getElementById('telefono').value.trim(),
            cedula: document.getElementById('cedula').value.trim(),
            sueldo: document.getElementById('sueldo').value,
            empresaId: document.getElementById('empresaId').value,
            correo: document.getElementById('correo').value.trim(),
            contrasena: document.getElementById('password').value
        };
        enviarRegistro(datos);
    });

    botonVolver.addEventListener('click', function () {
        if (pasoActual === 0) {
            window.location.href = 'iniciar-sesion.html';
            return;
        }
        pasoActual--;
        mostrarPaso(pasoActual);
    });

    document.getElementById('verTerminos').addEventListener('click', function (evento) {
        evento.preventDefault();
        modalTerminos.classList.add('active');
    });
    document.getElementById('cerrarTerminos').addEventListener('click', function () { modalTerminos.classList.remove('active'); });
    document.getElementById('aceptarTerminos').addEventListener('change', function () { modalTerminos.classList.remove('active'); });
    document.querySelectorAll('input').forEach(function (campo) {
        campo.addEventListener('input', function () { campo.style.borderColor = '#333'; });
    });
    mostrarPaso(0);
});

