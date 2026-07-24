import 'package:cloud_firestore/cloud_firestore.dart';
import 'sucursal_model.dart';

class SucursalRepository {
  final _col = FirebaseFirestore.instance.collection('sucursales');

  Stream<List<SucursalModel>> obtenerSucursales() {
    return _col.orderBy('nombre').snapshots().map((snap) {
      return snap.docs.map((d) => SucursalModel.fromMap(d.id, d.data())).toList();
    });
  }

  Future<List<SucursalModel>> obtenerActivas() async {
    final snap = await _col.where('estado', isEqualTo: true).get();
    final lista = snap.docs.map((d) => SucursalModel.fromMap(d.id, d.data())).toList();
    lista.sort((a, b) => a.nombre.compareTo(b.nombre));
    return lista;
  }

  Future<void> crear({required String nombre, required String direccion, required bool estado}) async {
    if (nombre.trim().isEmpty) throw Exception('El nombre es obligatorio');
    await _col.add({
      'nombre': nombre.trim(),
      'direccion': direccion.trim(),
      'estado': estado,
      'fechaRegistro': FieldValue.serverTimestamp(),
    });
  }

  Future<void> actualizar({required String id, required String nombre, required String direccion, required bool estado}) async {
    if (nombre.trim().isEmpty) throw Exception('El nombre es obligatorio');
    await _col.doc(id).update({
      'nombre': nombre.trim(),
      'direccion': direccion.trim(),
      'estado': estado,
    });
  }

  Future<void> eliminar(String id) async {
    await _col.doc(id).delete();
  }
}
