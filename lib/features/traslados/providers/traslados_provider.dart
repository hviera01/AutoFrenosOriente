import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/traslado_repository.dart';
import '../data/traslado_model.dart';

final trasladoRepositoryProvider = Provider((ref) => TrasladoRepository());

final trasladosStreamProvider = StreamProvider<List<TrasladoModel>>((ref) {
  return ref.watch(trasladoRepositoryProvider).obtenerTraslados();
});
