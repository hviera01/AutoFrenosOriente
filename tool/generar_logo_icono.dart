// Genera assets/images/logo_icono.png: el ícono del disco+pinza SOLO (sin el
// texto "AUTO FRENOS DE ORIENTE" de abajo), recortado del logo completo
// (assets/images/logo.jpg). El lockup completo tiene texto que se vuelve
// ilegible/se ve "sucio" a los tamaños chicos de un ícono (favicon, ícono de
// Android) -por eso este recorte cuadrado es la fuente para TODOS los
// íconos (web, Android, y de acá sale también el redondo de Windows/login,
// ver generar_logo_redondo.dart), en vez de usar logo.jpg directo.
//
// Coordenadas de recorte medidas a mano sobre el logo actual (1254x1254):
// si el logo cambia en el futuro, hay que volver a medirlas (escanear
// filas/columnas de píxeles "brillantes" para encontrar los bordes del
// ícono y el hueco antes del texto, como se hizo la primera vez).
//
// OJO: la primera versión de este recorte (x:315,y:90,650x650) dejaba el
// disco+pinza tocando casi los 4 bordes del cuadrado -se veía "cortado" en
// Windows/APK/web-. Este recorte deja margen de sobra (fondo navy, que ya
// es el color de fondo del logo, así que el margen extra no se nota como
// una "caja" pegada) en los cuatro lados, con más cuidado abajo porque el
// texto del lockup empieza enseguida después del disco.
// Se corre a mano: `dart run tool/generar_logo_icono.dart`.
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final bytes = File('assets/images/logo.jpg').readAsBytesSync();
  final original = img.decodeJpg(bytes);
  if (original == null) {
    stderr.writeln('No se pudo leer assets/images/logo.jpg');
    exit(1);
  }
  final icono = img.copyCrop(original, x: 310, y: 54, width: 700, height: 700);
  final grande = img.copyResize(icono, width: 1024, height: 1024, interpolation: img.Interpolation.average);
  File('assets/images/logo_icono.png').writeAsBytesSync(img.encodePng(grande));
  // ignore: avoid_print
  print('Listo: assets/images/logo_icono.png');
}
