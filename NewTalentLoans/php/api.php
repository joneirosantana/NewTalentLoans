<?php
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
session_start();

require_once __DIR__ . '/config/database.php';
require_once __DIR__ . '/entities/Entidades.php';
require_once __DIR__ . '/entities/Usuario.php';
require_once __DIR__ . '/repositories/CrudRepository.php';
require_once __DIR__ . '/repositories/ModoDemoRepository.php';
require_once __DIR__ . '/services/RegistroService.php';
require_once __DIR__ . '/services/AuthService.php';
require_once __DIR__ . '/services/ClienteService.php';
require_once __DIR__ . '/services/SolicitudWorkflowService.php';
require_once __DIR__ . '/services/PrestamoClienteService.php';

function responder($codigo, $datos)
{
    http_response_code($codigo);
    echo json_encode($datos, JSON_UNESCAPED_UNICODE);
    exit;
}

function leerDatos()
{
    $contenido = file_get_contents('php://input');
    $datos = json_decode($contenido, true);
    if (!is_array($datos)) {
        throw new InvalidArgumentException('El cuerpo debe ser JSON válido.');
    }
    return $datos;
}

$metodo = $_SERVER['REQUEST_METHOD'];
$recurso = isset($_GET['recurso']) ? trim($_GET['recurso']) : '';
$id = isset($_GET['id']) ? trim($_GET['id']) : null;

if ($recurso === 'cerrar-sesion' && $metodo === 'POST') {
    $_SESSION = array();
    session_destroy();
    responder(200, array('success' => true, 'message' => 'Sesión cerrada.'));
}

try {
    $conexion = null;
    $demo = null;
    if (MODO_DEMO_SIN_DB) {
        $demo = new ModoDemoRepository(obtenerEntidades());
    } else {
        $conexion = conectarBaseDatos();
    }

    if ($recurso === 'registro' && $metodo === 'POST') {
        if (MODO_DEMO_SIN_DB) {
            $usuario = $demo->registrar(leerDatos());
        } else {
            $servicio = new RegistroService($conexion, obtenerColumnasUsuario(), obtenerConfiguracionBaseDatos());
            $usuario = $servicio->registrar(leerDatos());
        }
        responder(201, array('success' => true, 'message' => 'La cuenta se creó correctamente.', 'usuario' => $usuario));
    }

    if ($recurso === 'sesion' && $metodo === 'POST') {
        $datos = leerDatos();
        if (MODO_DEMO_SIN_DB) {
            $usuario = $demo->iniciarSesion(isset($datos['correo']) ? $datos['correo'] : '', isset($datos['contrasena']) ? $datos['contrasena'] : '');
        } else {
            $servicio = new AuthService($conexion, obtenerColumnasUsuario());
            $usuario = $servicio->iniciarSesion(isset($datos['correo']) ? $datos['correo'] : '', isset($datos['contrasena']) ? $datos['contrasena'] : '');
        }
        if (!$usuario) {
            responder(401, array('success' => false, 'message' => 'Correo o contraseña incorrectos.'));
        }
        session_regenerate_id(true);
        $_SESSION['usuarioId'] = $usuario['id'];
        $_SESSION['rolId'] = $usuario['rolId'];
        if (MODO_DEMO_SIN_DB) {
            $rolAdmin = $demo->obtenerRolAdministradorId();
        } else {
            $rolAdmin = obtenerConfiguracionBaseDatos()['rolAdministradorId'];
        }
        $usuario['esAdministrador'] = $rolAdmin !== '' && (string)$usuario['rolId'] === (string)$rolAdmin;
        responder(200, array('success' => true, 'usuario' => $usuario));
    }

    if (!isset($_SESSION['usuarioId'])) {
        responder(401, array('success' => false, 'message' => 'Inicie sesión para continuar.'));
    }

    if (MODO_DEMO_SIN_DB) {
        $repositorio = $demo;
        $rolAdministradorId = $demo->obtenerRolAdministradorId();
    } else {
        $repositorio = new CrudRepository($conexion, obtenerEntidades());
        $rolAdministradorId = obtenerConfiguracionBaseDatos()['rolAdministradorId'];
    }
    $esAdministrador = $rolAdministradorId !== '' && isset($_SESSION['rolId']) && (string)$_SESSION['rolId'] === (string)$rolAdministradorId;

    if (!$esAdministrador && $metodo === 'GET' && ($recurso === 'tipos-prestamo' || $recurso === 'metodos-pago')) {
        responder(200, array('success' => true, 'datos' => $repositorio->listar($recurso)));
    }
    if ($recurso === 'mi-perfil' && $metodo === 'GET') {
        $sueldo = MODO_DEMO_SIN_DB ? $demo->obtenerSueldoUsuario($_SESSION['usuarioId']) : (float)$conexion->query('SELECT [Usuario_Sueldo] FROM [Usuario] WHERE [Usuario_ID] = ' . (int)$_SESSION['usuarioId'])->fetchColumn();
        responder(200, array('success' => true, 'sueldo' => $sueldo));
    }
    if ($recurso === 'mi-prestamo' && $metodo === 'GET') {
        $prestamoActivo = MODO_DEMO_SIN_DB ? $demo->obtenerPrestamoActivo($_SESSION['usuarioId']) : (new PrestamoClienteService($conexion))->obtenerActivo($_SESSION['usuarioId']);
        responder(200, array('success' => true, 'dato' => $prestamoActivo));
    }
    if ($recurso === 'pago-cliente' && $metodo === 'POST') {
        if ($esAdministrador) responder(403, array('success' => false, 'message' => 'Esta operación es para clientes.'));
        $datosPago = leerDatos();
        $resultadoPago = MODO_DEMO_SIN_DB ? $demo->registrarPagoCliente($_SESSION['usuarioId'], $datosPago) : (new PrestamoClienteService($conexion))->registrarPago($_SESSION['usuarioId'], $datosPago);
        responder(201, array('success' => true, 'message' => 'El pago fue registrado y aplicado al saldo.', 'resultado' => $resultadoPago));
    }    if ($recurso === 'resolver-solicitud' && $metodo === 'POST') {
        if (!$esAdministrador) responder(403, array('success' => false, 'message' => 'Solo un administrador puede resolver solicitudes.'));
        if ($id === null) responder(400, array('success' => false, 'message' => 'Falta el ID de la solicitud.'));
        $datosDecision = leerDatos();
        if (MODO_DEMO_SIN_DB) {
            $resultadoDecision = $demo->resolverSolicitud($id, isset($datosDecision['decision']) ? $datosDecision['decision'] : '', isset($datosDecision['tipoPrestamoId']) ? $datosDecision['tipoPrestamoId'] : null);
        } else {
            $servicioDecision = new SolicitudWorkflowService($conexion);
            $resultadoDecision = $servicioDecision->resolver($id, isset($datosDecision['decision']) ? $datosDecision['decision'] : '', isset($datosDecision['tipoPrestamoId']) ? $datosDecision['tipoPrestamoId'] : null);
        }
        if (!$resultadoDecision) responder(404, array('success' => false, 'message' => 'No se encontró la solicitud.'));
        $mensajeDecision = $resultadoDecision['estado'] === 'Aprobada' ? 'Solicitud aprobada y préstamo creado.' : 'Solicitud rechazada.';
        responder(200, array('success' => true, 'message' => $mensajeDecision, 'resultado' => $resultadoDecision));
    }

    if ($recurso === 'clientes') {
        if (!$esAdministrador) responder(403, array('success' => false, 'message' => 'Solo un administrador puede gestionar clientes.'));
        if ($metodo === 'GET') {
            if (MODO_DEMO_SIN_DB) {
                if ($id !== null) {
                    $cliente = $demo->obtenerCliente($id);
                    if (!$cliente) responder(404, array('success' => false, 'message' => 'No se encontró el cliente.'));
                    responder(200, array('success' => true, 'cliente' => $cliente));
                }
                $clientes = $demo->listarClientes();
            } else {
                $servicioClientes = new ClienteService($conexion, obtenerColumnasUsuario(), obtenerConfiguracionBaseDatos()['rolClienteId']);
                if ($id !== null) {
                    $cliente = $servicioClientes->obtener($id);
                    if (!$cliente) responder(404, array('success' => false, 'message' => 'No se encontró el cliente.'));
                    responder(200, array('success' => true, 'cliente' => $cliente));
                }
                $clientes = $servicioClientes->listar();
            }
            responder(200, array('success' => true, 'datos' => $clientes));
        }
        if ($metodo === 'POST') {
            if (MODO_DEMO_SIN_DB) {
                $clienteCreado = $demo->registrar(leerDatos());
            } else {
                $servicioRegistroCliente = new RegistroService($conexion, obtenerColumnasUsuario(), obtenerConfiguracionBaseDatos());
                $clienteCreado = $servicioRegistroCliente->registrar(leerDatos());
            }
            responder(201, array('success' => true, 'message' => 'Cliente creado y cuenta habilitada.', 'cliente' => $clienteCreado));
        }
        if ($id === null) responder(400, array('success' => false, 'message' => 'Falta el ID del cliente.'));
        if ($metodo === 'PUT') {
            $datosCliente = leerDatos();
            if (MODO_DEMO_SIN_DB) {
                $actualizado = $demo->actualizarCliente($id, $datosCliente);
            } else {
                $servicioClientes = new ClienteService($conexion, obtenerColumnasUsuario(), obtenerConfiguracionBaseDatos()['rolClienteId']);
                $actualizado = $servicioClientes->actualizar($id, $datosCliente);
            }
            if (!$actualizado) responder(404, array('success' => false, 'message' => 'No se encontró el cliente.'));
            responder(200, array('success' => true, 'message' => 'Datos del cliente actualizados.'));
        }
        if ($metodo === 'DELETE') {
            if (MODO_DEMO_SIN_DB) {
                $desactivado = $demo->desactivarCliente($id);
            } else {
                $servicioClientes = new ClienteService($conexion, obtenerColumnasUsuario(), obtenerConfiguracionBaseDatos()['rolClienteId']);
                $desactivado = $servicioClientes->desactivar($id);
            }
            if (!$desactivado) responder(404, array('success' => false, 'message' => 'No se encontró el cliente o ya estaba desactivado.'));
            responder(200, array('success' => true, 'message' => 'El cliente fue desactivado.'));
        }
    }
    if ($recurso === 'solicitudes') {
        if ($metodo === 'GET') {
            if ($id === null) {
                $solicitudes = $esAdministrador ? $repositorio->listar($recurso) : $repositorio->listarSolicitudesPorUsuario($_SESSION['usuarioId']);
                responder(200, array('success' => true, 'datos' => $solicitudes));
            }
            $solicitud = $repositorio->obtener($recurso, $id);
            if (!$solicitud || (!$esAdministrador && (string)$solicitud['Solicitud_UsuarioId'] !== (string)$_SESSION['usuarioId'])) {
                responder(404, array('success' => false, 'message' => 'No se encontró la solicitud.'));
            }
            responder(200, array('success' => true, 'dato' => $solicitud));
        }
        if ($metodo === 'POST') {
            if ($esAdministrador) {
                responder(403, array('success' => false, 'message' => 'Los administradores no crean solicitudes de cliente desde este formulario.'));
            }
            $datos = leerDatos();
            $montoSolicitud = isset($datos['Solicitud_Monto']) ? (float)$datos['Solicitud_Monto'] : 0;
            $sueldoCliente = MODO_DEMO_SIN_DB ? $demo->obtenerSueldoUsuario($_SESSION['usuarioId']) : (float)$conexion->query('SELECT [Usuario_Sueldo] FROM [Usuario] WHERE [Usuario_ID] = ' . (int)$_SESSION['usuarioId'])->fetchColumn();
            if ($montoSolicitud <= 0 || empty($datos['Solicitud_TipoPrestamoId']) || empty($datos['Solicitud_MetodoPagoId'])) responder(400, array('success' => false, 'message' => 'Indique un monto, tipo de préstamo y método de pago.'));
            if ($montoSolicitud > $sueldoCliente && (empty($datos['Solicitud_GaranteNombre']) || empty($datos['Solicitud_GaranteCedula']) || empty($datos['Solicitud_GaranteTelefono']))) responder(400, array('success' => false, 'message' => 'El monto supera su sueldo mensual; complete los datos del garante.'));
            $datos['Solicitud_UsuarioId'] = $_SESSION['usuarioId'];
            $nuevoId = $repositorio->crear($recurso, $datos);
            responder(201, array('success' => true, 'id' => $nuevoId, 'message' => 'Solicitud creada.'));
        }
    }

    if (!$esAdministrador) {
        responder(403, array('success' => false, 'message' => 'Esta operación requiere el rol administrativo.'));
    }
    if ($metodo === 'GET') {
        if ($id === null) {
            responder(200, array('success' => true, 'datos' => $repositorio->listar($recurso)));
        }
        $registro = $repositorio->obtener($recurso, $id);
        if (!$registro) {
            responder(404, array('success' => false, 'message' => 'No se encontró el registro.'));
        }
        responder(200, array('success' => true, 'dato' => $registro));
    }
    if ($metodo === 'POST') {
        $nuevoId = $repositorio->crear($recurso, leerDatos());
        responder(201, array('success' => true, 'id' => $nuevoId, 'message' => 'Registro creado.'));
    }
    if ($metodo === 'PUT') {
        if ($id === null) {
            responder(400, array('success' => false, 'message' => 'Falta el parámetro id.'));
        }
        if (!$repositorio->actualizar($recurso, $id, leerDatos())) {
            responder(404, array('success' => false, 'message' => 'No se encontró el registro o no hubo cambios.'));
        }
        responder(200, array('success' => true, 'message' => 'Registro actualizado.'));
    }
    if ($metodo === 'DELETE') {
        if ($id === null) {
            responder(400, array('success' => false, 'message' => 'Falta el parámetro id.'));
        }
        if (!$repositorio->eliminar($recurso, $id)) {
            responder(404, array('success' => false, 'message' => 'No se encontró el registro.'));
        }
        responder(200, array('success' => true, 'message' => 'Registro eliminado.'));
    }

    header('Allow: GET, POST, PUT, DELETE');
    responder(405, array('success' => false, 'message' => 'Método HTTP no permitido.'));
} catch (InvalidArgumentException $error) {
    responder(400, array('success' => false, 'message' => $error->getMessage()));
} catch (Throwable $error) {
    error_log('Error de API NewTalentLoans: ' . $error->getMessage());
    $mensaje = $error instanceof RuntimeException ? $error->getMessage() : 'Ocurrió un error al procesar la solicitud. Revise el registro de errores de PHP.';
    responder(500, array('success' => false, 'message' => $mensaje));
}