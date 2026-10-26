<?php
class PrestamoClienteService
{
    private $conexion;
    public function __construct($conexion) { $this->conexion = $conexion; }
    public function obtenerActivo($usuarioId)
    {
        $sql = "SELECT TOP 1 P.[Prestamo_ID], P.[Prestamo_Monto], P.[Prestamo_Tasa], P.[Prestamo_Plazo], P.[Prestamo_Saldo], S.[Solicitud_MetodoPagoId] FROM [Prestamo] P INNER JOIN [Solicitud] S ON P.[Prestamo_SolicitudId] = S.[Solicitud_ID] INNER JOIN [EstadoPrestamo] E ON P.[Prestamo_EstadoPrestamoId] = E.[EstadoPrestamo_ID] WHERE S.[Solicitud_UsuarioId] = ? AND E.[EstadoPrestamo_Nombre] IN ('Activo', 'Aprobado') ORDER BY P.[Prestamo_ID] DESC";
        $consulta = $this->conexion->prepare($sql); $consulta->execute(array($usuarioId));
        $prestamo = $consulta->fetch(); return $prestamo ? $prestamo : false;
    }
    public function registrarPago($usuarioId, $datos)
    {
        $monto = isset($datos['monto']) && is_numeric($datos['monto']) ? (float)$datos['monto'] : 0;
        $metodoId = isset($datos['metodoPagoId']) ? $datos['metodoPagoId'] : null;
        $this->conexion->beginTransaction();
        try {
            $consulta = $this->conexion->prepare("SELECT TOP 1 P.[Prestamo_ID], P.[Prestamo_Saldo] FROM [Prestamo] P INNER JOIN [Solicitud] S ON P.[Prestamo_SolicitudId] = S.[Solicitud_ID] INNER JOIN [EstadoPrestamo] E ON P.[Prestamo_EstadoPrestamoId] = E.[EstadoPrestamo_ID] WHERE S.[Solicitud_UsuarioId] = ? AND E.[EstadoPrestamo_Nombre] IN ('Activo', 'Aprobado') ORDER BY P.[Prestamo_ID] DESC");
            $consulta->execute(array($usuarioId)); $prestamo = $consulta->fetch();
            if (!$prestamo) throw new InvalidArgumentException('No tiene un préstamo activo.');
            if ($monto <= 0 || $monto > (float)$prestamo['Prestamo_Saldo']) throw new InvalidArgumentException('El monto debe ser mayor que cero y no superar el saldo pendiente.');
            $metodo = $this->conexion->prepare('SELECT [MetodoPago_ID] FROM [MetodoPago] WHERE [MetodoPago_ID] = ?'); $metodo->execute(array($metodoId));
            if ($metodo->fetchColumn() === false) throw new InvalidArgumentException('Seleccione un método de pago válido.');
            $pago = $this->conexion->prepare('INSERT INTO [Pago] ([Pago_PrestamoId], [Pago_MetodoPagoId], [Pago_Fecha], [Pago_Monto], [Pago_UsuarioId]) VALUES (?, ?, GETDATE(), ?, ?)');
            $pago->execute(array($prestamo['Prestamo_ID'], $metodoId, $monto, $usuarioId));
            $saldo = max(0, (float)$prestamo['Prestamo_Saldo'] - $monto);
            $actualizar = $this->conexion->prepare('UPDATE [Prestamo] SET [Prestamo_Saldo] = ? WHERE [Prestamo_ID] = ?'); $actualizar->execute(array($saldo, $prestamo['Prestamo_ID']));
            if ($saldo <= 0) {
                $estado = $this->conexion->query("SELECT TOP 1 [EstadoPrestamo_ID] FROM [EstadoPrestamo] WHERE [EstadoPrestamo_Nombre] = 'Finalizado'")->fetchColumn();
                if ($estado !== false) { $cambio = $this->conexion->prepare('UPDATE [Prestamo] SET [Prestamo_EstadoPrestamoId] = ? WHERE [Prestamo_ID] = ?'); $cambio->execute(array($estado, $prestamo['Prestamo_ID'])); }
            }
            $this->conexion->commit(); return array('saldo' => $saldo);
        } catch (Throwable $error) { if ($this->conexion->inTransaction()) $this->conexion->rollBack(); throw $error; }
    }
}
