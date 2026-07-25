// Genera assets/images/logo_redondo.png (insignia circular con transparencia
// real del logo) a partir de assets/images/logo.jpg, para usarlo como ícono
// de la app en Windows y como badge en login/splash/app bar. Se corre una
// sola vez a mano: `dart run tool/generar_logo_redondo.dart`.
//
// El logo de este negocio es un "lockup" cuadrado: el disco de freno arriba
// + el texto "AUTO FRENOS DE ORIENTE" abajo, casi hasta los bordes. Si se
// recorta directo a círculo (como hacía la versión anterior de este script,
// con copyResizeCropSquare + máscara), el círculo inscripto en el cuadrado
// corta las esquinas y se come pedazos del texto — se veía "muy grande,
// cortado". Acá en cambio el logo se ACHICA primero (66% del lienzo) y se
// centra sobre un fondo blanco circular, para que el logo completo (ícono +
// texto) quede siempre adentro del círculo, con margen.
//
// OJO: no alcanza con una máscara simple — el JPEG de origen no tiene canal
// alfa, así que las esquinas "transparentes" fuera del círculo terminarían
// siendo negro sólido y opaco si se hereda el número de canales de la imagen
// de origen (por eso el ícono de Windows salía con un marco negro feo antes
// de este fix). Acá se arma la imagen circular a mano, en una imagen RGBA
// nueva de 4 canales, para que la transparencia sea real.
import 'dart:io';
import 'dart:math' show sqrt;
import 'package:image/image.dart' as img;

void main() {
  final bytes = File('assets/images/logo.jpg').readAsBytesSync();
  final original = img.decodeJpg(bytes);
  if (original == null) {
    stderr.writeln('No se pudo leer assets/images/logo.jpg');
    exit(1);
  }
  const tamano = 512;
  // 66% del lienzo: con el logo actual (icono + texto casi al borde) deja
  // margen de sobra para que ninguna esquina del contenido quede fuera del
  // círculo inscripto (el punto más lejano del centro, en un cuadrado de
  // este tamaño, cae bien adentro del radio del círculo).
  const escala = 0.66;
  final contenido = (tamano * escala).round();
  final cuadrado = img.copyResizeCropSquare(original, size: tamano);
  final chico = img.copyResize(cuadrado, width: contenido, height: contenido, interpolation: img.Interpolation.average);

  final circular = img.Image(width: tamano, height: tamano, numChannels: 4);
  // Offset para centrar el logo achicado dentro del lienzo; el fondo blanco
  // opaco alrededor (dentro del círculo pero fuera de "chico") hace que el
  // margen ganado al achicar se vea como una insignia blanca prolija, no
  // transparente.
  final offset = ((tamano - contenido) / 2).round();

  const cx = tamano / 2;
  const cy = tamano / 2;
  const radio = tamano / 2;
  for (var y = 0; y < tamano; y++) {
    for (var x = 0; x < tamano; x++) {
      final dx = x - cx;
      final dy = y - cy;
      final distancia = sqrt(dx * dx + dy * dy);
      final dentroDelLogo = x >= offset && x < offset + contenido && y >= offset && y < offset + contenido;
      final origen = dentroDelLogo ? chico.getPixel(x - offset, y - offset) : null;
      final r = origen?.r ?? 255, g = origen?.g ?? 255, b = origen?.b ?? 255;
      if (distancia <= radio - 1) {
        circular.setPixelRgba(x, y, r, g, b, 255);
      } else if (distancia <= radio + 1) {
        // Un pixel de antialiasing en el borde para que no se vea dentado.
        final alfa = (((radio + 1 - distancia) / 2) * 255).clamp(0, 255).round();
        circular.setPixelRgba(x, y, r, g, b, alfa);
      } else {
        circular.setPixelRgba(x, y, 255, 255, 255, 0);
      }
    }
  }
  File('assets/images/logo_redondo.png').writeAsBytesSync(img.encodePng(circular));
  // ignore: avoid_print
  print('Listo: assets/images/logo_redondo.png');
}
