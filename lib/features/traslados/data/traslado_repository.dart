import 'package:cloud_firestore/cloud_firestore.dart';
import 'traslado_model.dart';
import 'item_traslado_model.dart';

/// Traslados entre sucursales: a diferencia de Ventas/Compras, acá no se
/// toca el stock de Producto. El stock de este sistema es uno solo, global
/// (igual que en el sistema viejo, donde el stock por sucursal existía en la
/// base de datos pero nunca se llegó a usar de verdad en la aplicación) —
/// así que un traslado es una bitácora real de qué se movió, cuándo y entre
/// qué sucursales, no un movimiento de inventario.
class TrasladoRepository {
  final _db = FirebaseFirestore.instance;
  final _col = FirebaseFirestore.instance.collection('traslados');
  final _colContadores = FirebaseFirestore.instance.collection('contadores');

  Stream<List<TrasladoModel>> obtenerTraslados() {
    return _col.orderBy('fecha', descending: true).snapshots().asyncMap((snap) async {
      // Los detalle de cada traslado se piden todos en paralelo (Future.wait)
      // en vez de uno por uno en un for: con varios cientos de traslados, la
      // versión secuencial hacía esa cantidad de round-trips a Firestore uno
      // detrás del otro cada vez que llegaba un snapshot nuevo, lo que se
      // sentía como una carga eterna al abrir la pantalla.
      final detalles = await Future.wait(snap.docs.map((doc) => doc.reference.collection('detalle').get()));
      return [
        for (var i = 0; i < snap.docs.length; i++)
          TrasladoModel.fromMap(
            snap.docs[i].id,
            snap.docs[i].data(),
            detalles[i].docs.map((d) => ItemTrasladoModel.fromMap(d.data())).toList(),
          ),
      ];
    });
  }

  Future<List<TrasladoModel>> obtenerPorRango(DateTime inicio, DateTime finInclusive, {String? estado, String? idSucursal}) async {
    Query<Map<String, dynamic>> query = _col.where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio)).where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(finInclusive));
    final snap = await query.orderBy('fecha', descending: true).get();
    final lista = <TrasladoModel>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      if (estado != null && estado.isNotEmpty && data['estado'] != estado) continue;
      if (idSucursal != null && idSucursal.isNotEmpty && data['idSucursalOrigen'] != idSucursal && data['idSucursalDestino'] != idSucursal) continue;
      final detalleSnap = await doc.reference.collection('detalle').get();
      final detalle = detalleSnap.docs.map((d) => ItemTrasladoModel.fromMap(d.data())).toList();
      lista.add(TrasladoModel.fromMap(doc.id, data, detalle));
    }
    return lista;
  }

  Future<TrasladoModel?> obtenerPorId(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    final detalleSnap = await doc.reference.collection('detalle').get();
    final detalle = detalleSnap.docs.map((d) => ItemTrasladoModel.fromMap(d.data())).toList();
    return TrasladoModel.fromMap(doc.id, doc.data()!, detalle);
  }

  Future<TrasladoModel?> obtenerPorNumero(String numero) async {
    final snap = await _col.where('numero', isEqualTo: numero.trim()).limit(1).get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    final detalleSnap = await doc.reference.collection('detalle').get();
    final detalle = detalleSnap.docs.map((d) => ItemTrasladoModel.fromMap(d.data())).toList();
    return TrasladoModel.fromMap(doc.id, doc.data(), detalle);
  }

  Future<TrasladoModel> registrar({
    required String idSucursalOrigen,
    required String nombreSucursalOrigen,
    required String idSucursalDestino,
    required String nombreSucursalDestino,
    required String observaciones,
    required String usuarioCrea,
    required List<ItemTrasladoModel> detalle,
  }) async {
    if (idSucursalOrigen == idSucursalDestino) {
      throw Exception('La sucursal origen y destino no pueden ser la misma');
    }
    if (detalle.isEmpty) {
      throw Exception('Agregá al menos un producto');
    }
    final contadorRef = _colContadores.doc('traslado');
    final trasladoRef = _col.doc();
    late String numero;

    await _db.runTransaction((transaction) async {
      final contadorSnap = await transaction.get(contadorRef);
      final actual = ((contadorSnap.data()?['ultimo'] ?? 0) as num).toInt();
      final nuevo = actual + 1;
      numero = 'TRAS-${nuevo.toString().padLeft(6, '0')}';
      transaction.set(contadorRef, {'ultimo': nuevo}, SetOptions(merge: true));
      transaction.set(trasladoRef, {
        'numero': numero,
        'idSucursalOrigen': idSucursalOrigen,
        'nombreSucursalOrigen': nombreSucursalOrigen,
        'idSucursalDestino': idSucursalDestino,
        'nombreSucursalDestino': nombreSucursalDestino,
        'fecha': FieldValue.serverTimestamp(),
        'estado': 'Pendiente',
        'observaciones': observaciones,
        'usuarioCrea': usuarioCrea,
        'usuarioRecibe': '',
      });
      for (final item in detalle) {
        transaction.set(trasladoRef.collection('detalle').doc(), item.toMap());
      }
    });

    return TrasladoModel(
      id: trasladoRef.id,
      numero: numero,
      idSucursalOrigen: idSucursalOrigen,
      nombreSucursalOrigen: nombreSucursalOrigen,
      idSucursalDestino: idSucursalDestino,
      nombreSucursalDestino: nombreSucursalDestino,
      fecha: DateTime.now(),
      estado: 'Pendiente',
      observaciones: observaciones,
      usuarioCrea: usuarioCrea,
      detalle: detalle,
    );
  }

  Future<void> enviar(String id) async {
    final doc = await _col.doc(id).get();
    if (doc.data()?['estado'] != 'Pendiente') {
      throw Exception('Solo se puede enviar un traslado que está Pendiente');
    }
    await _col.doc(id).update({'estado': 'Enviado'});
  }

  Future<void> recepcionar(String id, {required String usuarioRecibe}) async {
    final doc = await _col.doc(id).get();
    if (doc.data()?['estado'] != 'Enviado') {
      throw Exception('Solo se puede recibir un traslado que está Enviado');
    }
    await _col.doc(id).update({
      'estado': 'Entregado',
      'usuarioRecibe': usuarioRecibe,
      'fechaRecepcion': FieldValue.serverTimestamp(),
    });
  }

  Future<void> anular(String id) async {
    final doc = await _col.doc(id).get();
    final estado = doc.data()?['estado'];
    if (estado == 'Entregado' || estado == 'Anulado') {
      throw Exception('Un traslado $estado no se puede anular');
    }
    await _col.doc(id).update({'estado': 'Anulado'});
  }
}
