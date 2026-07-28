// Genera los íconos de web/icons/ (Icon-192, Icon-512 y sus variantes
// "maskable") a partir de assets/images/logo_icono.png (ver
// tool/generar_logo_icono.dart: el ícono del disco+pinza SOLO, sin el texto
// del lockup completo, que se vuelve ilegible a estos tamaños). No usa
// logo.jpg directo. flutter_launcher_icons no cubre la carpeta web, así que
// este paso queda aparte. Se corre a mano, DESPUÉS de generar_logo_icono.dart:
// `dart run tool/generar_iconos_web.dart`.
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final bytes = File('assets/images/logo_icono.png').readAsBytesSync();
  final original = img.decodePng(bytes);
  if (original == null) {
    stderr.writeln('No se pudo leer assets/images/logo_icono.png (corré primero tool/generar_logo_icono.dart)');
    exit(1);
  }

  void generar(String archivo, int tamano) {
    final cuadrado = img.copyResize(original, width: tamano, height: tamano, interpolation: img.Interpolation.average);
    File('web/icons/$archivo').writeAsBytesSync(img.encodePng(cuadrado));
    // ignore: avoid_print
    print('Listo: web/icons/$archivo');
  }

  generar('Icon-192.png', 192);
  generar('Icon-512.png', 512);
  // Maskable: el ícono (disco+pinza) ya tiene margen de sobra alrededor
  // (viene con fondo navy hasta los bordes del recorte), así que usar la
  // misma imagen cuadrada alcanza sin que el "safe zone" de Android recorte
  // nada importante.
  generar('Icon-maskable-192.png', 192);
  generar('Icon-maskable-512.png', 512);

  // favicon.png (pestaña del navegador) vive suelto en web/, no en
  // web/icons/ — si no, se queda con el ícono viejo aunque el resto ya esté
  // actualizado.
  final favicon = img.copyResize(original, width: 64, height: 64, interpolation: img.Interpolation.average);
  File('web/favicon.png').writeAsBytesSync(img.encodePng(favicon));
  // ignore: avoid_print
  print('Listo: web/favicon.png');
}
