// Genera assets/images/logo_redondo.png (insignia circular con transparencia
// real) a partir de assets/images/logo_icono.png (ver
// tool/generar_logo_icono.dart), para usarlo como ícono de la app en Windows
// y como badge en login/splash/app bar. Se corre una sola vez a mano, DESPUÉS
// de generar_logo_icono.dart: `dart run tool/generar_logo_redondo.dart`.
//
// El fondo del logo ya es azul marino oscuro, muy cercano al navy de marca
// (0xFF0D2B4E) que usa la app alrededor del badge, así que no hace falta
// rellenar con blanco: se deja transparente fuera del círculo y el navy del
// logo queda como fondo del medallón.
import 'dart:io';
import 'dart:math' show sqrt;
import 'package:image/image.dart' as img;

void main() {
  final bytes = File('assets/images/logo_icono.png').readAsBytesSync();
  final original = img.decodePng(bytes);
  if (original == null) {
    stderr.writeln('No se pudo leer assets/images/logo_icono.png (corré primero tool/generar_logo_icono.dart)');
    exit(1);
  }

  const tamano = 512;
  final cuadrado = img.copyResize(original, width: tamano, height: tamano, interpolation: img.Interpolation.average);

  final circular = img.Image(width: tamano, height: tamano, numChannels: 4);
  const cx = tamano / 2;
  const cy = tamano / 2;
  const radio = tamano / 2;
  for (var y = 0; y < tamano; y++) {
    for (var x = 0; x < tamano; x++) {
      final dx = x - cx;
      final dy = y - cy;
      final distancia = sqrt(dx * dx + dy * dy);
      final origen = cuadrado.getPixel(x, y);
      if (distancia <= radio - 1) {
        circular.setPixelRgba(x, y, origen.r, origen.g, origen.b, 255);
      } else if (distancia <= radio + 1) {
        // Un pixel de antialiasing en el borde para que no se vea dentado.
        final alfa = (((radio + 1 - distancia) / 2) * 255).clamp(0, 255).round();
        circular.setPixelRgba(x, y, origen.r, origen.g, origen.b, alfa);
      } else {
        circular.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
  }
  File('assets/images/logo_redondo.png').writeAsBytesSync(img.encodePng(circular));
  // ignore: avoid_print
  print('Listo: assets/images/logo_redondo.png');
}
