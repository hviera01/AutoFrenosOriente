import 'package:cloud_firestore/cloud_firestore.dart';

class HistorialStockModel {
  final String id;
  final double stockAnterior;
  final double stockNuevo;
  final DateTime? fecha;
  final String usuario;
  final String motivo;

  HistorialStockModel({
    required this.id,
    required this.stockAnterior,
    required this.stockNuevo,
    required this.fecha,
    required this.usuario,
    required this.motivo,
  });

  factory HistorialStockModel.fromMap(String id, Map<String, dynamic> data) {
    return HistorialStockModel(
      id: id,
      stockAnterior: (data['stockAnterior'] ?? 0).toDouble(),
      stockNuevo: (data['stockNuevo'] ?? 0).toDouble(),
      fecha: (data['fecha'] as Timestamp?)?.toDate(),
      usuario: data['usuario'] ?? '',
      motivo: data['motivo'] ?? '',
    );
  }
}