import 'package:cloud_firestore/cloud_firestore.dart';
import 'item_traslado_model.dart';

/// Estados posibles, igual que en el sistema viejo: Pendiente (recién
/// creado, todavía no salió), Enviado (salió de la sucursal origen),
/// Entregado (la sucursal destino confirmó que lo recibió), Anulado.
class TrasladoModel {
  final String id;
  final String numero;
  final String idSucursalOrigen;
  final String nombreSucursalOrigen;
  final String idSucursalDestino;
  final String nombreSucursalDestino;
  final DateTime? fecha;
  final String estado;
  final String observaciones;
  final String usuarioCrea;
  final String usuarioRecibe;
  final DateTime? fechaRecepcion;
  final List<ItemTrasladoModel> detalle;

  TrasladoModel({
    required this.id,
    required this.numero,
    required this.idSucursalOrigen,
    required this.nombreSucursalOrigen,
    required this.idSucursalDestino,
    required this.nombreSucursalDestino,
    this.fecha,
    this.estado = 'Pendiente',
    this.observaciones = '',
    required this.usuarioCrea,
    this.usuarioRecibe = '',
    this.fechaRecepcion,
    this.detalle = const [],
  });

  double get totalItems => detalle.fold<double>(0, (s, i) => s + i.cantidad);

  factory TrasladoModel.fromMap(String id, Map<String, dynamic> data, List<ItemTrasladoModel> detalle) {
    return TrasladoModel(
      id: id,
      numero: data['numero'] ?? '',
      idSucursalOrigen: data['idSucursalOrigen'] ?? '',
      nombreSucursalOrigen: data['nombreSucursalOrigen'] ?? '',
      idSucursalDestino: data['idSucursalDestino'] ?? '',
      nombreSucursalDestino: data['nombreSucursalDestino'] ?? '',
      fecha: (data['fecha'] as Timestamp?)?.toDate(),
      estado: data['estado'] ?? 'Pendiente',
      observaciones: data['observaciones'] ?? '',
      usuarioCrea: data['usuarioCrea'] ?? '',
      usuarioRecibe: data['usuarioRecibe'] ?? '',
      fechaRecepcion: (data['fechaRecepcion'] as Timestamp?)?.toDate(),
      detalle: detalle,
    );
  }
}
