document.addEventListener('DOMContentLoaded', function() {

    // =========================================
    // 1. REFERENCIAS
    // =========================================
    const formRegistro = document.getElementById('formRegistro');
    const btnSiguiente = document.getElementById('btnSiguiente');
    const btnVolver = document.getElementById('btnVolver');
    
    const pasos = [
        document.getElementById('paso-1'),
        document.getElementById('paso-2'),
        document.getElementById('paso-3')
    ];

    // Modal de mensajes
    const modalOverlay = document.getElementById('modalOverlay');
    const modalTitle = document.getElementById('modalTitle');
    const modalMessage = document.getElementById('modalMessage');
    const modalBtn = document.getElementById('modalBtn');

    // Modal de Términos
    const modalTerminos = document.getElementById('modalTerminos');
    const verTerminos = document.getElementById('verTerminos');
    const cerrarTerminos = document.getElementById('cerrarTerminos');
    const aceptarTerminos = document.getElementById('aceptarTerminos');

    let pasoActual = 0;

    // =========================================
    // 2. FUNCIÓN PARA MOSTRAR EL MODAL DE MENSAJES
    // =========================================
    function mostrarModal(titulo, mensaje, callback) {
        modalTitle.textContent = titulo;
        modalMessage.textContent = mensaje;
        modalOverlay.classList.add('active');

        const nuevoBtn = modalBtn.cloneNode(true);
        modalBtn.parentNode.replaceChild(nuevoBtn, modalBtn);

        nuevoBtn.addEventListener('click', function() {
            modalOverlay.classList.remove('active');
            if (callback) callback();
        });
    }

    modalOverlay.addEventListener('click', function(e) {
        if (e.target === modalOverlay) {
            modalOverlay.classList.remove('active');
        }
    });

    // =========================================
    // 3. MODAL DE TÉRMINOS Y CONDICIONES
    // =========================================
    verTerminos.addEventListener('click', function(e) {
        e.preventDefault();
        modalTerminos.classList.add('active');
    });

    cerrarTerminos.addEventListener('click', function() {
        modalTerminos.classList.remove('active');
    });

    modalTerminos.addEventListener('click', function(e) {
        if (e.target === modalTerminos) {
            modalTerminos.classList.remove('active');
        }
    });

    // =========================================
    // 4. FUNCIÓN PARA MOSTRAR UN PASO
    // =========================================
    function mostrarPaso(indice) {
        pasos.forEach(function(paso) {
            paso.classList.remove('activo');
        });

        pasos[indice].classList.add('activo');

        if (indice === pasos.length - 1) {
            btnSiguiente.textContent = 'Registrar';
        } else {
            btnSiguiente.textContent = 'Siguiente';
        }
    }

    // =========================================
    // 5. VALIDACIÓN DE CADA PASO
    // =========================================
    function validarPaso(indice) {
        const paso = pasos[indice];
        const inputs = paso.querySelectorAll('input[type="text"], input[type="email"], input[type="tel"], input[type="password"]');
        let camposVacios = [];

        inputs.forEach(function(input) {
            const label = input.nextElementSibling.textContent.replace(':', '');
            
            if (input.value.trim() === '') {
                input.style.borderColor = 'red';
                camposVacios.push(label);
            } else {
                input.style.borderColor = '#333';
            }
        });

        if (camposVacios.length > 0) {
            mostrarModal(
                'Campos Incompletos', 
                'Por favor complete los siguientes campos: ' + camposVacios.join(', ')
            );
            return false;
        }

        // Validaciones específicas del Paso 3
        if (indice === 2) {
            const pass = document.getElementById('password').value.trim();
            const confirmPass = document.getElementById('confirmPassword').value.trim();
            const correo = document.getElementById('correo').value.trim();

            const regexCorreo = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
            if (!regexCorreo.test(correo)) {
                mostrarModal('Correo Inválido', 'Por favor, ingrese un correo electrónico válido.');
                return false;
            }

            if (pass !== confirmPass) {
                mostrarModal('Contraseñas no coinciden', 'Las contraseñas deben ser iguales.');
                return false;
            }

            if (pass.length < 6) {
                mostrarModal('Contraseña Corta', 'La contraseña debe tener al menos 6 caracteres.');
                return false;
            }

            // Validar que aceptó los términos
            if (!aceptarTerminos.checked) {
                mostrarModal(
                    'Términos no aceptados', 
                    'Debe aceptar los Términos y Condiciones para poder registrarse.'
                );
                return false;
            }
        }

        return true;
    }

    // =========================================
    // 6. LÓGICA DEL BOTÓN SIGUIENTE / REGISTRAR
    // =========================================
    formRegistro.addEventListener('submit', function(e) {
        e.preventDefault();

        if (!validarPaso(pasoActual)) {
            return;
        }

        // Si es el último paso, enviamos el formulario
        if (pasoActual === pasos.length - 1) {
            console.log('Enviando datos de registro al backend...');
            
            const datos = {
                nombre: document.getElementById('nombre').value.trim(),
                apellido: document.getElementById('apellido').value.trim(),
                direccion: document.getElementById('direccion').value.trim(),
                telefono: document.getElementById('telefono').value.trim(),
                cedula: document.getElementById('cedula').value.trim(),
                correo: document.getElementById('correo').value.trim(),
                password: document.getElementById('password').value.trim(),
                aceptoTerminos: true
            };

            console.log('Datos a enviar:', datos);

            // 🔌 Cuando tengas el backend:
            /*
            fetch('http://localhost:3000/registro', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(datos)
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    mostrarModal('¡Registro Exitoso!', 'Ahora puede iniciar sesión.', function() {
                        window.location.href = 'IniciarSesion.html';
                    });
                } else {
                    mostrarModal('Error', data.message || 'Error al registrarse.');
                }
            })
            .catch(error => {
                mostrarModal('Error de Conexión', 'No se pudo conectar con el servidor.');
            });
            */

            // 🔸 TEMPORAL (sin backend):
            setTimeout(function() {
                mostrarModal(
                    '¡Registro Exitoso!', 
                    'Su cuenta ha sido creada correctamente. Ahora puede iniciar sesión.', 
                    function() {
                        window.location.href = 'IniciarSesion.html';
                    }
                );
            }, 800);
            return;
        }

        // Avanzamos al siguiente paso
        pasoActual++;
        mostrarPaso(pasoActual);
    });

    // =========================================
    // 7. LÓGICA DEL BOTÓN VOLVER
    // =========================================
    btnVolver.addEventListener('click', function(e) {
        e.preventDefault();

        if (pasoActual === 0) {
            window.location.href = 'IniciarSesion.html';
            return;
        }

        pasoActual--;
        mostrarPaso(pasoActual);
    });

    // =========================================
    // 8. LIMPIAR BORDE ROJO AL ESCRIBIR
    // =========================================
    const todosLosInputs = document.querySelectorAll('input');
    todosLosInputs.forEach(function(input) {
        input.addEventListener('input', function() {
            this.style.borderColor = '#333';
        });
    });

    // =========================================
    // 9. INICIALIZAR EN EL PRIMER PASO
    // =========================================
    mostrarPaso(0);

});