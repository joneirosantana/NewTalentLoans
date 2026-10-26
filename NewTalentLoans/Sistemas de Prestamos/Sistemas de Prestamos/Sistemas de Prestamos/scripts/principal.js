document.addEventListener('DOMContentLoaded', function() {

    // =========================================
    // MENÚ MÓVIL
    // =========================================
    const menuToggle = document.getElementById('menuToggle');
    const navMenu = document.getElementById('navMenu');

    if (menuToggle && navMenu) {
        menuToggle.addEventListener('click', function() {
            navMenu.classList.toggle('active');
        });

        // Cerrar el menú al hacer clic en un enlace
        navMenu.querySelectorAll('a').forEach(link => {
            link.addEventListener('click', () => {
                navMenu.classList.remove('active');
            });
        });
    }

    // =========================================
    // ANIMACIÓN AL HACER SCROLL
    // =========================================
    const elementos = document.querySelectorAll('.servicio-card, .stat-card, .beneficios-lista li');

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.style.opacity = '1';
                entry.target.style.transform = 'translateY(0)';
            }
        });
    }, { threshold: 0.1 });

    elementos.forEach(el => {
        el.style.opacity = '0';
        el.style.transform = 'translateY(30px)';
        el.style.transition = 'all 0.6s ease';
        observer.observe(el);
    });

    // =========================================
    // HEADER CON SCROLL
    // =========================================
    const header = document.querySelector('.header');
    window.addEventListener('scroll', function() {
        if (window.scrollY > 50) {
            header.style.boxShadow = '0 4px 20px rgba(0,0,0,0.12)';
        } else {
            header.style.boxShadow = '0 2px 10px rgba(0,0,0,0.08)';
        }
    });

        // =========================================
    // MODAL: TÉRMINOS Y CONDICIONES
    // =========================================
    const linkTerminos = document.getElementById('linkTerminos');
    const modalTerminos = document.getElementById('modalTerminos');
    const cerrarTerminos = document.getElementById('cerrarTerminos');
    const btnCerrarTerminos = document.getElementById('btnCerrarTerminos');

    if (linkTerminos) {
        linkTerminos.addEventListener('click', function(e) {
            e.preventDefault();
            modalTerminos.classList.add('active');
        });
    }

    if (cerrarTerminos) {
        cerrarTerminos.addEventListener('click', function() {
            modalTerminos.classList.remove('active');
        });
    }

    if (btnCerrarTerminos) {
        btnCerrarTerminos.addEventListener('click', function() {
            modalTerminos.classList.remove('active');
        });
    }

    if (modalTerminos) {
        modalTerminos.addEventListener('click', function(e) {
            if (e.target === modalTerminos) {
                modalTerminos.classList.remove('active');
            }
        });
    }

    // =========================================
    // MODAL: POLÍTICA DE PRIVACIDAD
    // =========================================
    const linkPrivacidad = document.getElementById('linkPrivacidad');
    const modalPrivacidad = document.getElementById('modalPrivacidad');
    const cerrarPrivacidad = document.getElementById('cerrarPrivacidad');
    const btnCerrarPrivacidad = document.getElementById('btnCerrarPrivacidad');

    if (linkPrivacidad) {
        linkPrivacidad.addEventListener('click', function(e) {
            e.preventDefault();
            modalPrivacidad.classList.add('active');
        });
    }

    if (cerrarPrivacidad) {
        cerrarPrivacidad.addEventListener('click', function() {
            modalPrivacidad.classList.remove('active');
        });
    }

    if (btnCerrarPrivacidad) {
        btnCerrarPrivacidad.addEventListener('click', function() {
            modalPrivacidad.classList.remove('active');
        });
    }

    if (modalPrivacidad) {
        modalPrivacidad.addEventListener('click', function(e) {
            if (e.target === modalPrivacidad) {
                modalPrivacidad.classList.remove('active');
            }
        });
    }

    // =========================================
    // CERRAR MODALES CON LA TECLA ESC
    // =========================================
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') {
            document.querySelectorAll('.modal-overlay.active').forEach(modal => {
                modal.classList.remove('active');
            });
        }
    });

});