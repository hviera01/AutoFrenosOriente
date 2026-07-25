import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Tema compartido para todo lo que se imprime (tickets de venta, traslado,
// PDFs formales): Open Sans en vez de la Helvetica por defecto del paquete
// pdf, mucho más clara para leer en una impresora térmica o en papel a
// tamaños chicos -a pedido explícito del usuario, que la encontró borrosa/
// poco clara con la fuente anterior-. Se carga una sola vez (los .ttf de
// Google Fonts pesan varios cientos de KB) y se reusa entre documentos.
pw.ThemeData? _temaCacheado;

Future<pw.ThemeData> obtenerTemaImpresion() async {
  final cacheado = _temaCacheado;
  if (cacheado != null) return cacheado;
  final regular = await PdfGoogleFonts.openSansRegular();
  final negrita = await PdfGoogleFonts.openSansBold();
  final italica = await PdfGoogleFonts.openSansItalic();
  final tema = pw.ThemeData.withFont(base: regular, bold: negrita, italic: italica);
  _temaCacheado = tema;
  return tema;
}
