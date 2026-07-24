import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/vehiculo_repository.dart';
import '../data/vehiculo_model.dart';

final vehiculoRepositoryProvider = Provider((ref) => VehiculoRepository());

final vehiculosStreamProvider = StreamProvider<List<VehiculoModel>>((ref) {
  return ref.watch(vehiculoRepositoryProvider).obtenerVehiculos();
});
