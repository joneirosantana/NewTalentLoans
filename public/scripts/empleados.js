(() => {
    const money = n => Number(n || 0).toLocaleString('es-DO', { style: 'currency', currency: 'DOP' });
    const add = (id, value) => document.getElementById(id).textContent = value;
    async function load() {
        const who = await (await NTLApi.fetch('/?recurso=identidad')).json();
        const u = who.usuario || {};
        add('role', u.rol || 'Empleado');
        add('title', u.rol === 'RRHH' ? 'Recursos Humanos' : u.rol === 'Contable' ? 'Contabilidad' : u.rol === 'Solicitudes' ? 'Revisión de solicitudes' : u.rol === 'Gerente' ? 'Gerencia y control' : 'Panel interno');
        const d = await (await NTLApi.fetch('/?recurso=dashboard')).json(), s = d.datos || {};
        add('activos', s.prestamosActivos || 0); add('pendientes', s.solicitudesPendientes || 0); add('deuda', money(s.deuda)); add('mora', money(s.mora));
        const links = { Administrador: [['Empresas','empresas.html'],['Clientes','clientes.html'],['Solicitudes','gestion-creditos.html?recurso=solicitudes'],['Préstamos','prestamos.html'],['Pagos','pagos.html'],['Reportes','reportes.html']], RRHH: [['Personal','clientes.html'],['Pendientes','empleados-pendientes.html'],['Solicitudes','gestion-creditos.html?recurso=solicitudes']], Contable: [['Pagos','pagos.html'],['Préstamos','prestamos.html'],['Reportes','reportes.html']], Solicitudes: [['Solicitudes','gestion-creditos.html?recurso=solicitudes'],['Préstamos','prestamos.html']], Gerente: [['Dashboard','empleados.html'],['Reportes','reportes.html'],['Personal','clientes.html']] }[u.rol] || [];
        document.getElementById('menu').innerHTML = links.map(x => `<a href="${x[1]}">${x[0]}</a>`).join('');
        document.getElementById('actions').innerHTML = links.map(x => `<a class="panel" href="${x[1]}">${x[0]}</a>`).join('');
        const c = await (await NTLApi.fetch('/?recurso=clientes')).json();
        document.getElementById('rows').innerHTML = (c.datos || []).map(x => x.privacidad === 'agregada' ? `<tr><td>${x.Empresa_Nombre || ''}</td><td>Información agregada</td><td>${money(x.sueldo_total)}</td><td>${x.clientes || 0} clientes</td></tr>` : `<tr><td>${x.Cliente_Nombre || ''} ${x.Cliente_Apellido || ''}</td><td>${x.Cliente_Cedula || ''}</td><td>${money(x.Cliente_Sueldo)}</td><td>${x.Acceso_Activo ? 'Activo' : 'Inactivo'}</td></tr>`).join('') || '<tr><td colspan="4">No hay registros disponibles.</td></tr>';
    }
    load().catch(() => location.href = 'iniciar-sesion.html');
    document.getElementById('logout').onclick = () => NTLApi.fetch('/?recurso=cerrar-sesion', { method: 'POST' }).then(() => location.href = 'iniciar-sesion.html');
})();
