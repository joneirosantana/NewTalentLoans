document.addEventListener('DOMContentLoaded', () => {
    
    // =========================================
    // 0. CONFIGURACIÓN
    // =========================================
    const API_URL = 'http://localhost:3000'; // 👈 CAMBIA ESTO POR LA URL DE TU BACKEND

    // =========================================
    // FUNCIÓN PARA MOSTRAR EL MODAL
    // =========================================
    const modalOverlay = document.getElementById('modalOverlay');
    const modalTitle = document.getElementById('modalTitle');
    const modalMessage = document.getElementById('modalMessage');
    const modalBtn = document.getElementById('modalBtn');

    function mostrarModal(titulo, mensaje, callback) {
        modalTitle.textContent = titulo;
        modalMessage.textContent = mensaje;
        modalOverlay.classList.add('active');

        // Clonamos el botón para limpiar eventos anteriores
        const nuevoBtn = modalBtn.cloneNode(true);
        modalBtn.parentNode.replaceChild(nuevoBtn, modalBtn);

        nuevoBtn.addEventListener('click', () => {
            modalOverlay.classList.remove('active');
            if (callback) callback();
        });
    }

    modalOverlay.addEventListener('click', (e) => {
        if (e.target === modalOverlay) {
            modalOverlay.classList.remove('active');
        }
    });

    // =========================================
    // FUNCIÓN AUXILIAR: Formatear números con $
    // =========================================
    function formatearMoneda(numero) {
        return '$' + Number(numero).toLocaleString('es-CO', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }

    // =========================================
    // 1. CARGAR ESTADÍSTICAS AL INICIO
    // =========================================
    function cargarEstadisticas() {
        console.log('📊 Cargando estadísticas del dashboard...');

        fetch(API_URL + '/api/dashboard')
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    // Actualizamos cada cuadro con los datos del backend
                    document.querySelector('#card-capital .card-value').textContent = 
                        formatearMoneda(data.capitalPrestado);
                    
                    document.querySelector('#card-pagos .card-value').textContent = 
                        formatearMoneda(data.pagosRecibidosMes);
                    
                    document.querySelector('#card-prestamos .card-value').textContent = 
                        data.prestamosActivos;
                    
                    document.querySelector('#card-atrasados .card-value').textContent = 
                        data.pagosAtrasados;

                    console.log('✅ Estadísticas cargadas:', data);
                } else {
                    console.warn('⚠️ El backend no devolvió datos válidos:', data);
                }
            })
            .catch(error => {
                console.error('❌ Error al cargar estadísticas:', error);
                // No mostramos modal para no molestar al usuario; los cuadros se quedan en $0.00
            });
    }

    // =========================================
    // 2. LÓGICA DE LAS TARJETAS (CARDS) - CLICK
    // =========================================
    const cards = document.querySelectorAll('.card');

    cards.forEach((card) => {
        card.style.cursor = 'pointer';

        card.addEventListener('click', () => {
            const tipo = card.getAttribute('data-tipo');
            const label = card.querySelector('.card-label').textContent;

            console.log(`🔍 Cargando detalle de: ${tipo}`);

            // Mostramos modal de "cargando"
            mostrarModal('Cargando...', 'Obteniendo información de ' + label);

            // Llamada al backend
            fetch(API_URL + '/api/dashboard/' + tipo)
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        mostrarModal(
                            label,
                            'Se encontraron ' + data.datos.length + ' registros.\n\n' +
                            '(Aquí puedes mostrar una tabla con los datos)'
                        );
                    } else {
                        mostrarModal('Error', data.message || 'No se pudieron cargar los datos.');
                    }
                })
                .catch(error => {
                    console.error('❌ Error:', error);
                    mostrarModal('Error de Conexión', 'No se pudo conectar con el servidor.');
                });
        });
    });

    // =========================================
    // 3. LÓGICA DEL MENÚ LATERAL (SIDEBAR)
    // =========================================
    // ✅ Ahora los enlaces del sidebar NAVEGAN a las otras páginas
    // Solo cambiamos el título y el "active" visualmente

    const menuLinks = document.querySelectorAll('.sidebar-nav a');
    const pageTitle = document.querySelector('.page-title');

    menuLinks.forEach(link => {
        link.addEventListener('click', (e) => {
            const href = link.getAttribute('href');
            const sectionName = link.querySelector('span').textContent;

            // Si el enlace tiene un href real (no "#"), permitimos la navegación normal
            if (href && href !== '#') {
                // NO hacemos preventDefault, dejamos que el navegador navegue
                console.log(`🚀 Navegando a: ${href}`);
                return;
            }

            // Si el href es "#", entonces sí prevenimos y hacemos la lógica interna
            e.preventDefault();

            document.querySelectorAll('.sidebar-nav li').forEach(li => li.classList.remove('active'));
            link.parentElement.classList.add('active');

            if (sectionName === 'Inicio') {
                // Redirigir al panel principal
                window.location.href = 'panelPrincipal.htm';
                return;
            }

            pageTitle.textContent = sectionName;
            mostrarModal(sectionName, `Esta sección aún no está disponible.`);
        });
    });

    // =========================================
    // 4. LÓGICA DE CERRAR SESIÓN
    // =========================================
    const logoutLink = document.querySelector('.logout-link');
    
    if (logoutLink) {
        logoutLink.addEventListener('click', (e) => {
            e.preventDefault();
            
            mostrarModal('Cerrar Sesión', '¿Estás seguro de que deseas cerrar sesión?', function() {
                // 🔌 Cuando tengas el login funcionando:
                localStorage.removeItem('token');
                localStorage.removeItem('usuario');
                
                console.log('Sesión cerrada correctamente');
                
                // Redirigir a la página de sesión cerrada
                window.location.href = 'CerrarSesionExitoso.html';
            });
        });
    }

    // =========================================
    // 5. CARGAR TABLA DE ÚLTIMOS PRÉSTAMOS
    // =========================================
    function cargarTablaPrestamos() {
        console.log('📋 Cargando últimos préstamos...');

        fetch(API_URL + '/api/prestamos/ultimos')
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    const tbody = document.querySelector('.data-table tbody');
                    tbody.innerHTML = '';

                    if (data.datos.length === 0) {
                        // Si no hay datos, mostramos 3 filas vacías
                        for (let i = 0; i < 3; i++) {
                            const row = document.createElement('tr');
                            row.innerHTML = '<td></td><td></td><td></td><td></td><td></td>';
                            tbody.appendChild(row);
                        }
                    } else {
                        data.datos.forEach(prestamo => {
                            const row = document.createElement('tr');
                            row.innerHTML = `
                                <td>${prestamo.id}</td>
                                <td>${prestamo.cliente}</td>
                                <td>${formatearMoneda(prestamo.monto)}</td>
                                <td>${prestamo.estado}</td>
                                <td>${new Date(prestamo.fecha_prestamo).toLocaleDateString('es-CO')}</td>
                            `;
                            tbody.appendChild(row);
                        });
                    }
                    console.log('✅ Tabla cargada con', data.datos.length, 'registros');
                }
            })
            .catch(error => {
                console.error('❌ Error al cargar tabla:', error);
            });
    }

    // =========================================
    // 6. LÓGICA DEL BOTÓN DE MENÚ (MÓVILES)
    // =========================================
    const menuToggle = document.querySelector('.menu-toggle');
    const sidebar = document.querySelector('.sidebar');

    if (menuToggle && sidebar) {
        menuToggle.addEventListener('click', () => {
            sidebar.classList.toggle('open');
        });
    }

    // =========================================
    // 7. INICIALIZAR
    // =========================================
    cargarEstadisticas();
    cargarTablaPrestamos();

    // =========================================
    // 8. MOSTRAR NOMBRE DEL USUARIO LOGUEADO
    // =========================================
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

});