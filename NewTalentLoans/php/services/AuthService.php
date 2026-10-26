<?php
class AuthService
{
    private $conexion;
    private $columnas;

    public function __construct($conexion, $columnas)
    {
        $this->conexion = $conexion;
        $this->columnas = $columnas;
    }

    public function iniciarSesion($correo, $contrasena)
    {
        $acceso = $this->columnas['acceso'];
        $usuario = $this->columnas['usuario'];
        $sql = 'SELECT U.[' . $usuario['id'] . '] AS id, U.[' . $usuario['nombre'] . '] AS nombre, U.[' . $usuario['apellido'] . '] AS apellido, A.[' . $acceso['clave'] . '] AS clave, A.[' . $acceso['rol'] . '] AS rolId FROM [' . $usuario['tabla'] . '] U INNER JOIN [' . $acceso['tabla'] . '] A ON U.[' . $usuario['acceso'] . '] = A.[' . $acceso['id'] . '] WHERE A.[' . $acceso['correo'] . '] = ? AND A.[' . $acceso['activo'] . '] = 1';
        $consulta = $this->conexion->prepare($sql);
        $consulta->execute(array(strtolower(trim($correo))));
        $usuarioEncontrado = $consulta->fetch();
        if (!$usuarioEncontrado || !password_verify($contrasena, $usuarioEncontrado['clave'])) {
            return false;
        }
        unset($usuarioEncontrado['clave']);
        return $usuarioEncontrado;
    }
}