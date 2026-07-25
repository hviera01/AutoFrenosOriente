/// Clave interna (guardada en `venta.tipoDocumento` en Firestore) -> etiqueta
/// legible, de los tipos de documento que puede generar una venta. Este
/// negocio no maneja facturación fiscal real (sin CAI, ver NEGOCIO.CAI="0"
/// en los datos migrados): el sistema viejo solo ofrecía "Venta" (un ticket
/// interno) y "Cotización", sin Factura/Boleta — se replica igual acá.
const tiposDocumento = {
  'Venta': 'Venta',
  'Cotizacion': 'Cotización',
};
