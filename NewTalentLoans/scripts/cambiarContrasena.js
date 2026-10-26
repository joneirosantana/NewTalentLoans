// ==========================================================
// SISTEMA DE CAMBIO DE CONTRASEÑA - New Talent Loans
// ==========================================================

document.addEventListener('DOMContentLoaded', () => {

    // ==========================================================
    // 🔌 CONFIGURACIÓN DEL BACKEND
    // ==========================================================
    const API_URL = 'http://localhost:3000';

    const ENDPOINTS = {
        cambiar: `${API_URL}/api/usuarios/cambiar-password`
    };

    // 👇 Cambia a FALSE cuando tengas tu backend listo
    const MODO_SIMULACION = true;

    // =========================================
    // REFERENCIAS DEL DOM
    // =========================================
    const formCambiar = document.getElementById('formCambiarContrasena');
    const inputPasswordActual = document.getElementById('passwordActual');
    const inputPasswordNueva = document.getElementById('passwordNueva');
    const inputPasswordConfirmar = document.getElementById('passwordConfirmar');
    const btnCancelar = document.getElementById('btnCancelar');

    const strengthFill = document.getElementById('strengthFill');
    const strengthText = document.getElementById('strengthText');

    // Modal
    const modalOverlay = document.getElementById('modalOverlay');
    const modalTitle = document.getElementById('modalTitle');
    const modalMessage = document.getElementById('modalMessage');
    const modalBtn = document.getElementById('modalBtn');

    let accionModalActual = null;

    // =========================================
    // MODAL
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
    // MOSTRAR / OCULTAR CONTRASEÑA
    // =========================================
    document.querySelectorAll('.toggle-password').forEach(btn => {
        btn.addEventListener('click', () => {
            const targetId = btn.dataset.target;
            const input = document.getElementById(targetId);
            const icon = btn.querySelector('ion-icon');

            if (input.type === 'password') {
                input.type = 'text';
                icon.setAttribute('name', 'eye-off-outline');
            } else {
                input.type = 'password';
                icon.setAttribute('name', 'eye-outline');
            }
        });
    });

    // =========================================
    // VALIDAR REQUISITOS
    // =========================================
    function validarRequisitos(password) {
        return {
            longitud: password.length >= 8,
            mayuscula: /[A-Z]/.test(password),
            minuscula: /[a-z]/.test(password),
            numero: /[0-9]/.test(password),
            especial: /[!@#$%^&*(),.?":{}|<>]/.test(password)
        };
    }

    function actualizarRequisitos(password) {
        const req = validarRequisitos(password);

        document.getElementById('req-longitud').classList.toggle('cumplido', req.longitud);
        document.getElementById('req-mayuscula').classList.toggle('cumplido', req.mayuscula);
        document.getElementById('req-minuscula').classList.toggle('cumplido', req.minuscula);
        document.getElementById('req-numero').classList.toggle('cumplido', req.numero);
        document.getElementById('req-especial').classList.toggle('cumplido', req.especial);

        ['longitud', 'mayuscula', 'minuscula', 'numero', 'especial'].forEach(key => {
            const li = document.getElementById('req-' + key);
            const icon = li.querySelector('ion-icon');
            if (req[key]) {
                icon.setAttribute('name', 'checkmark-circle');
            } else {
                icon.setAttribute('name', 'close-circle-outline');
            }
        });

        return req;
    }

    // =========================================
    // INDICADOR DE FUERZA
    // =========================================
    function actualizarFuerza(password) {
        const req = validarRequisitos(password);
        const cumplidos = Object.values(req).filter(v => v).length;

        let porcentaje = 0;
        let color = '#e74c3c';
        let texto = 'Muy débil';

        if (password.length === 0) {
            porcentaje = 0;
            texto = 'Ingresa una contraseña';
            color = '#e0e0e0';
        } else if (cumplidos <= 2) {
            porcentaje = 25;
            color = '#e74c3c';
            texto = 'Muy débil';
        } else if (cumplidos === 3) {
            porcentaje = 50;
            color = '#f39c12';
            texto = 'Débil';
        } else if (cumplidos === 4) {
            porcentaje = 75;
            color = '#3498db';
            texto = 'Buena';
        } else if (cumplidos === 5) {
            porcentaje = 100;
            color = '#00963f';
            texto = '¡Excelente!';
        }

        strengthFill.style.width = porcentaje + '%';
        strengthFill.style.backgroundColor = color;
        strengthText.textContent = texto;
        strengthText.style.color = color;
    }

    inputPasswordNueva.addEventListener('input', () => {
        actualizarRequisitos(inputPasswordNueva.value);
        actualizarFuerza(inputPasswordNueva.value);
    });

    // =========================================
    // CANCELAR
    // =========================================
    btnCancelar.addEventListener('click', () => {
        window.location.href = 'iniciar-sesion.php';
    });

    // =========================================
    // ENVIAR FORMULARIO
    // =========================================
    formCambiar.addEventListener('submit', async (e) => {
        e.preventDefault();

        const passwordActual = inputPasswordActual.value.trim();
        const passwordNueva = inputPasswordNueva.value.trim();
        const passwordConfirmar = inputPasswordConfirmar.value.trim();

        if (!passwordActual || !passwordNueva || !passwordConfirmar) {
            mostrarModal('Campos Incompletos', 'Por favor complete todos los campos.');
            return;
        }

        const req = validarRequisitos(passwordNueva);
        const todosCumplidos = Object.values(req).every(v => v);

        if (!todosCumplidos) {
            mostrarModal('Contraseña Débil', 'La nueva contraseña debe cumplir con todos los requisitos.');
            return;
        }

        if (passwordNueva !== passwordConfirmar) {
            mostrarModal('Contraseñas no coinciden', 'La nueva contraseña y su confirmación deben ser iguales.');
            return;
        }

        if (passwordActual === passwordNueva) {
            mostrarModal('Contraseña Repetida', 'La nueva contraseña debe ser diferente a la actual.');
            return;
        }

        const datos = {
            passwordActual: passwordActual,
            passwordNueva: passwordNueva
        };

        mostrarModal('Actualizando...', 'Cambiando tu contraseña, por favor espera...');

        // 🔸 SIMULACIÓN
        if (MODO_SIMULACION) {
            setTimeout(() => {
                cerrarModal();
                mostrarModal(
                    '✅ Contraseña Actualizada',
                    'Tu contraseña ha sido cambiada correctamente. Ahora puedes iniciar sesión con tu nueva contraseña.',
                    () => {
                        // Redirigir al LOGIN
                        window.location.href = 'iniciar-sesion.php';
                    }
                );
            }, 1500);
            return;
        }

        // 🔌 REAL
        const token = localStorage.getItem('token');

        try {
            const response = await fetch(ENDPOINTS.cambiar, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`
                },
                body: JSON.stringify(datos)
            });

            const data = await response.json();
            cerrarModal();

            if (response.ok && data.success) {
                mostrarModal(
                    '✅ Contraseña Actualizada',
                    data.message || 'Tu contraseña ha sido cambiada correctamente. Ahora puedes iniciar sesión.',
                    () => {
                        // Redirigir al LOGIN
                        window.location.href = 'iniciar-sesion.php';
                    }
                );
            } else {
                mostrarModal('Error', data.message || 'No se pudo cambiar la contraseña.');
            }
        } catch (error) {
            console.error('❌ Error:', error);
            cerrarModal();
            mostrarModal('Error de Conexión', 'No se pudo conectar con el servidor.');
        }
    });

    // =========================================
    // CERRAR MODAL CON ESC
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