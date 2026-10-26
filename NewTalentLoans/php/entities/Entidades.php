<?php
/*
 * Catálogo de tablas y columnas del modelo. Los nombres siguen la convención:
 * tabla en CamelCase y columna como NombreTabla_NombreCampo.
 * Ajuste este catálogo si el diagrama SQL final usa otros nombres.
 */
function obtenerEntidades()
{
    return array(
        'solicitudes' => array('tabla' => 'Solicitud', 'id' => 'Solicitud_ID', 'campos' => array('Solicitud_UsuarioId', 'Solicitud_Fecha', 'Solicitud_Monto', 'Solicitud_Plazo', 'Solicitud_Motivo', 'Solicitud_Estado', 'Solicitud_TipoPrestamoId', 'Solicitud_MetodoPagoId', 'Solicitud_GaranteNombre', 'Solicitud_GaranteCedula', 'Solicitud_GaranteTelefono')),
        'prestamos' => array('tabla' => 'Prestamo', 'id' => 'Prestamo_ID', 'campos' => array('Prestamo_SolicitudId', 'Prestamo_TipoPrestamoId', 'Prestamo_EstadoPrestamoId', 'Prestamo_Monto', 'Prestamo_Tasa', 'Prestamo_Plazo', 'Prestamo_FechaDesembolso', 'Prestamo_Saldo')),
        'cuotas' => array('tabla' => 'Cuota', 'id' => 'Cuota_ID', 'campos' => array('Cuota_PrestamoId', 'Cuota_FechaVencimiento', 'Cuota_Capital', 'Cuota_Interes', 'Cuota_Monto', 'Cuota_Saldo', 'Cuota_Estado')),
        'pagos' => array('tabla' => 'Pago', 'id' => 'Pago_ID', 'campos' => array('Pago_PrestamoId', 'Pago_MetodoPagoId', 'Pago_Fecha', 'Pago_Monto', 'Pago_UsuarioId')),
        'tipos-prestamo' => array('tabla' => 'TipoPrestamo', 'id' => 'TipoPrestamo_ID', 'campos' => array('TipoPrestamo_Nombre', 'TipoPrestamo_TasaBase')),
        'estados-prestamo' => array('tabla' => 'EstadoPrestamo', 'id' => 'EstadoPrestamo_ID', 'campos' => array('EstadoPrestamo_Nombre')),
        'metodos-pago' => array('tabla' => 'MetodoPago', 'id' => 'MetodoPago_ID', 'campos' => array('MetodoPago_Nombre', 'MetodoPago_Descripcion')),
        'garantes' => array('tabla' => 'Garante', 'id' => 'Garante_ID', 'campos' => array('Garante_PrestamoId', 'Garante_Nombre', 'Garante_Cedula', 'Garante_Telefono')),
        'facturacion' => array('tabla' => 'Facturacion', 'id' => 'Facturacion_ID', 'campos' => array('Facturacion_MetodoPagoId', 'Facturacion_Fecha', 'Facturacion_Monto', 'Facturacion_Descripcion', 'Facturacion_Estado'))
    );
}
