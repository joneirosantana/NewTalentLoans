<?php
class ModoDemoRepository
{
    private $archivo;
    private $archivoBloqueo;
    private $bloqueo;
    private $datos;
    private $entidades;

    public function __construct($entidades)
    {
        $this->entidades = $entidades;
        $directorio = __DIR__ . '/../storage';
        if (!is_dir($directorio) && !mkdir($directorio, 0775, true)) {
            throw new RuntimeException('No se pudo crear el almacenamiento local de demostración.');
        }
        $this->archivo = $directorio . '/datos_demo.json';
        $this->archivoBloqueo = $directorio . '/datos_demo.lock';
        $this->bloqueo = fopen($this->archivoBloqueo, 'c');
        if (!$this->bloqueo || !flock($this->bloqueo, LOCK_EX)) {
            throw new RuntimeException('No se pudo abrir el almacenamiento local de demostración.');
        }
        $contenido = is_file($this->archivo) ? file_get_contents($this->archivo) : false;
        $this->datos = $contenido ? json_decode($contenido, true) : null;
        if (!is_array($this->datos)) {
            $this->inicializarDatos();
            $this->guardar();
        }
    }

    public function __destruct()
    {
        if (is_resource($this->bloqueo)) {
            flock($this->bloqueo, LOCK_UN);
            fclose($this->bloqueo);
        }
    }

    public function obtenerRolAdministradorId()
    {
        return 1;
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
        $correoNormalizado = strtolower(trim($datos['correo']));
        foreach ($this->datos['Acceso'] as $acceso) {
            if (strtolower($acceso['Acceso_Correo']) === $correoNormalizado) {
                throw new InvalidArgumentException('Ya existe una cuenta con ese correo.');
            }
        }

        $paisId = $this->obtenerOCrearCatalogo('Pais', 'Pais_ID', 'Pais_Nombre', trim($datos['pais']));
        $provinciaId = $this->obtenerOCrearCatalogo('Provincia', 'Provincia_ID', 'Provincia_Nombre', trim($datos['provincia']), 'Provincia_PaisId', $paisId);
        $ciudadId = $this->obtenerOCrearCatalogo('Ciudad', 'Ciudad_ID', 'Ciudad_Nombre', trim($datos['ciudad']), 'Ciudad_ProvinciaId', $provinciaId);
        $direccionId = $this->crearEnTabla('Direccion', 'Direccion_ID', array('Direccion_CiudadId' => $ciudadId, 'Direccion_Descripcion' => trim($datos['direccion'])));
        $hash = password_hash($datos['contrasena'], PASSWORD_DEFAULT);
        $accesoId = $this->crearEnTabla('Acceso', 'Acceso_ID', array('Acceso_RolId' => 2, 'Acceso_Correo' => $correoNormalizado, 'Acceso_ContrasenaHash' => $hash, 'Acceso_Activo' => 1));
        $usuarioId = $this->crearEnTabla('Usuario', 'Usuario_ID', array('Usuario_DireccionId' => $direccionId, 'Usuario_AccesoId' => $accesoId, 'Usuario_Nombre' => trim($datos['nombre']), 'Usuario_Apellido' => trim($datos['apellido']), 'Usuario_Cedula' => trim($datos['cedula']), 'Usuario_Sueldo' => $sueldo));
        $this->crearEnTabla('Telefono', 'Telefono_ID', array('Telefono_UsuarioId' => $usuarioId, 'Telefono_Numero' => trim($datos['telefono'])));
        $this->crearEnTabla('Correo', 'Correo_ID', array('Correo_UsuarioId' => $usuarioId, 'Correo_Direccion' => $correoNormalizado));
        $this->guardar();
        return array('id' => $usuarioId, 'nombre' => trim($datos['nombre']), 'apellido' => trim($datos['apellido']), 'correo' => $correoNormalizado);
    }

    public function iniciarSesion($correo, $contrasena)
    {
        $correoNormalizado = strtolower(trim($correo));
        foreach ($this->datos['Acceso'] as $acceso) {
            if (strtolower($acceso['Acceso_Correo']) === $correoNormalizado && (int)$acceso['Acceso_Activo'] === 1 && password_verify($contrasena, $acceso['Acceso_ContrasenaHash'])) {
                foreach ($this->datos['Usuario'] as $usuario) {
                    if ((string)$usuario['Usuario_AccesoId'] === (string)$acceso['Acceso_ID']) {
                        return array('id' => $usuario['Usuario_ID'], 'nombre' => $usuario['Usuario_Nombre'], 'apellido' => $usuario['Usuario_Apellido'], 'rolId' => $acceso['Acceso_RolId']);
                    }
                }
            }
        }
        return false;
    }

    public function listarClientes()
    {
        $clientes = array();
        foreach ($this->datos['Usuario'] as $usuario) {
            $acceso = $this->buscarFila('Acceso', 'Acceso_ID', $usuario['Usuario_AccesoId']);
            if (!$acceso || (int)$acceso['Acceso_Activo'] !== 1 || (int)$acceso['Acceso_RolId'] !== 2) {
                continue;
            }
            $direccion = $this->buscarFila('Direccion', 'Direccion_ID', $usuario['Usuario_DireccionId']);
            $ciudad = $direccion ? $this->buscarFila('Ciudad', 'Ciudad_ID', $direccion['Direccion_CiudadId']) : false;
            $provincia = $ciudad ? $this->buscarFila('Provincia', 'Provincia_ID', $ciudad['Ciudad_ProvinciaId']) : false;
            $pais = $provincia ? $this->buscarFila('Pais', 'Pais_ID', $provincia['Provincia_PaisId']) : false;
            $telefono = $this->buscarFila('Telefono', 'Telefono_UsuarioId', $usuario['Usuario_ID']);
            $clientes[] = array(
                'id' => $usuario['Usuario_ID'],
                'cedula' => $usuario['Usuario_Cedula'],
                'sueldo' => isset($usuario['Usuario_Sueldo']) ? $usuario['Usuario_Sueldo'] : 0,
                'nombre' => $usuario['Usuario_Nombre'],
                'apellido' => $usuario['Usuario_Apellido'],
                'telefono' => $telefono ? $telefono['Telefono_Numero'] : '',
                'correo' => $acceso['Acceso_Correo'],
                'direccion' => $direccion ? $direccion['Direccion_Descripcion'] : '',
                'ciudad' => $ciudad ? $ciudad['Ciudad_Nombre'] : '',
                'provincia' => $provincia ? $provincia['Provincia_Nombre'] : '',
                'pais' => $pais ? $pais['Pais_Nombre'] : ''
            );
        }
        return $clientes;
    }

    public function obtenerCliente($id)
    {
        foreach ($this->listarClientes() as $cliente) {
            if ((string)$cliente['id'] === (string)$id) {
                return $cliente;
            }
        }
        return false;
    }

    public function actualizarCliente($id, $datos)
    {
        $campos = array('cedula', 'nombre', 'apellido', 'telefono', 'correo', 'direccion');
        foreach ($campos as $campo) {
            if (!isset($datos[$campo]) || trim((string)$datos[$campo]) === '') {
                throw new InvalidArgumentException('El campo ' . $campo . ' es obligatorio.');
            }
        }
        if (!filter_var($datos['correo'], FILTER_VALIDATE_EMAIL)) {
            throw new InvalidArgumentException('El correo electrónico no tiene un formato válido.');
        }        $cliente = $this->obtenerCliente($id);
        if (!$cliente) {
            return false;
        }
        $usuarioIndice = $this->buscarIndice('Usuario', 'Usuario_ID', $id);
        $usuario = $this->datos['Usuario'][$usuarioIndice];
        $accesoIndice = $this->buscarIndice('Acceso', 'Acceso_ID', $usuario['Usuario_AccesoId']);
        $direccionIndice = $this->buscarIndice('Direccion', 'Direccion_ID', $usuario['Usuario_DireccionId']);
        $telefonoIndice = $this->buscarIndice('Telefono', 'Telefono_UsuarioId', $id);
        $correoIndice = $this->buscarIndice('Correo', 'Correo_UsuarioId', $id);
        $this->datos['Usuario'][$usuarioIndice]['Usuario_Cedula'] = trim($datos['cedula']);
        $this->datos['Usuario'][$usuarioIndice]['Usuario_Sueldo'] = isset($datos['sueldo']) ? (float)$datos['sueldo'] : 0;
        $this->datos['Usuario'][$usuarioIndice]['Usuario_Nombre'] = trim($datos['nombre']);
        $this->datos['Usuario'][$usuarioIndice]['Usuario_Apellido'] = trim($datos['apellido']);
        $this->datos['Acceso'][$accesoIndice]['Acceso_Correo'] = strtolower(trim($datos['correo']));
        $this->datos['Direccion'][$direccionIndice]['Direccion_Descripcion'] = trim($datos['direccion']);
        if ($telefonoIndice !== false) {
            $this->datos['Telefono'][$telefonoIndice]['Telefono_Numero'] = trim($datos['telefono']);
        }
        if ($correoIndice !== false) {
            $this->datos['Correo'][$correoIndice]['Correo_Direccion'] = strtolower(trim($datos['correo']));
        }
        $this->guardar();
        return true;
    }

    public function desactivarCliente($id)
    {
        $cliente = $this->obtenerCliente($id);
        if (!$cliente) {
            return false;
        }
        $usuarioIndice = $this->buscarIndice('Usuario', 'Usuario_ID', $id);
        $accesoId = $this->datos['Usuario'][$usuarioIndice]['Usuario_AccesoId'];
        $accesoIndice = $this->buscarIndice('Acceso', 'Acceso_ID', $accesoId);
        $this->datos['Acceso'][$accesoIndice]['Acceso_Activo'] = 0;
        $this->guardar();
        return true;
    }

    public function resolverSolicitud($id, $decision, $tipoPrestamoId)
    {
        $decision = ucfirst(strtolower(trim($decision)));
        if ($decision !== 'Aprobada' && $decision !== 'Rechazada') {
            throw new InvalidArgumentException('La decisión debe ser Aprobada o Rechazada.');
        }
        $indiceSolicitud = $this->buscarIndice('Solicitud', 'Solicitud_ID', $id);
        if ($indiceSolicitud === false) {
            return false;
        }
        $solicitud = $this->datos['Solicitud'][$indiceSolicitud];
        if (strcasecmp((string)$solicitud['Solicitud_Estado'], 'Pendiente') !== 0) {
            throw new InvalidArgumentException('Solo se pueden resolver solicitudes pendientes.');
        }
        $prestamoId = null;
        if ($decision === 'Aprobada') {
            $usuarioSolicitud = $this->buscarFila('Usuario', 'Usuario_ID', $solicitud['Solicitud_UsuarioId']);
            $sueldoCliente = $usuarioSolicitud && isset($usuarioSolicitud['Usuario_Sueldo']) ? (float)$usuarioSolicitud['Usuario_Sueldo'] : 0;
            if ((float)$solicitud['Solicitud_Monto'] > $sueldoCliente && (empty($solicitud['Solicitud_GaranteNombre']) || empty($solicitud['Solicitud_GaranteCedula']) || empty($solicitud['Solicitud_GaranteTelefono']))) throw new InvalidArgumentException('Faltan los datos del garante requerido por el monto del préstamo.');
            if (($tipoPrestamoId === null || $tipoPrestamoId === '') && isset($solicitud['Solicitud_TipoPrestamoId'])) $tipoPrestamoId = $solicitud['Solicitud_TipoPrestamoId'];
            if ($tipoPrestamoId === null || $tipoPrestamoId === '') {
                throw new InvalidArgumentException('Seleccione el tipo de préstamo para aprobar la solicitud.');
            }
            $tipo = $this->buscarFila('TipoPrestamo', 'TipoPrestamo_ID', $tipoPrestamoId);
            if (!$tipo) {
                throw new InvalidArgumentException('El tipo de préstamo seleccionado no existe.');
            }
            foreach ($this->datos['Prestamo'] as $prestamo) {
                if ((string)$prestamo['Prestamo_SolicitudId'] === (string)$id) {
                    throw new InvalidArgumentException('Esta solicitud ya tiene un préstamo asociado.');
                }
            }
            $estado = false;
            foreach ($this->datos['EstadoPrestamo'] as $registroEstado) {
                if (strcasecmp($registroEstado['EstadoPrestamo_Nombre'], 'Activo') === 0 || strcasecmp($registroEstado['EstadoPrestamo_Nombre'], 'Aprobado') === 0) {
                    $estado = $registroEstado;
                    if (strcasecmp($registroEstado['EstadoPrestamo_Nombre'], 'Activo') === 0) {
                        break;
                    }
                }
            }
            if (!$estado) {
                throw new RuntimeException('Agregue un estado de préstamo llamado Activo o Aprobado.');
            }
            $entidadPrestamo = $this->entidades['prestamos'];
            $prestamoId = $this->siguienteId($entidadPrestamo['tabla']);
            if (!empty($solicitud['Solicitud_GaranteNombre'])) {
                $garanteId = $this->siguienteId('Garante');
                $this->datos['Garante'][] = array('Garante_ID' => $garanteId, 'Garante_PrestamoId' => $prestamoId, 'Garante_Nombre' => $solicitud['Solicitud_GaranteNombre'], 'Garante_Cedula' => $solicitud['Solicitud_GaranteCedula'], 'Garante_Telefono' => $solicitud['Solicitud_GaranteTelefono']);
            }            $this->datos[$entidadPrestamo['tabla']][] = array(
                'Prestamo_SolicitudId' => $id,
                'Prestamo_TipoPrestamoId' => $tipoPrestamoId,
                'Prestamo_EstadoPrestamoId' => $estado['EstadoPrestamo_ID'],
                'Prestamo_Monto' => (float)$solicitud['Solicitud_Monto'],
                'Prestamo_Tasa' => (float)$tipo['TipoPrestamo_TasaBase'],
                'Prestamo_Plazo' => (int)$solicitud['Solicitud_Plazo'],
                'Prestamo_Saldo' => $this->calcularTotalPrestamo((float)$solicitud['Solicitud_Monto'], (float)$tipo['TipoPrestamo_TasaBase'], (int)$solicitud['Solicitud_Plazo']),
                'Prestamo_ID' => $prestamoId
            );
        }
        $this->datos['Solicitud'][$indiceSolicitud]['Solicitud_Estado'] = $decision;
        $this->guardar();
        return array('solicitudId' => $id, 'estado' => $decision, 'prestamoId' => $prestamoId);
    }

    private function calcularTotalPrestamo($monto, $tasaAnual, $meses)
    {
        $tasaMensual = $tasaAnual / 1200;
        $cuota = $tasaMensual > 0 ? $monto * $tasaMensual / (1 - pow(1 + $tasaMensual, -$meses)) : $monto / $meses;
        return $cuota * $meses;
    }
    public function obtenerSueldoUsuario($usuarioId)
    {
        $usuario = $this->buscarFila('Usuario', 'Usuario_ID', $usuarioId);
        return $usuario && isset($usuario['Usuario_Sueldo']) ? (float)$usuario['Usuario_Sueldo'] : 0;
    }

    public function obtenerPrestamoActivo($usuarioId)
    {
        foreach ($this->datos['Prestamo'] as $prestamo) {
            $solicitud = $this->buscarFila('Solicitud', 'Solicitud_ID', $prestamo['Prestamo_SolicitudId']);
            $estado = $this->buscarFila('EstadoPrestamo', 'EstadoPrestamo_ID', $prestamo['Prestamo_EstadoPrestamoId']);
            if (!$solicitud || (string)$solicitud['Solicitud_UsuarioId'] !== (string)$usuarioId || !$estado || (strcasecmp($estado['EstadoPrestamo_Nombre'], 'Activo') !== 0 && strcasecmp($estado['EstadoPrestamo_Nombre'], 'Aprobado') !== 0)) continue;
            $tipo = $this->buscarFila('TipoPrestamo', 'TipoPrestamo_ID', $prestamo['Prestamo_TipoPrestamoId']);
            $prestamo['Prestamo_Monto'] = isset($prestamo['Prestamo_Monto']) ? $prestamo['Prestamo_Monto'] : $solicitud['Solicitud_Monto'];
            $prestamo['Prestamo_Saldo'] = isset($prestamo['Prestamo_Saldo']) ? $prestamo['Prestamo_Saldo'] : $prestamo['Prestamo_Monto'];
            $prestamo['Prestamo_Tasa'] = isset($prestamo['Prestamo_Tasa']) ? $prestamo['Prestamo_Tasa'] : ($tipo ? $tipo['TipoPrestamo_TasaBase'] : 0);
            $prestamo['Prestamo_Plazo'] = isset($prestamo['Prestamo_Plazo']) ? $prestamo['Prestamo_Plazo'] : $solicitud['Solicitud_Plazo'];
            return $prestamo;
        }
        return false;
    }

    public function registrarPagoCliente($usuarioId, $datos)
    {
        $prestamo = $this->obtenerPrestamoActivo($usuarioId);
        if (!$prestamo) throw new InvalidArgumentException('No tiene un préstamo activo.');
        $monto = isset($datos['monto']) && is_numeric($datos['monto']) ? (float)$datos['monto'] : 0;
        if ($monto <= 0 || $monto > (float)$prestamo['Prestamo_Saldo']) throw new InvalidArgumentException('El monto debe ser mayor que cero y no superar el saldo pendiente.');
        $metodoId = isset($datos['metodoPagoId']) ? $datos['metodoPagoId'] : null;
        if (!$this->buscarFila('MetodoPago', 'MetodoPago_ID', $metodoId)) throw new InvalidArgumentException('Seleccione un método de pago válido.');
        $this->crear('pagos', array('Pago_PrestamoId' => $prestamo['Prestamo_ID'], 'Pago_MetodoPagoId' => $metodoId, 'Pago_Fecha' => date('Y-m-d'), 'Pago_Monto' => $monto, 'Pago_UsuarioId' => $usuarioId));
        $indicePrestamo = $this->buscarIndice('Prestamo', 'Prestamo_ID', $prestamo['Prestamo_ID']);
        $nuevoSaldo = (float)$prestamo['Prestamo_Saldo'] - $monto;
        $this->datos['Prestamo'][$indicePrestamo]['Prestamo_Saldo'] = $nuevoSaldo;
        if ($nuevoSaldo <= 0) foreach ($this->datos['EstadoPrestamo'] as $estado) if (strcasecmp($estado['EstadoPrestamo_Nombre'], 'Finalizado') === 0) $this->datos['Prestamo'][$indicePrestamo]['Prestamo_EstadoPrestamoId'] = $estado['EstadoPrestamo_ID'];
        $this->guardar();
        return array('saldo' => $nuevoSaldo);
    }
    private function buscarFila($tabla, $campo, $valor)
    {
        foreach ($this->datos[$tabla] as $registro) {
            if (isset($registro[$campo]) && (string)$registro[$campo] === (string)$valor) {
                return $registro;
            }
        }
        return false;
    }

    private function buscarIndice($tabla, $campo, $valor)
    {
        foreach ($this->datos[$tabla] as $indice => $registro) {
            if (isset($registro[$campo]) && (string)$registro[$campo] === (string)$valor) {
                return $indice;
            }
        }
        return false;
    }
    public function listar($recurso)
    {
        $entidad = $this->buscarEntidad($recurso);
        return $this->datos[$entidad['tabla']];
    }

    public function listarSolicitudesPorUsuario($usuarioId)
    {
        $resultado = array();
        foreach ($this->datos['Solicitud'] as $solicitud) {
            if ((string)$solicitud['Solicitud_UsuarioId'] === (string)$usuarioId) {
                $resultado[] = $solicitud;
            }
        }
        return $resultado;
    }

    public function obtener($recurso, $id)
    {
        $entidad = $this->buscarEntidad($recurso);
        foreach ($this->datos[$entidad['tabla']] as $registro) {
            if ((string)$registro[$entidad['id']] === (string)$id) {
                return $registro;
            }
        }
        return false;
    }

    public function crear($recurso, $datos)
    {
        $entidad = $this->buscarEntidad($recurso);
        $registro = $this->filtrarCampos($entidad, $datos);
        if (count($registro) === 0) {
            throw new InvalidArgumentException('No se recibieron campos permitidos para crear el registro.');
        }
        $registro[$entidad['id']] = $this->siguienteId($entidad['tabla']);
        $this->datos[$entidad['tabla']][] = $registro;
        $this->guardar();
        return $registro[$entidad['id']];
    }

    public function actualizar($recurso, $id, $datos)
    {
        $entidad = $this->buscarEntidad($recurso);
        $cambios = $this->filtrarCampos($entidad, $datos);
        if (count($cambios) === 0) {
            throw new InvalidArgumentException('No se recibieron campos permitidos para actualizar.');
        }
        foreach ($this->datos[$entidad['tabla']] as $indice => $registro) {
            if ((string)$registro[$entidad['id']] === (string)$id) {
                foreach ($cambios as $campo => $valor) {
                    $this->datos[$entidad['tabla']][$indice][$campo] = $valor;
                }
                $this->guardar();
                return true;
            }
        }
        return false;
    }

    public function eliminar($recurso, $id)
    {
        $entidad = $this->buscarEntidad($recurso);
        foreach ($this->datos[$entidad['tabla']] as $indice => $registro) {
            if ((string)$registro[$entidad['id']] === (string)$id) {
                array_splice($this->datos[$entidad['tabla']], $indice, 1);
                $this->guardar();
                return true;
            }
        }
        return false;
    }

    private function inicializarDatos()
    {
        $this->datos = array('secuencias' => array());
        foreach ($this->entidades as $entidad) {
            $this->datos[$entidad['tabla']] = array();
            $this->datos['secuencias'][$entidad['tabla']] = 1;
        }
        foreach (array('Pais', 'Provincia', 'Ciudad', 'Direccion', 'Acceso', 'Usuario', 'Telefono', 'Correo') as $tabla) {
            $this->datos[$tabla] = array();
            $this->datos['secuencias'][$tabla] = 1;
        }

        $this->datos['Pais'][] = array('Pais_ID' => 1, 'Pais_Nombre' => 'República Dominicana');
        $this->datos['Provincia'][] = array('Provincia_ID' => 1, 'Provincia_PaisId' => 1, 'Provincia_Nombre' => 'Distrito Nacional');
        $this->datos['Ciudad'][] = array('Ciudad_ID' => 1, 'Ciudad_ProvinciaId' => 1, 'Ciudad_Nombre' => 'Santo Domingo');
        $this->datos['Direccion'][] = array('Direccion_ID' => 1, 'Direccion_CiudadId' => 1, 'Direccion_Descripcion' => 'Oficina de demostración');
        $this->datos['Acceso'][] = array('Acceso_ID' => 1, 'Acceso_RolId' => 1, 'Acceso_Correo' => 'admin@newtalentloans.local', 'Acceso_ContrasenaHash' => password_hash('Demo1234!', PASSWORD_DEFAULT), 'Acceso_Activo' => 1);
        $this->datos['Usuario'][] = array('Usuario_ID' => 1, 'Usuario_DireccionId' => 1, 'Usuario_AccesoId' => 1, 'Usuario_Nombre' => 'Administrador', 'Usuario_Apellido' => 'Demo', 'Usuario_Cedula' => 'DEMO-ADMIN');
        $this->datos['Telefono'][] = array('Telefono_ID' => 1, 'Telefono_UsuarioId' => 1, 'Telefono_Numero' => '0000000000');
        $this->datos['Correo'][] = array('Correo_ID' => 1, 'Correo_UsuarioId' => 1, 'Correo_Direccion' => 'admin@newtalentloans.local');
        $this->datos['secuencias']['Pais'] = 2;
        $this->datos['secuencias']['Provincia'] = 2;
        $this->datos['secuencias']['Ciudad'] = 2;
        $this->datos['secuencias']['Direccion'] = 2;
        $this->datos['secuencias']['Acceso'] = 2;
        $this->datos['secuencias']['Usuario'] = 2;
        $this->datos['secuencias']['Telefono'] = 2;
        $this->datos['secuencias']['Correo'] = 2;

        $this->datos['TipoPrestamo'] = array(
            array('TipoPrestamo_ID' => 1, 'TipoPrestamo_Nombre' => 'Personal', 'TipoPrestamo_TasaBase' => 12),
            array('TipoPrestamo_ID' => 2, 'TipoPrestamo_Nombre' => 'Comercial', 'TipoPrestamo_TasaBase' => 15)
        );
        $this->datos['EstadoPrestamo'] = array(
            array('EstadoPrestamo_ID' => 1, 'EstadoPrestamo_Nombre' => 'Pendiente'),
            array('EstadoPrestamo_ID' => 2, 'EstadoPrestamo_Nombre' => 'Aprobado'),
            array('EstadoPrestamo_ID' => 3, 'EstadoPrestamo_Nombre' => 'Rechazado'),
            array('EstadoPrestamo_ID' => 4, 'EstadoPrestamo_Nombre' => 'Activo'),
            array('EstadoPrestamo_ID' => 5, 'EstadoPrestamo_Nombre' => 'Finalizado')
        );
        $this->datos['MetodoPago'] = array(
            array('MetodoPago_ID' => 1, 'MetodoPago_Nombre' => 'Efectivo', 'MetodoPago_Descripcion' => 'Pago en efectivo'),
            array('MetodoPago_ID' => 2, 'MetodoPago_Nombre' => 'Transferencia', 'MetodoPago_Descripcion' => 'Transferencia bancaria')
        );
        $this->datos['secuencias']['TipoPrestamo'] = 3;
        $this->datos['secuencias']['EstadoPrestamo'] = 6;
        $this->datos['secuencias']['MetodoPago'] = 3;
    }

    private function obtenerOCrearCatalogo($tabla, $idCampo, $nombreCampo, $nombre, $relacionCampo = null, $relacionId = null)
    {
        foreach ($this->datos[$tabla] as $registro) {
            $coincideNombre = strtolower($registro[$nombreCampo]) === strtolower($nombre);
            $coincideRelacion = $relacionCampo === null || (string)$registro[$relacionCampo] === (string)$relacionId;
            if ($coincideNombre && $coincideRelacion) {
                return $registro[$idCampo];
            }
        }
        $valores = array($nombreCampo => $nombre);
        if ($relacionCampo !== null) {
            $valores[$relacionCampo] = $relacionId;
        }
        return $this->crearEnTabla($tabla, $idCampo, $valores);
    }

    private function crearEnTabla($tabla, $idCampo, $valores)
    {
        $id = $this->siguienteId($tabla);
        $valores[$idCampo] = $id;
        $this->datos[$tabla][] = $valores;
        return $id;
    }

    private function siguienteId($tabla)
    {
        if (!isset($this->datos['secuencias'][$tabla])) {
            $this->datos['secuencias'][$tabla] = 1;
        }
        $id = $this->datos['secuencias'][$tabla];
        $this->datos['secuencias'][$tabla]++;
        return $id;
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

    private function guardar()
    {
        $json = json_encode($this->datos, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
        if ($json === false || file_put_contents($this->archivo, $json, LOCK_EX) === false) {
            throw new RuntimeException('No se pudieron guardar los datos de demostración.');
        }
    }
}
