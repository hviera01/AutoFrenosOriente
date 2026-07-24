class ItemVentaModel {
  final String idProducto;
  final String idCategoria;
  final String nombreProducto;
  final double precioVenta;
  final double cantidad;
  final double subtotal;
  final double precioCompraUsado;
  final bool reembasado;
  final double descuentoPorcentaje;
  // Servicio de barbería (ej. corte): exige barbero, no descuenta stock.
  final bool esServicio;
  final String idBarbero;
  final String nombreBarbero;
  // % de comisión del barbero capturado al momento de asignarlo a la línea
  // (no se recalcula después aunque el barbero cambie su % más adelante).
  // El monto de comisión se calcula sobre el subtotal en el momento que se
  // necesita (reportes), no se guarda aparte para no desincronizarse si el
  // cajero edita precio/cantidad después de asignar el barbero.
  final double pctComisionBarbero;
  // Solo aplica a líneas de producto físico: quién lo vendió además del
  // cajero que registra la venta, para efectos de comisión ('N/A',
  // 'Usuario' o 'Barbero').
  final String vendidoPorTipo;
  final String vendidoPorId;
  final String vendidoPorNombre;

  ItemVentaModel({
    required this.idProducto,
    required this.idCategoria,
    required this.nombreProducto,
    required this.precioVenta,
    required this.cantidad,
    required this.subtotal,
    required this.precioCompraUsado,
    this.reembasado = false,
    this.descuentoPorcentaje = 0,
    this.esServicio = false,
    this.idBarbero = '',
    this.nombreBarbero = '',
    this.pctComisionBarbero = 0,
    this.vendidoPorTipo = 'N/A',
    this.vendidoPorId = '',
    this.vendidoPorNombre = '',
  });

  factory ItemVentaModel.fromMap(Map<String, dynamic> data) {
    return ItemVentaModel(
      idProducto: data['idProducto'] ?? '',
      idCategoria: data['idCategoria'] ?? '',
      nombreProducto: data['nombreProducto'] ?? '',
      precioVenta: (data['precioVenta'] ?? 0).toDouble(),
      cantidad: (data['cantidad'] ?? 0).toDouble(),
      subtotal: (data['subtotal'] ?? 0).toDouble(),
      precioCompraUsado: (data['precioCompraUsado'] ?? 0).toDouble(),
      reembasado: data['reembasado'] ?? false,
      descuentoPorcentaje: (data['descuentoPorcentaje'] ?? 0).toDouble(),
      esServicio: data['esServicio'] ?? false,
      idBarbero: data['idBarbero'] ?? '',
      nombreBarbero: data['nombreBarbero'] ?? '',
      pctComisionBarbero: (data['pctComisionBarbero'] ?? 0).toDouble(),
      vendidoPorTipo: data['vendidoPorTipo'] ?? 'N/A',
      vendidoPorId: data['vendidoPorId'] ?? '',
      vendidoPorNombre: data['vendidoPorNombre'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'idProducto': idProducto,
      'idCategoria': idCategoria,
      'nombreProducto': nombreProducto,
      'precioVenta': precioVenta,
      'cantidad': cantidad,
      'subtotal': subtotal,
      'precioCompraUsado': precioCompraUsado,
      'reembasado': reembasado,
      'descuentoPorcentaje': descuentoPorcentaje,
      'esServicio': esServicio,
      'idBarbero': idBarbero,
      'nombreBarbero': nombreBarbero,
      'pctComisionBarbero': pctComisionBarbero,
      'vendidoPorTipo': vendidoPorTipo,
      'vendidoPorId': vendidoPorId,
      'vendidoPorNombre': vendidoPorNombre,
    };
  }

  ItemVentaModel copyWith({
    String? nombreProducto,
    double? precioVenta,
    double? cantidad,
    double? subtotal,
    double? descuentoPorcentaje,
    double? precioCompraUsado,
    bool? reembasado,
    String? idBarbero,
    String? nombreBarbero,
    double? pctComisionBarbero,
    String? vendidoPorTipo,
    String? vendidoPorId,
    String? vendidoPorNombre,
  }) {
    return ItemVentaModel(
      idProducto: idProducto,
      idCategoria: idCategoria,
      nombreProducto: nombreProducto ?? this.nombreProducto,
      precioVenta: precioVenta ?? this.precioVenta,
      cantidad: cantidad ?? this.cantidad,
      subtotal: subtotal ?? this.subtotal,
      precioCompraUsado: precioCompraUsado ?? this.precioCompraUsado,
      reembasado: reembasado ?? this.reembasado,
      descuentoPorcentaje: descuentoPorcentaje ?? this.descuentoPorcentaje,
      esServicio: esServicio,
      idBarbero: idBarbero ?? this.idBarbero,
      nombreBarbero: nombreBarbero ?? this.nombreBarbero,
      pctComisionBarbero: pctComisionBarbero ?? this.pctComisionBarbero,
      vendidoPorTipo: vendidoPorTipo ?? this.vendidoPorTipo,
      vendidoPorId: vendidoPorId ?? this.vendidoPorId,
      vendidoPorNombre: vendidoPorNombre ?? this.vendidoPorNombre,
    );
  }
}
