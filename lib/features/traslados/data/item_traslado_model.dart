class ItemTrasladoModel {
  final String idProducto;
  final String nombreProducto;
  final double cantidad;

  ItemTrasladoModel({
    required this.idProducto,
    required this.nombreProducto,
    required this.cantidad,
  });

  factory ItemTrasladoModel.fromMap(Map<String, dynamic> data) {
    return ItemTrasladoModel(
      idProducto: data['idProducto'] ?? '',
      nombreProducto: data['nombreProducto'] ?? '',
      cantidad: (data['cantidad'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'idProducto': idProducto,
      'nombreProducto': nombreProducto,
      'cantidad': cantidad,
    };
  }
}
