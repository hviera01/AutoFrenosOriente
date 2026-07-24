import 'package:cloud_firestore/cloud_firestore.dart';

class VentaCreditoModel {
  final String id;
  final String documentoCliente;
  final String nombreCliente;
  final String numeroDocumento;
  final double montoTotal;
  final double saldoPendiente;
  final DateTime? fechaRegistro;
  final DateTime? fechaVencimiento;
  final bool fusionada;

  VentaCreditoModel({
    required this.id,
    required this.documentoCliente,
    required this.nombreCliente,
    required this.numeroDocumento,
    required this.montoTotal,
    required this.saldoPendiente,
    required this.fechaRegistro,
    required this.fechaVencimiento,
    this.fusionada = false,
  });

  bool get liquidada => saldoPendiente <= 0;

  bool get vencida => !liquidada && fechaVencimiento != null && DateTime.now().isAfter(fechaVencimiento!);

  factory VentaCreditoModel.fromMap(String id, Map<String, dynamic> data) {
    return VentaCreditoModel(
      id: id,
      documentoCliente: data['documentoCliente'] ?? '',
      nombreCliente: data['nombreCliente'] ?? '',
      numeroDocumento: data['numeroDocumento'] ?? '',
      montoTotal: (data['montoTotal'] ?? 0).toDouble(),
      saldoPendiente: (data['saldoPendiente'] ?? 0).toDouble(),
      fechaRegistro: (data['fechaRegistro'] as Timestamp?)?.toDate(),
      fechaVencimiento: (data['fechaVencimiento'] as Timestamp?)?.toDate(),
      fusionada: data['fusionada'] ?? false,
    );
  }

  String get textoBusqueda => '$numeroDocumento $nombreCliente $documentoCliente';
}
