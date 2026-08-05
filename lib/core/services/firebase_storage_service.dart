import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

/// Sube fotos de producto a Firebase Storage. A diferencia de Super Color
/// (sistema_ventas), que usa Cloudinary por un problema puntual de
/// facturación en ESE proyecto de Firebase, acá Storage sí funciona porque
/// el plan Blaze ya está activo — no hace falta un servicio externo.
class FirebaseStorageService {
  final _storage = FirebaseStorage.instance;

  /// Nombre de archivo único por subida (no reutiliza el nombre original):
  /// así cada foto nueva de un producto queda en su propia ruta, en vez de
  /// pisar el archivo anterior — evita que el CDN sirva una versión vieja
  /// cacheada bajo la misma URL.
  Future<String> subirImagenProducto(Uint8List bytes, String extension) async {
    final nombre = '${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ref = _storage.ref('productos/$nombre');
    await ref.putData(bytes, SettableMetadata(contentType: _contentType(extension)));
    return ref.getDownloadURL();
  }

  String _contentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
