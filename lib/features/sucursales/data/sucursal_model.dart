class SucursalModel {
  final String id;
  final String nombre;
  final String direccion;
  final bool estado;

  SucursalModel({
    required this.id,
    required this.nombre,
    required this.direccion,
    required this.estado,
  });

  factory SucursalModel.fromMap(String id, Map<String, dynamic> data) {
    return SucursalModel(
      id: id,
      nombre: data['nombre'] ?? '',
      direccion: data['direccion'] ?? '',
      estado: data['estado'] ?? true,
    );
  }

  String get textoBusqueda => '$nombre $direccion';
}
