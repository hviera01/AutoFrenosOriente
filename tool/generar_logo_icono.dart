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
// OJO -dos vueltas de ajuste ya-: la v1 (x:315,y:90,650x650) dejaba el
// disco+pinza tocando casi los 4 bordes. La v2 le agregó margen AL RECORTE,
// pero el disco es ancho de lado a lado: aunque las ESQUINAS del cuadrado
// tuvieran margen de sobra, el círculo inscripto (logo_redondo.png, usado en
// Windows/login/menú) toca el CENTRO de cada lado del cuadrado sin ningún
// margen ahí -y el borde izquierdo/derecho del disco cae justo en esa franja
// central-, así que seguía viéndose cortado en redondo aunque en el
// cuadrado ya se viera bien. Esta v3 no confía en el margen del recorte:
// primero recorta ajustado (como v1) y DESPUÉS achica ese contenido al 68%
// centrado sobre un lienzo del color de fondo del logo (mismo lienzo que
// usan tanto el ícono cuadrado como, a partir de él, el redondo) — así el
// margen es uniforme en los 4 lados Y en el medio de cada lado, sin
// depender de dónde caigan justo los bordes del disco.
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

  const tamano = 1024;
  const escala = 0.68; // 68% del lienzo: ~16% de margen uniforme en cada lado.
  final contenido = (tamano * escala).round();
  final chico = img.copyResize(icono, width: contenido, height: contenido, interpolation: img.Interpolation.average);

  // Color de fondo real del logo (esquina superior izquierda del recorte,
  // que siempre cae en el fondo navy oscuro, nunca en el disco): así el
  // margen agregado se funde con el resto de la imagen en vez de notarse
  // como un color distinto.
  final fondo = icono.getPixel(0, 0);

  final lienzo = img.Image(width: tamano, height: tamano, numChannels: 3);
  img.fill(lienzo, color: img.ColorRgb8(fondo.r.toInt(), fondo.g.toInt(), fondo.b.toInt()));
  final offset = ((tamano - contenido) / 2).round();
  img.compositeImage(lienzo, chico, dstX: offset, dstY: offset);

  File('assets/images/logo_icono.png').writeAsBytesSync(img.encodePng(lienzo));
  // ignore: avoid_print
  print('Listo: assets/images/logo_icono.png');
}
