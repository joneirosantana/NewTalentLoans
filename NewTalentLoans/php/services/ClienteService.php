<?php
class ClienteService
{
    private $conexion;
    private $columnas;
    private $rolClienteId;

    public function __construct($conexion, $columnas, $rolClienteId)
    {
        $this->conexion = $conexion;
        $this->columnas = $columnas;
        $this->rolClienteId = $rolClienteId;
    }

    public function listar()
    {
        $sql = $this->consultaBase() . ' ORDER BY U.[Usuario_ID] DESC';
        $consulta = $this->conexion->prepare($sql);
        $consulta->execute(array($this->rolClienteId));
        return $consulta->fetchAll();
    }

    public function obtener($id)
    {
        $sql = $this->consultaBase() . ' AND U.[Usuario_ID] = ?';
        $consulta = $this->conexion->prepare($sql);
        $consulta->execute(array($this->rolClienteId, $id));
        $cliente = $consulta->fetch();
        return $cliente ? $cliente : false;
    }

    public function actualizar($id, $datos)
    {
        $campos = array('cedula', 'nombre', 'apellido', 'telefono', 'correo', 'direccion');
        foreach ($campos as $campo) {
            if (!isset($datos[$campo]) || trim((string)$datos[$campo]) === '') {
                throw new InvalidArgumentException('El campo ' . $campo . ' es obligatorio.');
            }
        }
        if (!filter_var($datos['correo'], FILTER_VALIDATE_EMAIL)) {
            throw new InvalidArgumentException('El correo electrónico no tiene un formato válido.');
        }
        if (!$this->obtener($id)) {
            return false;
        }

        $this->conexion->beginTransaction();
        try {
            $sqlUsuario = 'UPDATE [Usuario] SET [Usuario_Cedula] = ?, [Usuario_Nombre] = ?, [Usuario_Apellido] = ?, [Usuario_Sueldo] = ? WHERE [Usuario_ID] = ?';
            $this->conexion->prepare($sqlUsuario)->execute(array(trim($datos['cedula']), trim($datos['nombre']), trim($datos['apellido']), isset($datos['sueldo']) ? (float)$datos['sueldo'] : 0, $id));
            $sqlAcceso = 'UPDATE [Acceso] SET [Acceso_Correo] = ? WHERE [Acceso_ID] = (SELECT [Usuario_AccesoId] FROM [Usuario] WHERE [Usuario_ID] = ?)';
            $this->conexion->prepare($sqlAcceso)->execute(array(strtolower(trim($datos['correo'])), $id));
            $sqlTelefono = 'UPDATE [Telefono] SET [Telefono_Numero] = ? WHERE [Telefono_UsuarioId] = ?';
            $this->conexion->prepare($sqlTelefono)->execute(array(trim($datos['telefono']), $id));
            $sqlCorreo = 'UPDATE [Correo] SET [Correo_Direccion] = ? WHERE [Correo_UsuarioId] = ?';
            $this->conexion->prepare($sqlCorreo)->execute(array(strtolower(trim($datos['correo'])), $id));
            $sqlDireccion = 'UPDATE [Direccion] SET [Direccion_Descripcion] = ? WHERE [Direccion_ID] = (SELECT [Usuario_DireccionId] FROM [Usuario] WHERE [Usuario_ID] = ?)';
            $this->conexion->prepare($sqlDireccion)->execute(array(trim($datos['direccion']), $id));
            $this->conexion->commit();
            return true;
        } catch (Throwable $error) {
            if ($this->conexion->inTransaction()) {
                $this->conexion->rollBack();
            }
            throw $error;
        }
    }

    public function desactivar($id)
    {
        if (!$this->obtener($id)) {
            return false;
        }
        $sql = 'UPDATE [Acceso] SET [Acceso_Activo] = 0 WHERE [Acceso_ID] = (SELECT [Usuario_AccesoId] FROM [Usuario] WHERE [Usuario_ID] = ?)';
        $consulta = $this->conexion->prepare($sql);
        $consulta->execute(array($id));
        return $consulta->rowCount() > 0;
    }

    private function consultaBase()
    {
        return 'SELECT U.[Usuario_ID] AS id, U.[Usuario_Cedula] AS cedula, U.[Usuario_Nombre] AS nombre, U.[Usuario_Apellido] AS apellido, U.[Usuario_Sueldo] AS sueldo, A.[Acceso_Correo] AS correo, (SELECT TOP 1 T.[Telefono_Numero] FROM [Telefono] T WHERE T.[Telefono_UsuarioId] = U.[Usuario_ID] ORDER BY T.[Telefono_ID]) AS telefono, D.[Direccion_Descripcion] AS direccion, Ci.[Ciudad_Nombre] AS ciudad, Pr.[Provincia_Nombre] AS provincia, Pa.[Pais_Nombre] AS pais FROM [Usuario] U INNER JOIN [Acceso] A ON U.[Usuario_AccesoId] = A.[Acceso_ID] INNER JOIN [Direccion] D ON U.[Usuario_DireccionId] = D.[Direccion_ID] INNER JOIN [Ciudad] Ci ON D.[Direccion_CiudadId] = Ci.[Ciudad_ID] INNER JOIN [Provincia] Pr ON Ci.[Ciudad_ProvinciaId] = Pr.[Provincia_ID] INNER JOIN [Pais] Pa ON Pr.[Provincia_PaisId] = Pa.[Pais_ID] WHERE A.[Acceso_Activo] = 1 AND A.[Acceso_RolId] = ?';
    }
}