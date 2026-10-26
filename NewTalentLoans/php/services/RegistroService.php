<?php
class RegistroService
{
    private $conexion;
    private $columnas;
    private $configuracion;

    public function __construct($conexion, $columnas, $configuracion)
    {
        $this->conexion = $conexion;
        $this->columnas = $columnas;
        $this->configuracion = $configuracion;
    }

    public function registrar($datos)
    {
        $requeridos = array('nombre', 'apellido', 'cedula', 'direccion', 'pais', 'provincia', 'ciudad', 'telefono', 'correo', 'contrasena');
        foreach ($requeridos as $campo) {
            if (!isset($datos[$campo]) || trim((string)$datos[$campo]) === '') {
                throw new InvalidArgumentException('El campo ' . $campo . ' es obligatorio.');
            }
        }
        if (!filter_var($datos['correo'], FILTER_VALIDATE_EMAIL)) {
            throw new InvalidArgumentException('El correo electrónico no tiene un formato válido.');
        }
        if (strlen($datos['contrasena']) < 8) {
            throw new InvalidArgumentException('La contraseña debe tener al menos 8 caracteres.');
        }
        $sueldo = isset($datos['sueldo']) && is_numeric($datos['sueldo']) ? (float)$datos['sueldo'] : 0;
        if ($sueldo < 0) throw new InvalidArgumentException('El sueldo mensual debe ser un monto mayor o igual a cero.');
        if ($this->configuracion['rolClienteId'] === '') {
            throw new RuntimeException('Configure NTL_CLIENT_ROLE_ID con el ID del rol Cliente ya creado en la base de datos.');
        }

        $this->conexion->beginTransaction();
        try {
            $columnas = $this->columnas;
            $paisId = $this->obtenerOCrearCatalogo($columnas['pais'], $datos['pais']);
            $provinciaId = $this->obtenerOCrearCatalogo($columnas['provincia'], $datos['provincia'], $columnas['provincia']['relacion'], $paisId);
            $ciudadId = $this->obtenerOCrearCatalogo($columnas['ciudad'], $datos['ciudad'], $columnas['ciudad']['relacion'], $provinciaId);
            $direccion = $columnas['direccion'];
            $direccionId = $this->insertar($direccion['tabla'], array($direccion['ciudad'] => $ciudadId, $direccion['descripcion'] => trim($datos['direccion'])));

            $acceso = $columnas['acceso'];
            $hash = password_hash($datos['contrasena'], PASSWORD_DEFAULT);
            $accesoId = $this->insertar($acceso['tabla'], array($acceso['rol'] => $this->configuracion['rolClienteId'], $acceso['correo'] => strtolower(trim($datos['correo'])), $acceso['clave'] => $hash, $acceso['activo'] => 1));

            $usuario = $columnas['usuario'];
            $usuarioId = $this->insertar($usuario['tabla'], array($usuario['direccion'] => $direccionId, $usuario['acceso'] => $accesoId, $usuario['nombre'] => trim($datos['nombre']), $usuario['apellido'] => trim($datos['apellido']), $usuario['cedula'] => trim($datos['cedula']), $usuario['sueldo'] => $sueldo));
            $this->insertar($columnas['telefono']['tabla'], array($columnas['telefono']['usuario'] => $usuarioId, $columnas['telefono']['numero'] => trim($datos['telefono'])));
            $this->insertar($columnas['correo']['tabla'], array($columnas['correo']['usuario'] => $usuarioId, $columnas['correo']['direccion'] => strtolower(trim($datos['correo']))));

            $this->conexion->commit();
            return array('id' => $usuarioId, 'nombre' => trim($datos['nombre']), 'apellido' => trim($datos['apellido']), 'correo' => strtolower(trim($datos['correo'])));
        } catch (Throwable $error) {
            if ($this->conexion->inTransaction()) {
                $this->conexion->rollBack();
            }
            throw $error;
        }
    }

    private function obtenerOCrearCatalogo($entidad, $nombre, $columnaRelacion, $idRelacion)
    {
        $sql = 'SELECT [' . $entidad['id'] . '] FROM [' . $entidad['tabla'] . '] WHERE [' . $entidad['nombre'] . '] = ?';
        $parametros = array(trim($nombre));
        if ($columnaRelacion !== null) {
            $sql .= ' AND [' . $columnaRelacion . '] = ?';
            $parametros[] = $idRelacion;
        }
        $consulta = $this->conexion->prepare($sql);
        $consulta->execute($parametros);
        $id = $consulta->fetchColumn();
        if ($id !== false) {
            return $id;
        }
        $valores = array($entidad['nombre'] => trim($nombre));
        if ($columnaRelacion !== null) {
            $valores[$columnaRelacion] = $idRelacion;
        }
        return $this->insertar($entidad['tabla'], $valores);
    }

    private function insertar($tabla, $valores)
    {
        $columnas = array_keys($valores);
        $marcadores = array_fill(0, count($columnas), '?');
        $nombres = array();
        foreach ($columnas as $columna) {
            $nombres[] = '[' . $columna . ']';
        }
        $sql = 'INSERT INTO [' . $tabla . '] (' . implode(', ', $nombres) . ') OUTPUT INSERTED.[' . $this->columnaId($tabla) . '] VALUES (' . implode(', ', $marcadores) . ')';
        $consulta = $this->conexion->prepare($sql);
        $consulta->execute(array_values($valores));
        return $consulta->fetchColumn();
    }

    private function columnaId($tabla)
    {
        foreach ($this->columnas as $entidad) {
            if ($entidad['tabla'] === $tabla) {
                return $entidad['id'];
            }
        }
        throw new RuntimeException('No se encontró la columna ID para ' . $tabla . '.');
    }
}
