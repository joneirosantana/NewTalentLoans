<?php
/* Columnas de ubicación y acceso usadas por el registro y el inicio de sesión. */
function obtenerColumnasUsuario()
{
    return array(
        'pais' => array('tabla' => 'Pais', 'id' => 'Pais_ID', 'nombre' => 'Pais_Nombre'),
        'provincia' => array('tabla' => 'Provincia', 'id' => 'Provincia_ID', 'nombre' => 'Provincia_Nombre', 'relacion' => 'Provincia_PaisId'),
        'ciudad' => array('tabla' => 'Ciudad', 'id' => 'Ciudad_ID', 'nombre' => 'Ciudad_Nombre', 'relacion' => 'Ciudad_ProvinciaId'),
        'direccion' => array('tabla' => 'Direccion', 'id' => 'Direccion_ID', 'ciudad' => 'Direccion_CiudadId', 'descripcion' => 'Direccion_Descripcion'),
        'acceso' => array('tabla' => 'Acceso', 'id' => 'Acceso_ID', 'rol' => 'Acceso_RolId', 'correo' => 'Acceso_Correo', 'clave' => 'Acceso_ContrasenaHash', 'activo' => 'Acceso_Activo'),
        'usuario' => array('tabla' => 'Usuario', 'id' => 'Usuario_ID', 'direccion' => 'Usuario_DireccionId', 'acceso' => 'Usuario_AccesoId', 'nombre' => 'Usuario_Nombre', 'apellido' => 'Usuario_Apellido', 'cedula' => 'Usuario_Cedula', 'sueldo' => 'Usuario_Sueldo'),
        'telefono' => array('tabla' => 'Telefono', 'id' => 'Telefono_ID', 'usuario' => 'Telefono_UsuarioId', 'numero' => 'Telefono_Numero'),
        'correo' => array('tabla' => 'Correo', 'id' => 'Correo_ID', 'usuario' => 'Correo_UsuarioId', 'direccion' => 'Correo_Direccion')
    );
}
