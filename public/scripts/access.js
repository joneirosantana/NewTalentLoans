document.addEventListener('DOMContentLoaded', async function () {
        var requested = document.body.dataset.access || 'user';

    try {
        var response = await NTLApi.fetch('http://api.newtalentloans.local/?recurso=identidad', { credentials: 'same-origin' });
        var result = await response.json();

        if (!response.ok || !result.success) {
            window.location.replace('iniciar-sesion.html');
            return;
        }

        var role = result.usuario.rol || '';
        var allowed = requested === 'user' || requested === 'staff' && role !== 'Cliente' || requested === role.toLowerCase();
        if (!allowed) window.location.replace(role === 'Cliente' ? 'dashboard.html' : 'empleados.html');
    } catch (error) {
        window.location.replace('iniciar-sesion.html');
    }
});
