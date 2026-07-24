import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/sucursal_repository.dart';
import '../data/sucursal_model.dart';

final sucursalRepositoryProvider = Provider((ref) => SucursalRepository());

final sucursalesStreamProvider = StreamProvider<List<SucursalModel>>((ref) {
  return ref.watch(sucursalRepositoryProvider).obtenerSucursales();
});

final sucursalesActivasProvider = FutureProvider<List<SucursalModel>>((ref) {
  return ref.watch(sucursalRepositoryProvider).obtenerActivas();
});
