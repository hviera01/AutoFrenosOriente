import 'package:cloud_firestore/cloud_firestore.dart';

/// Una fila del historial de existencia de un producto, vista a nivel
/// global (todos los productos juntos) en vez de dentro de un producto en
/// particular — mismos campos que HistorialStockModel, más el id/nombre del
/// producto al que pertenece (que la fila de Firestore no trae, se resuelve
/// aparte con la lista de productos ya cargada).
class MovimientoGlobalModel {
  final String id;
  final String idProducto;
  final String nombreProducto;
  final double stockAnterior;
  final double stockNuevo;
  final DateTime? fecha;
  final String usuario;
  final String motivo;

  MovimientoGlobalModel({
    required this.id,
    required this.idProducto,
    required this.nombreProducto,
    required this.stockAnterior,
    required this.stockNuevo,
    required this.fecha,
    required this.usuario,
    required this.motivo,
  });

  factory MovimientoGlobalModel.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc, String nombreProducto) {
    final data = doc.data();
    // doc.reference.parent es la subcolección 'historial'; su .parent es el
    // documento del producto dueño de este movimiento.
    final idProducto = doc.reference.parent.parent?.id ?? '';
    return MovimientoGlobalModel(
      id: doc.id,
      idProducto: idProducto,
      nombreProducto: nombreProducto,
      stockAnterior: (data['stockAnterior'] ?? 0).toDouble(),
      stockNuevo: (data['stockNuevo'] ?? 0).toDouble(),
      fecha: (data['fecha'] as Timestamp?)?.toDate(),
      usuario: data['usuario'] ?? '',
      motivo: data['motivo'] ?? '',
    );
  }
}
