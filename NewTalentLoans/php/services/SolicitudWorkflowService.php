<?php
class SolicitudWorkflowService
{
    private $conexion;

    public function __construct($conexion)
    {
        $this->conexion = $conexion;
    }

    public function resolver($solicitudId, $decision, $tipoPrestamoId)
    {
        $decision = ucfirst(strtolower(trim($decision)));
        if ($decision !== 'Aprobada' && $decision !== 'Rechazada') {
            throw new InvalidArgumentException('La decisión debe ser Aprobada o Rechazada.');
        }

        $this->conexion->beginTransaction();
        try {
            $consulta = $this->conexion->prepare('SELECT S.[Solicitud_ID], S.[Solicitud_Estado], S.[Solicitud_UsuarioId], S.[Solicitud_Monto], S.[Solicitud_Plazo], S.[Solicitud_TipoPrestamoId], S.[Solicitud_MetodoPagoId], S.[Solicitud_GaranteNombre], S.[Solicitud_GaranteCedula], S.[Solicitud_GaranteTelefono], U.[Usuario_Sueldo] FROM [Solicitud] S INNER JOIN [Usuario] U ON S.[Solicitud_UsuarioId] = U.[Usuario_ID] WHERE S.[Solicitud_ID] = ?');
            $consulta->execute(array($solicitudId));
            $solicitud = $consulta->fetch();
            if (!$solicitud) {
                $this->conexion->rollBack();
                return false;
            }
            if (strcasecmp((string)$solicitud['Solicitud_Estado'], 'Pendiente') !== 0) {
                throw new InvalidArgumentException('Solo se pueden resolver solicitudes pendientes.');
            }

            $prestamoId = null;
            if ($decision === 'Aprobada') {
                if ((float)$solicitud['Solicitud_Monto'] > (float)$solicitud['Usuario_Sueldo'] && (trim((string)$solicitud['Solicitud_GaranteNombre']) === '' || trim((string)$solicitud['Solicitud_GaranteCedula']) === '' || trim((string)$solicitud['Solicitud_GaranteTelefono']) === '')) {
                    throw new InvalidArgumentException('La solicitud supera el sueldo mensual del cliente y requiere los datos de un garante.');
                }
                $tipoPrestamoId = $tipoPrestamoId ?: $solicitud['Solicitud_TipoPrestamoId'];
                if ($tipoPrestamoId === null || $tipoPrestamoId === '') {
                    throw new InvalidArgumentException('Seleccione el tipo de préstamo para aprobar la solicitud.');
                }
                $consultaTipo = $this->conexion->prepare('SELECT [TipoPrestamo_TasaBase] FROM [TipoPrestamo] WHERE [TipoPrestamo_ID] = ?');
                $consultaTipo->execute(array($tipoPrestamoId));
                $tasa = $consultaTipo->fetchColumn();
                if ($tasa === false) {
                    throw new InvalidArgumentException('El tipo de préstamo seleccionado no existe.');
                }
                $consultaEstado = $this->conexion->prepare("SELECT TOP 1 [EstadoPrestamo_ID] FROM [EstadoPrestamo] WHERE [EstadoPrestamo_Nombre] IN ('Activo', 'Aprobado') ORDER BY CASE WHEN [EstadoPrestamo_Nombre] = 'Activo' THEN 0 ELSE 1 END");
                $consultaEstado->execute();
                $estadoPrestamoId = $consultaEstado->fetchColumn();
                if ($estadoPrestamoId === false) {
                    throw new RuntimeException('Agregue a EstadoPrestamo un estado llamado Activo o Aprobado.');
                }
                $consultaExistente = $this->conexion->prepare('SELECT [Prestamo_ID] FROM [Prestamo] WHERE [Prestamo_SolicitudId] = ?');
                $consultaExistente->execute(array($solicitudId));
                if ($consultaExistente->fetchColumn() !== false) {
                    throw new InvalidArgumentException('Esta solicitud ya tiene un préstamo asociado.');
                }
                $montoAprobado = (float)$solicitud['Solicitud_Monto'];
                $plazoAprobado = (int)$solicitud['Solicitud_Plazo'];
                $tasaMensual = (float)$tasa / 1200;
                $saldoInicial = $tasaMensual > 0 ? ($montoAprobado * $tasaMensual / (1 - pow(1 + $tasaMensual, -$plazoAprobado))) * $plazoAprobado : $montoAprobado;
                $insertarPrestamo = $this->conexion->prepare('INSERT INTO [Prestamo] ([Prestamo_SolicitudId], [Prestamo_TipoPrestamoId], [Prestamo_EstadoPrestamoId], [Prestamo_Monto], [Prestamo_Tasa], [Prestamo_Plazo], [Prestamo_FechaDesembolso], [Prestamo_Saldo]) OUTPUT INSERTED.[Prestamo_ID] VALUES (?, ?, ?, ?, ?, ?, GETDATE(), ?)');
                $insertarPrestamo->execute(array($solicitudId, $tipoPrestamoId, $estadoPrestamoId, $montoAprobado, $tasa, $plazoAprobado, $saldoInicial));
                $prestamoId = $insertarPrestamo->fetchColumn();
                if (trim((string)$solicitud['Solicitud_GaranteNombre']) !== '') {
                    $insertarGarante = $this->conexion->prepare('INSERT INTO [Garante] ([Garante_PrestamoId], [Garante_Nombre], [Garante_Cedula], [Garante_Telefono]) VALUES (?, ?, ?, ?)');
                    $insertarGarante->execute(array($prestamoId, $solicitud['Solicitud_GaranteNombre'], $solicitud['Solicitud_GaranteCedula'], $solicitud['Solicitud_GaranteTelefono']));
                }
            }

            $actualizarSolicitud = $this->conexion->prepare('UPDATE [Solicitud] SET [Solicitud_Estado] = ? WHERE [Solicitud_ID] = ?');
            $actualizarSolicitud->execute(array($decision, $solicitudId));
            $this->conexion->commit();
            return array('solicitudId' => $solicitudId, 'estado' => $decision, 'prestamoId' => $prestamoId);
        } catch (Throwable $error) {
            if ($this->conexion->inTransaction()) {
                $this->conexion->rollBack();
            }
            throw $error;
        }
    }
}
