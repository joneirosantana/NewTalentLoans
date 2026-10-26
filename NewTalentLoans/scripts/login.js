document.addEventListener('DOMContentLoaded', function () {
    var formulario = document.getElementById('formLogin');
    var modal = document.getElementById('modalOverlay');
    var titulo = document.getElementById('modalTitle');
    var mensaje = document.getElementById('modalMessage');
    var boton = document.getElementById('modalBtn');

    function mostrarMensaje(textoTitulo, textoMensaje, accion) {
        titulo.textContent = textoTitulo;
        mensaje.textContent = textoMensaje;
        modal.classList.add('active');
        var nuevoBoton = boton.cloneNode(true);
        boton.parentNode.replaceChild(nuevoBoton, boton);
        boton = nuevoBoton;
        boton.addEventListener('click', function () {
            modal.classList.remove('active');
            if (accion) accion();
        });
    }

    formulario.addEventListener('submit', function (evento) {
        evento.preventDefault();
        var correo = document.getElementById('correo').value.trim();
        var contrasena = document.getElementById('password').value;
        if (!correo || !contrasena) {
            mostrarMensaje('Datos incompletos', 'Escriba su correo y contraseña.');
            return;
        }
        fetch('php/api.php?recurso=sesion', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ correo: correo, contrasena: contrasena })
        }).then(function (respuesta) {
            return respuesta.json().then(function (contenido) {
                return { ok: respuesta.ok, contenido: contenido };
            });
        }).then(function (resultado) {
            if (!resultado.ok || !resultado.contenido.success) {
                throw new Error(resultado.contenido.message || 'No se pudo iniciar sesión.');
            }
            localStorage.setItem('usuario', JSON.stringify(resultado.contenido.usuario));
            var destino = resultado.contenido.usuario.esAdministrador ? 'panel-servicios.php' : 'solicitudes.php';
            mostrarMensaje('Bienvenido', 'Inicio de sesión correcto.', function () {
                window.location.href = destino;
            });
        }).catch(function (error) {
            mostrarMensaje('No se pudo iniciar sesión', error.message || 'No se pudo conectar con el servidor.');
        });
    });
});
