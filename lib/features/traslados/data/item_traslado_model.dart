class ItemTrasladoModel {
  final String idProducto;
  final String nombreProducto;
  final double cantidad;
  // Ubicación física del producto (estante/bodega, ej. "(1N)") en la
  // sucursal de origen — en el sistema viejo este dato vivía en
  // DETALLE_TRASLADO.Descripcion (mal nombrado: es una ubicación, no una
  // descripción del producto) y se imprime en el ticket como "Ubicación:".
  // Opcional: la mayoría de los traslados no la traen.
  final String ubicacion;

  ItemTrasladoModel({
    required this.idProducto,
    required this.nombreProducto,
    required this.cantidad,
    this.ubicacion = '',
  });

  factory ItemTrasladoModel.fromMap(Map<String, dynamic> data) {
    return ItemTrasladoModel(
      idProducto: data['idProducto'] ?? '',
      nombreProducto: data['nombreProducto'] ?? '',
      cantidad: (data['cantidad'] ?? 0).toDouble(),
      ubicacion: data['ubicacion'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'idProducto': idProducto,
      'nombreProducto': nombreProducto,
      'cantidad': cantidad,
      'ubicacion': ubicacion,
    };
  }
}
