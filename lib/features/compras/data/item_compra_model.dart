class ItemCompraModel {
  final String idProducto;
  final String idCategoria;
  final String nombreProducto;
  final double precioCompra;
  final double cantidad;
  final double subtotal;
  final double descuentoPorcentaje;
  // Nuevo precio de venta (con ISV) a aplicar al producto al registrar la
  // compra. Null significa "no cambiar el precio de venta actual".
  final double? precioVentaNuevo;
  // Nueva descripción a aplicar al PRODUCTO (no solo a esta línea) al
  // registrar la compra -para agregarle o corregirle algo (ej. una medida,
  // una nota) sin tener que ir aparte a Inventario. Null significa "no
  // cambiar la descripción actual".
  final String? descripcionNueva;

  ItemCompraModel({
    required this.idProducto,
    required this.idCategoria,
    required this.nombreProducto,
    required this.precioCompra,
    required this.cantidad,
    required this.subtotal,
    this.descuentoPorcentaje = 0,
    this.precioVentaNuevo,
    this.descripcionNueva,
  });

  factory ItemCompraModel.fromMap(Map<String, dynamic> data) {
    return ItemCompraModel(
      idProducto: data['idProducto'] ?? '',
      idCategoria: data['idCategoria'] ?? '',
      nombreProducto: data['nombreProducto'] ?? '',
      precioCompra: (data['precioCompra'] ?? 0).toDouble(),
      cantidad: (data['cantidad'] ?? 0).toDouble(),
      subtotal: (data['subtotal'] ?? 0).toDouble(),
      descuentoPorcentaje: (data['descuentoPorcentaje'] ?? 0).toDouble(),
      precioVentaNuevo: (data['precioVentaNuevo'] as num?)?.toDouble(),
      descripcionNueva: data['descripcionNueva'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'idProducto': idProducto,
      'idCategoria': idCategoria,
      'nombreProducto': nombreProducto,
      'precioCompra': precioCompra,
      'cantidad': cantidad,
      'subtotal': subtotal,
      'descuentoPorcentaje': descuentoPorcentaje,
      'precioVentaNuevo': precioVentaNuevo,
      'descripcionNueva': descripcionNueva,
    };
  }

  ItemCompraModel copyWith({
    double? precioCompra,
    double? cantidad,
    double? subtotal,
    double? descuentoPorcentaje,
    double? precioVentaNuevo,
    String? descripcionNueva,
  }) {
    return ItemCompraModel(
      idProducto: idProducto,
      idCategoria: idCategoria,
      nombreProducto: nombreProducto,
      precioCompra: precioCompra ?? this.precioCompra,
      cantidad: cantidad ?? this.cantidad,
      subtotal: subtotal ?? this.subtotal,
      descuentoPorcentaje: descuentoPorcentaje ?? this.descuentoPorcentaje,
      precioVentaNuevo: precioVentaNuevo ?? this.precioVentaNuevo,
      descripcionNueva: descripcionNueva ?? this.descripcionNueva,
    );
  }
}
