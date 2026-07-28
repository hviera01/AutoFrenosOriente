import 'package:cloud_firestore/cloud_firestore.dart';

/// Un registro histórico de traslado de un producto: cuánto se movió, entre
/// qué sucursales y cuándo, en el orden en que se fueron registrando.
class HistorialTrasladoProductoModel {
  final String id;
  final String idTraslado;
  final String numero;
  final double cantidad;
  final DateTime? fecha;
  final String sucursalOrigen;
  final String sucursalDestino;
  final String usuario;

  HistorialTrasladoProductoModel({
    required this.id,
    required this.idTraslado,
    required this.numero,
    required this.cantidad,
    required this.fecha,
    required this.sucursalOrigen,
    required this.sucursalDestino,
    required this.usuario,
  });

  factory HistorialTrasladoProductoModel.fromMap(String id, Map<String, dynamic> data) {
    return HistorialTrasladoProductoModel(
      id: id,
      idTraslado: data['idTraslado'] ?? '',
      numero: data['numero'] ?? '',
      cantidad: (data['cantidad'] ?? 0).toDouble(),
      fecha: (data['fecha'] as Timestamp?)?.toDate(),
      sucursalOrigen: data['sucursalOrigen'] ?? '',
      sucursalDestino: data['sucursalDestino'] ?? '',
      usuario: data['usuario'] ?? '',
    );
  }
}
