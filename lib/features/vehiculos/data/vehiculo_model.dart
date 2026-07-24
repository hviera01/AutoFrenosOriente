class VehiculoModel {
  final String id;
  final String idCliente;
  final String nombreCliente;
  final String marca;
  final String modelo;
  final String anio;
  final String placa;

  VehiculoModel({
    required this.id,
    required this.idCliente,
    required this.nombreCliente,
    required this.marca,
    required this.modelo,
    required this.anio,
    required this.placa,
  });

  factory VehiculoModel.fromMap(String id, Map<String, dynamic> data) {
    return VehiculoModel(
      id: id,
      idCliente: data['idCliente'] ?? '',
      nombreCliente: data['nombreCliente'] ?? '',
      marca: data['marca'] ?? '',
      modelo: data['modelo'] ?? '',
      anio: data['anio'] ?? '',
      placa: data['placa'] ?? '',
    );
  }

  /// Texto formateado para autocompletar el campo "Vehículo" de una venta,
  /// igual que hacía el sistema viejo al elegir un vehículo del cliente.
  String get descripcion {
    final partes = [marca, modelo, anio].where((p) => p.trim().isNotEmpty).join(' ');
    return placa.trim().isEmpty ? partes : '$partes (${placa.trim()})';
  }

  String get textoBusqueda => '$marca $modelo $anio $placa $nombreCliente';
}
