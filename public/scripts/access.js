document.addEventListener('DOMContentLoaded', async function () {
    var requested = document.body.dataset.access || 'user';

    try {
        var response = await fetch('api/?recurso=identidad', { credentials: 'same-origin' });
        var result = await response.json();

        if (!response.ok || !result.success) {
            window.location.replace('iniciar-sesion.html');
            return;
        }

        var isAdmin = Boolean(result.usuario.esAdministrador);
        if (requested === 'admin' && !isAdmin) {
            window.location.replace('solicitudes.html');
        } else if (requested === 'client' && isAdmin) {
            window.location.replace('panel-servicios.html');
        }
    } catch (error) {
        window.location.replace('iniciar-sesion.html');
    }
});
