import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/compra_repository.dart';

final compraRepositoryProvider = Provider((ref) => CompraRepository());
