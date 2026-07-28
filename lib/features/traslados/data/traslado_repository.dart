import 'package:cloud_firestore/cloud_firestore.dart';
import 'traslado_model.dart';
import 'item_traslado_model.dart';

/// Traslados entre sucursales: el stock de este sistema es uno solo, global
/// (no hay inventario separado por sucursal — la otra sucursal todavía no
/// tiene su propio sistema). Por eso un traslado se trata como una salida de
/// ese stock único, igual que una venta: al registrarlo se resta, con su
/// entrada en el historial de stock del producto; si se anula, se repone,
/// también con su historial (igual que anularVenta en VentaRepository).
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

    // Si el detalle repite el mismo producto en más de una línea, la resta
    // de stock debe sumar esas cantidades (no pisar una resta con la otra).
    final idsProductoUnicos = detalle.map((i) => i.idProducto).toSet().toList();

    await _db.runTransaction((transaction) async {
      // El contador y el stock de cada producto no dependen uno del otro,
      // así que se leen juntos en vez de esperar uno antes del otro.
      final futureResultados = Future.wait([
        transaction.get(contadorRef),
        ...idsProductoUnicos.map((id) => transaction.get(_db.collection('productos').doc(id))),
      ]);
      final resultados = await futureResultados;
      final contadorSnap = resultados[0];
      final snapsStock = resultados.sublist(1);

      final actual = ((contadorSnap.data()?['ultimo'] ?? 0) as num).toInt();
      final nuevo = actual + 1;
      numero = 'TRAS-${nuevo.toString().padLeft(6, '0')}';

      final stocksActuales = <String, double>{
        for (var i = 0; i < idsProductoUnicos.length; i++) idsProductoUnicos[i]: ((snapsStock[i].data()?['stock'] ?? 0) as num).toDouble(),
      };

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

      for (final item in detalle) {
        final ref = _db.collection('productos').doc(item.idProducto);
        final stockActual = stocksActuales[item.idProducto] ?? 0;
        // Nunca queda en negativo, igual que en Ventas.
        final stockNuevo = (stockActual - item.cantidad) < 0 ? 0.0 : stockActual - item.cantidad;
        stocksActuales[item.idProducto] = stockNuevo;
        transaction.update(ref, {'stock': stockNuevo});
        final historialRef = ref.collection('historial').doc();
        transaction.set(historialRef, {
          'stockAnterior': stockActual,
          'stockNuevo': stockNuevo,
          'usuario': usuarioCrea,
          'motivo': 'Traslado $numero a $nombreSucursalDestino',
          'fecha': FieldValue.serverTimestamp(),
        });
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

  /// Anula un traslado y repone al stock las cantidades que se le habían
  /// restado al registrarlo (igual que anularVenta en VentaRepository).
  Future<void> anular(String id, {required String usuario}) async {
    final doc = await _col.doc(id).get();
    final data = doc.data();
    final estado = data?['estado'];
    if (estado == 'Entregado' || estado == 'Anulado') {
      throw Exception('Un traslado $estado no se puede anular');
    }
    final numero = data?['numero'] as String? ?? '';
    final detalleSnap = await _col.doc(id).collection('detalle').get();
    final items = detalleSnap.docs.map((d) => ItemTrasladoModel.fromMap(d.data())).toList();
    final idsProductoUnicos = items.map((i) => i.idProducto).toSet().toList();

    await _db.runTransaction((transaction) async {
      final snapsStock = await Future.wait(idsProductoUnicos.map((pid) => transaction.get(_db.collection('productos').doc(pid))));
      final stocksActuales = <String, double>{
        for (var i = 0; i < idsProductoUnicos.length; i++) idsProductoUnicos[i]: ((snapsStock[i].data()?['stock'] ?? 0) as num).toDouble(),
      };

      transaction.update(_col.doc(id), {'estado': 'Anulado'});

      for (final item in items) {
        final ref = _db.collection('productos').doc(item.idProducto);
        final stockActual = stocksActuales[item.idProducto] ?? 0;
        final stockNuevo = stockActual + item.cantidad;
        stocksActuales[item.idProducto] = stockNuevo;
        transaction.update(ref, {'stock': stockNuevo});
        final historialRef = ref.collection('historial').doc();
        transaction.set(historialRef, {
          'stockAnterior': stockActual,
          'stockNuevo': stockNuevo,
          'usuario': usuario,
          'motivo': 'Anulación de traslado $numero',
          'fecha': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}
