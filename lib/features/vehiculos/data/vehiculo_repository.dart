import 'package:cloud_firestore/cloud_firestore.dart';
import 'vehiculo_model.dart';

class VehiculoRepository {
  final _col = FirebaseFirestore.instance.collection('vehiculos');

  Stream<List<VehiculoModel>> obtenerVehiculos() {
    return _col.orderBy('nombreCliente').snapshots().map((snap) {
      return snap.docs.map((d) => VehiculoModel.fromMap(d.id, d.data())).toList();
    });
  }

  Future<List<VehiculoModel>> obtenerPorCliente(String idCliente) async {
    if (idCliente.isEmpty) return [];
    final snap = await _col.where('idCliente', isEqualTo: idCliente).get();
    return snap.docs.map((d) => VehiculoModel.fromMap(d.id, d.data())).toList();
  }

  Future<void> crear({
    required String idCliente,
    required String nombreCliente,
    required String marca,
    required String modelo,
    required String anio,
    required String placa,
  }) async {
    if (marca.trim().isEmpty) throw Exception('La marca es obligatoria');
    await _col.add({
      'idCliente': idCliente,
      'nombreCliente': nombreCliente,
      'marca': marca.trim(),
      'modelo': modelo.trim(),
      'anio': anio.trim(),
      'placa': placa.trim(),
      'fechaRegistro': FieldValue.serverTimestamp(),
    });
  }

  Future<void> actualizar({
    required String id,
    required String idCliente,
    required String nombreCliente,
    required String marca,
    required String modelo,
    required String anio,
    required String placa,
  }) async {
    if (marca.trim().isEmpty) throw Exception('La marca es obligatoria');
    await _col.doc(id).update({
      'idCliente': idCliente,
      'nombreCliente': nombreCliente,
      'marca': marca.trim(),
      'modelo': modelo.trim(),
      'anio': anio.trim(),
      'placa': placa.trim(),
    });
  }

  Future<void> eliminar(String id) async {
    await _col.doc(id).delete();
  }
}
