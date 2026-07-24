// Genera los íconos de web/icons/ (Icon-192, Icon-512 y sus variantes
// "maskable") a partir de assets/images/logo.jpg. flutter_launcher_icons no
// cubre la carpeta web, así que este paso queda aparte. Se corre una sola
// vez a mano: `dart run tool/generar_iconos_web.dart`.
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final bytes = File('assets/images/logo.jpg').readAsBytesSync();
  final original = img.decodeJpg(bytes);
  if (original == null) {
    stderr.writeln('No se pudo leer assets/images/logo.jpg');
    exit(1);
  }

  void generar(String archivo, int tamano) {
    final cuadrado = img.copyResizeCropSquare(original, size: tamano);
    File('web/icons/$archivo').writeAsBytesSync(img.encodePng(cuadrado));
    // ignore: avoid_print
    print('Listo: web/icons/$archivo');
  }

  generar('Icon-192.png', 192);
  generar('Icon-512.png', 512);
  // Maskable: el logo ya tiene bastante margen alrededor del texto, así que
  // usar la misma imagen cuadrada alcanza sin que el "safe zone" de Android
  // recorte el texto.
  generar('Icon-maskable-192.png', 192);
  generar('Icon-maskable-512.png', 512);

  // favicon.png (pestaña del navegador) vive suelto en web/, no en
  // web/icons/ — si no, se queda con el ícono viejo aunque el resto ya esté
  // actualizado.
  final favicon = img.copyResizeCropSquare(original, size: 64);
  File('web/favicon.png').writeAsBytesSync(img.encodePng(favicon));
  // ignore: avoid_print
  print('Listo: web/favicon.png');
}
