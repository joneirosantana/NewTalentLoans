<?php
class CrudRepository
{
    private $conexion;
    private $entidades;

    public function __construct($conexion, $entidades)
    {
        $this->conexion = $conexion;
        $this->entidades = $entidades;
    }

    public function listar($recurso)
    {
        $entidad = $this->buscarEntidad($recurso);
        $sql = 'SELECT * FROM ' . $this->identificador($entidad['tabla']);
        return $this->conexion->query($sql)->fetchAll();
    }

    public function listarSolicitudesPorUsuario($usuarioId)
    {
        $entidad = $this->buscarEntidad('solicitudes');
        $campoUsuario = 'Solicitud_UsuarioId';
        if (!in_array($campoUsuario, $entidad['campos'], true)) {
            throw new RuntimeException('La relación Solicitud_UsuarioId no está configurada.');
        }
        $sql = 'SELECT * FROM ' . $this->identificador($entidad['tabla']) . ' WHERE ' . $this->identificador($campoUsuario) . ' = ?';
        $consulta = $this->conexion->prepare($sql);
        $consulta->execute(array($usuarioId));
        return $consulta->fetchAll();
    }
    public function obtener($recurso, $id)
    {
        $entidad = $this->buscarEntidad($recurso);
        $sql = 'SELECT * FROM ' . $this->identificador($entidad['tabla']) . ' WHERE ' . $this->identificador($entidad['id']) . ' = ?';
        $consulta = $this->conexion->prepare($sql);
        $consulta->execute(array($id));
        return $consulta->fetch();
    }

    public function crear($recurso, $datos)
    {
        $entidad = $this->buscarEntidad($recurso);
        $valores = $this->filtrarCampos($entidad, $datos);
        if (count($valores) === 0) {
            throw new InvalidArgumentException('No se recibieron campos permitidos para crear el registro.');
        }
        $columnas = array_keys($valores);
        $nombres = array_map(array($this, 'identificador'), $columnas);
        $marcadores = array_fill(0, count($columnas), '?');
        $sql = 'INSERT INTO ' . $this->identificador($entidad['tabla']) . ' (' . implode(', ', $nombres) . ') OUTPUT INSERTED.' . $this->identificador($entidad['id']) . ' VALUES (' . implode(', ', $marcadores) . ')';
        $consulta = $this->conexion->prepare($sql);
        $consulta->execute(array_values($valores));
        return $consulta->fetchColumn();
    }

    public function actualizar($recurso, $id, $datos)
    {
        $entidad = $this->buscarEntidad($recurso);
        $valores = $this->filtrarCampos($entidad, $datos);
        if (count($valores) === 0) {
            throw new InvalidArgumentException('No se recibieron campos permitidos para actualizar.');
        }
        $asignaciones = array();
        foreach (array_keys($valores) as $columna) {
            $asignaciones[] = $this->identificador($columna) . ' = ?';
        }
        $sql = 'UPDATE ' . $this->identificador($entidad['tabla']) . ' SET ' . implode(', ', $asignaciones) . ' WHERE ' . $this->identificador($entidad['id']) . ' = ?';
        $parametros = array_values($valores);
        $parametros[] = $id;
        $consulta = $this->conexion->prepare($sql);
        $consulta->execute($parametros);
        return $consulta->rowCount() > 0;
    }

    public function eliminar($recurso, $id)
    {
        $entidad = $this->buscarEntidad($recurso);
        $sql = 'DELETE FROM ' . $this->identificador($entidad['tabla']) . ' WHERE ' . $this->identificador($entidad['id']) . ' = ?';
        $consulta = $this->conexion->prepare($sql);
        $consulta->execute(array($id));
        return $consulta->rowCount() > 0;
    }

    private function buscarEntidad($recurso)
    {
        if (!isset($this->entidades[$recurso])) {
            throw new InvalidArgumentException('El recurso solicitado no está disponible.');
        }
        return $this->entidades[$recurso];
    }

    private function filtrarCampos($entidad, $datos)
    {
        $resultado = array();
        foreach ($entidad['campos'] as $campo) {
            if (array_key_exists($campo, $datos)) {
                $resultado[$campo] = $datos[$campo];
            }
        }
        return $resultado;
    }

    private function identificador($nombre)
    {
        if (!preg_match('/^[A-Za-z][A-Za-z0-9_]*$/', $nombre)) {
            throw new InvalidArgumentException('Nombre de tabla o columna no válido.');
        }
        return '[' . $nombre . ']';
    }
}

