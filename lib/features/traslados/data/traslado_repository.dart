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

  /// El filtro de estado/sucursal se aplica ANTES de pedir el detalle (no
  /// después), y el detalle de los que quedan se pide todo junto con
  /// Future.wait (no uno por uno en un for): mismo motivo que en
  /// obtenerTraslados — con cientos de traslados en el rango, hacer un
  /// round-trip a Firestore detrás de otro para cada uno hacía sentir el
  /// Reporte de Traslados eterno para cargar.
  Future<List<TrasladoModel>> obtenerPorRango(DateTime inicio, DateTime finInclusive, {String? estado, String? idSucursal}) async {
    Query<Map<String, dynamic>> query = _col.where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio)).where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(finInclusive));
    final snap = await query.orderBy('fecha', descending: true).get();
    final docsFiltrados = snap.docs.where((doc) {
      final data = doc.data();
      if (estado != null && estado.isNotEmpty && data['estado'] != estado) return false;
      if (idSucursal != null && idSucursal.isNotEmpty && data['idSucursalOrigen'] != idSucursal && data['idSucursalDestino'] != idSucursal) return false;
      return true;
    }).toList();
    final detalles = await Future.wait(docsFiltrados.map((doc) => doc.reference.collection('detalle').get()));
    return [
      for (var i = 0; i < docsFiltrados.length; i++)
        TrasladoModel.fromMap(
          docsFiltrados[i].id,
          docsFiltrados[i].data(),
          detalles[i].docs.map((d) => ItemTrasladoModel.fromMap(d.data())).toList(),
        ),
    ];
  }

  Future<TrasladoModel?> obtenerPorId(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    final detalleSnap = await doc.reference.collection('detalle').get();
    final detalle = detalleSnap.docs.map((d) => ItemTrasladoModel.fromMap(d.data())).toList();
    return TrasladoModel.fromMap(doc.id, doc.data()!, detalle);
  }

  /// Busca sin que el usuario tenga que escribir "TRAS-" ni los ceros de
  /// relleno (por ejemplo "123" en vez de "TRAS-000123"): arma las variantes
  /// posibles del número y las busca todas en paralelo (mismo patrón que
  /// buscarVentasPorNumeroDocumento en VentaRepository).
  Set<String> _candidatosNumero(String texto) {
    final limpio = texto.trim();
    final candidatos = <String>{limpio};
    final sinPrefijo = limpio.replaceFirst(RegExp(r'^tras-?', caseSensitive: false), '');
    if (RegExp(r'^\d+$').hasMatch(sinPrefijo)) {
      candidatos.add('TRAS-${sinPrefijo.padLeft(6, '0')}');
    }
    return candidatos;
  }

  Future<TrasladoModel?> obtenerPorNumero(String numero) async {
    final candidatos = _candidatosNumero(numero);
    final snaps = await Future.wait(candidatos.map((c) => _col.where('numero', isEqualTo: c).limit(1).get()));
    final docs = snaps.expand((s) => s.docs).toList();
    if (docs.isEmpty) return null;
    final doc = docs.first;
    final detalleSnap = await doc.reference.collection('detalle').get();
    final detalle = detalleSnap.docs.map((d) => ItemTrasladoModel.fromMap(d.data())).toList();
    return TrasladoModel.fromMap(doc.id, doc.data(), detalle);
  }

  /// [estadoInicial] deja el traslado creado directo en Pendiente/Enviado/
  /// Entregado (usado por RegistrarTrasladoScreen, que deja elegir el estado
  /// final de una vez): antes la pantalla encadenaba registrar() + enviar()
  /// + recepcionar() + un obtenerPorId() final, hasta 4 round-trips
  /// secuenciales a Firestore para el caso más común (Entregado, que viene
  /// preseleccionado por defecto). Ahora es un solo round-trip. [usuarioRecibe]
  /// solo aplica (y hace falta) cuando estadoInicial es 'Entregado'.
  Future<TrasladoModel> registrar({
    required String idSucursalOrigen,
    required String nombreSucursalOrigen,
    required String idSucursalDestino,
    required String nombreSucursalDestino,
    required String observaciones,
    required String usuarioCrea,
    required List<ItemTrasladoModel> detalle,
    String estadoInicial = 'Pendiente',
    String usuarioRecibe = '',
  }) async {
    if (idSucursalOrigen == idSucursalDestino) {
      throw Exception('La sucursal origen y destino no pueden ser la misma');
    }
    if (detalle.isEmpty) {
      throw Exception('Agregá al menos un producto');
    }
    final contadorRef = _colContadores.doc('traslado');
    final trasladoRef = _col.doc();
    final ahora = DateTime.now();
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
        'estado': estadoInicial,
        'observaciones': observaciones,
        'usuarioCrea': usuarioCrea,
        'usuarioRecibe': estadoInicial == 'Entregado' ? usuarioRecibe : '',
        if (estadoInicial == 'Entregado') 'fechaRecepcion': FieldValue.serverTimestamp(),
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
      fecha: ahora,
      estado: estadoInicial,
      observaciones: observaciones,
      usuarioCrea: usuarioCrea,
      usuarioRecibe: estadoInicial == 'Entregado' ? usuarioRecibe : '',
      fechaRecepcion: estadoInicial == 'Entregado' ? ahora : null,
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
  /// restado al registrarlo (igual que anularVenta en VentaRepository). Se
  /// puede anular en cualquier estado -incluido Entregado-: a diferencia de
  /// antes (cuando el traslado era solo una bitácora y Entregado marcaba un
  /// punto sin retorno del lado del flujo de trabajo), ahora que el stock se
  /// resta desde el registro, la única anulación que de verdad no tiene
  /// sentido es la de un traslado ya Anulado.
  Future<void> anular(String id, {required String usuario}) async {
    final doc = await _col.doc(id).get();
    final data = doc.data();
    final estado = data?['estado'];
    if (estado == 'Anulado') {
      throw Exception('Este traslado ya está anulado');
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
