const tiposDocumento = {
  'VentaSinFacturar': 'Venta',
  'Factura': 'Factura',
  'Cotizacion': 'Cotización',
  'Venta': 'Venta',
};

const tiposDocumentoFiltro = {
  'VentaSinFacturar': 'Venta',
  'Factura': 'Factura',
  'Cotizacion': 'Cotización',
};

bool coincideTipoDocumentoFiltro(String tipoVenta, String? filtro) {
  if (filtro == null || filtro.isEmpty) return true;
  if (filtro == 'VentaSinFacturar') return tipoVenta == 'VentaSinFacturar' || tipoVenta == 'Venta';
  return tipoVenta == filtro;
}

String etiquetaTipoDocumento(String tipo) => tiposDocumento[tipo] ?? tipo;
