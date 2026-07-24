class ClienteModel {
  final String id;
  final String dni;
  final String nombreCompleto;
  final String correo;
  final String telefono;
  final bool estado;

  ClienteModel({
    required this.id,
    required this.dni,
    required this.nombreCompleto,
    required this.correo,
    required this.telefono,
    required this.estado,
  });

  factory ClienteModel.fromMap(String id, Map<String, dynamic> data) {
    return ClienteModel(
      id: id,
      dni: data['dni'] ?? '',
      nombreCompleto: data['nombreCompleto'] ?? '',
      correo: data['correo'] ?? '',
      telefono: data['telefono'] ?? '',
      estado: data['estado'] ?? true,
    );
  }

  String get textoBusqueda => '$dni $nombreCompleto $correo $telefono';
}
