import 'dart:convert';
import 'package:image/image.dart' as img;

final _cache = <String, img.Image?>{};

img.Image? decodificarLogoEscPos(String base64, {int maxDimension = 300}) {
  if (base64.isEmpty) return null;
  final clave = '$maxDimension:${base64.length}:${base64.substring(0, base64.length < 64 ? base64.length : 64)}';
  if (_cache.containsKey(clave)) return _cache[clave];
  try {
    final bytes = base64Decode(base64);
    final decodificada = img.decodeImage(bytes);
    if (decodificada == null) {
      _cache[clave] = null;
      return null;
    }
    final recortada = img.trim(decodificada);
    final necesitaReducir = recortada.width > maxDimension || recortada.height > maxDimension;
    final redimensionada = necesitaReducir
        ? img.copyResize(
            recortada,
            width: recortada.width >= recortada.height ? maxDimension : null,
            height: recortada.height > recortada.width ? maxDimension : null,
          )
        : recortada;
    final ditherizada = img.ditherImage(redimensionada, quantizer: img.BinaryQuantizer(), kernel: img.DitherKernel.floydSteinberg);
    final imagenFinal = ditherizada.convert(numChannels: 3);
    _cache[clave] = imagenFinal;
    return imagenFinal;
  } catch (_) {
    _cache[clave] = null;
    return null;
  }
}

List<int> rasterEscPos(img.Image imagen) {
  final ancho = imagen.width;
  final alto = imagen.height;
  final anchoBytes = (ancho + 7) ~/ 8;
  final datos = List<int>.filled(anchoBytes * alto, 0);
  for (var y = 0; y < alto; y++) {
    for (var x = 0; x < ancho; x++) {
      final p = imagen.getPixel(x, y);
      final luminancia = (p.r * 0.299 + p.g * 0.587 + p.b * 0.114);
      final opaco = imagen.numChannels < 4 || p.a > 127;
      if (opaco && luminancia < 128) {
        datos[y * anchoBytes + (x >> 3)] |= 0x80 >> (x & 7);
      }
    }
  }
  return [
    0x1B, 0x61, 0x01,
    0x1D, 0x76, 0x30, 0x00,
    anchoBytes & 0xFF, (anchoBytes >> 8) & 0xFF,
    alto & 0xFF, (alto >> 8) & 0xFF,
    ...datos,
    0x1B, 0x61, 0x00,
  ];
}
