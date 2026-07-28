import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'traslado_model.dart';
import '../../../core/utils/pdf_tema.dart';
import '../../negocio/data/negocio_model.dart';

/// Comprobante de traslado, calcado del ticket térmico del sistema viejo
/// (frmTraslado.RenderTrasladoTicket / frmDetalleTraslado.RenderTraslado):
/// mismos campos, mismo orden, con las dos líneas de firma al final. A
/// pedido explícito: letra más grande que el ticket de venta (acá no hay
/// que meter mucho detalle de precios en poco espacio) y sin límite de
/// líneas en ningún texto -MultiPage se encarga de seguir en la próxima
/// página si hace falta, así que un traslado nunca queda cortado a la mitad
/// sin importar cuántos productos u observaciones tenga.
class TrasladoExportService {
  // [forzarCopia] es para cuando se reimprime desde el Reporte de Traslados
  // (siempre como "COPIA", una sola hoja, igual que ImprimirTrasladoCopia()
  // en el sistema viejo). Si se deja en null, es el comportamiento de
  // siempre al registrar: ORIGINAL y COPIA, las dos, igual que Ventas.
  Future<Uint8List> generarPdfTraslado(
    TrasladoModel traslado,
    NegocioModel negocio, {
    bool? forzarCopia,
    required Map<String, String> codigosPorProducto,
    PdfPageFormat? formatoImpresora,
  }) async {
    final tema = await obtenerTemaImpresion();
    final doc = pw.Document(theme: tema);
    // Sin logo en el traslado (a pedido explícito) — el sistema viejo
    // tampoco lo imprime en su ticket de traslado (solo en el de venta).
    const logo = null;
    // Preferí el ancho que reportó el driver de la impresora si parece
    // válido; si no, el que el usuario configuró a mano en Negocio (no un
    // 80mm fijo a ciegas: el driver de Windows no siempre lo reporta bien,
    // ver NegocioModel.anchoTicketMm).
    final anchoMm = _anchoValidoDesdeFormato(formatoImpresora) ?? negocio.anchoTicketMm;

    if (forzarCopia != null) {
      doc.addPage(_construirPagina(traslado, negocio, logo, esCopia: forzarCopia, codigosPorProducto: codigosPorProducto, anchoMm: anchoMm));
      return doc.save();
    }

    doc.addPage(_construirPagina(traslado, negocio, logo, esCopia: false, codigosPorProducto: codigosPorProducto, anchoMm: anchoMm));
    doc.addPage(_construirPagina(traslado, negocio, logo, esCopia: true, codigosPorProducto: codigosPorProducto, anchoMm: anchoMm));
    return doc.save();
  }

  double? _anchoValidoDesdeFormato(PdfPageFormat? formato) {
    if (formato == null) return null;
    final anchoMm = formato.width / PdfPageFormat.mm;
    if (anchoMm < 40 || anchoMm > 120) return null;
    return anchoMm;
  }

  // pw.MultiPage (no pw.Page con alto "infinito"): con altura infinita, la
  // vista previa se ve bien porque el paquete mide el contenido real antes
  // de mostrarlo, pero al imprimir directo (sin pasar por la vista previa)
  // algunos drivers de impresora en Windows no manejan bien una altura
  // infinita y cortan el ticket a la mitad -mismo motivo por el que el
  // ticket de venta usa MultiPage, ver venta_export_service.dart-. Con
  // MultiPage, si el contenido no entra en una página sigue en la próxima
  // automáticamente: el traslado nunca queda cortado, sea cual sea su
  // largo.
  pw.Page _construirPagina(
    TrasladoModel t,
    NegocioModel negocio,
    pw.MemoryImage? logo, {
    required bool esCopia,
    required Map<String, String> codigosPorProducto,
    double? anchoMm,
  }) {
    final formatoFecha = DateFormat('dd/MM/yyyy HH:mm');
    // Letra clara y grande a propósito (más que el ticket de venta, que
    // tiene que meter mucho detalle de precios en poco espacio): acá el
    // objetivo es que se lea bien de un vistazo en el andén de carga.
    const fTitulo = 13.0;
    const fNormal = 10.5;
    const fChica = 9.0;

    // Mismo ajuste de margen que en el ticket de venta: en el .exe de
    // Windows, imprimiendo nativo, el controlador recorta un área imprimible
    // más angosta que los 80mm declarados si el margen es muy chico.
    final margenMm = (!kIsWeb && Platform.isWindows) ? 9.0 : 5.0;
    final anchoPaginaMm = anchoMm ?? 80.0;
    final alturaMm = _estimarAlturaMm(t, negocio, tieneLogo: logo != null);

    return pw.MultiPage(
      pageFormat: PdfPageFormat(anchoPaginaMm * PdfPageFormat.mm, alturaMm * PdfPageFormat.mm, marginAll: margenMm * PdfPageFormat.mm),
      build: (context) {
        return [
          pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null) pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4), child: pw.Image(logo, width: 130))),
            // ORIGINAL/COPIA en la MISMA línea que el nombre del negocio
            // (no arriba, aparte) — así sale en el sistema viejo. FittedBox
            // en vez de un Text suelto: si el nombre del negocio no entra
            // en una sola línea compartiendo el ancho con "ORIGINAL"/"COPIA",
            // se achica en vez de pasar a una segunda línea.
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  child: pw.FittedBox(
                    fit: pw.BoxFit.scaleDown,
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(
                      negocio.nombre.isEmpty ? 'MI NEGOCIO' : negocio.nombre.toUpperCase(),
                      maxLines: 1,
                      style: pw.TextStyle(fontSize: fTitulo, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.Text(esCopia ? 'COPIA' : 'ORIGINAL', style: pw.TextStyle(fontSize: fNormal, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.Center(child: pw.Text('TRASLADO', style: pw.TextStyle(fontSize: fTitulo, fontWeight: pw.FontWeight.bold))),
            _separador(),
            _fila('Nº:', t.numero, fNormal),
            _fila('Fecha:', t.fecha != null ? formatoFecha.format(t.fecha!) : '-', fNormal),
            _fila('Estado:', t.estado.toUpperCase(), fNormal),
            _fila('Sucursal origen: ', t.nombreSucursalOrigen, fNormal),
            _fila('Sucursal destino:', t.nombreSucursalDestino, fNormal),
            _fila('Usuario crea:  ', t.usuarioCrea.isEmpty ? '-' : t.usuarioCrea, fNormal),
            _fila('Usuario recibe:', t.usuarioRecibe.isEmpty ? '-' : t.usuarioRecibe, fNormal),
            _separador(),
            // Columnas separadas de verdad (no un solo texto combinado):
            // CÓDIGO angosto a la izquierda, DESCRIPCIÓN se lleva el resto
            // del ancho, CANT a la derecha — mismo layout que cada línea de
            // producto de abajo, para que quede alineado.
            pw.Row(
              children: [
                pw.SizedBox(width: 46, child: pw.Text('CÓDIGO', style: pw.TextStyle(fontSize: fChica, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(width: 6),
                pw.Expanded(child: pw.Text('DESCRIPCIÓN', style: pw.TextStyle(fontSize: fChica, fontWeight: pw.FontWeight.bold))),
                pw.Text('CANT', style: pw.TextStyle(fontSize: fChica, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            _separador(),
            ...t.detalle.map((item) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 5),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Código sin límite de líneas: por largo que sea,
                          // se envuelve dentro de su columna, nunca se corta
                          // ni se pega con la descripción de al lado.
                          pw.SizedBox(
                            width: 46,
                            child: pw.Text(codigosPorProducto[item.idProducto] ?? '', style: pw.TextStyle(fontSize: fNormal)),
                          ),
                          pw.SizedBox(width: 6),
                          // Nombre sin límite de líneas tampoco: se envuelve,
                          // nunca se recorta ni se superpone con CANT.
                          pw.Expanded(
                            child: pw.Text(item.nombreProducto, style: pw.TextStyle(fontSize: fNormal)),
                          ),
                          pw.SizedBox(width: 6),
                          pw.Text(_formatoCantidad(item.cantidad), style: pw.TextStyle(fontSize: fNormal, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      // Ubicación (bodega/estante): Producto.Descripcion en
                      // el momento de agregarlo al traslado. Se imprime
                      // SIEMPRE (con "-" si no la trae) para que nunca
                      // parezca que "falta" el renglón — y en negro sólido,
                      // no gris: una impresora térmica no maneja grises de
                      // verdad, los dithera y salen borrosos/desvanecidos en
                      // papel real (aunque en pantalla se vean bien).
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 52, top: 1),
                        child: pw.Text(
                          'Ubicación: ${item.ubicacion.trim().isEmpty ? '-' : item.ubicacion}',
                          style: pw.TextStyle(fontSize: fChica, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                )),
            _separador(),
            if (t.observaciones.isNotEmpty) ...[
              pw.Text('OBSERVACIONES:', style: pw.TextStyle(fontSize: fChica, fontWeight: pw.FontWeight.bold)),
              pw.Text(t.observaciones, style: pw.TextStyle(fontSize: fNormal)),
              _separador(),
            ],
            pw.SizedBox(height: 20),
            _lineaFirma('Entrega Origen', fNormal),
            pw.SizedBox(height: 16),
            _lineaFirma('Recibe Destino', fNormal),
            _separador(),
            pw.Center(child: pw.Text('Documento generado por el sistema', style: pw.TextStyle(fontSize: fChica))),
          ],
          ),
        ];
      },
    );
  }

  // Igual que en el ticket de venta: se estima cuánto va a ocupar el
  // contenido real para que el rollo térmico no salga con un espacio en
  // blanco larguísimo al final ni tan corto que MultiPage tenga que partir
  // el ticket en más de una página. El número base ya incluye margen de
  // sobra generoso.
  // OJO: este número se quedó corto una vez ya (el traslado se partía en 2
  // páginas con un solo producto) porque la letra acá es más grande que la
  // del ticket de venta y no se había recalculado la base para eso. Bloque
  // fijo real que SIEMPRE se imprime, con su alto aproximado a fNormal
  // (10.5pt): encabezado + "TRASLADO" (2 líneas ~8mm c/u), 4 separadores de
  // sección (~11mm c/u), 7 líneas de datos (Nº/Fecha/Estado/origen/destino/
  // usuario crea/usuario recibe, ~7mm c/u), encabezado de tabla (~8mm), las
  // dos firmas con su espaciado (~35mm c/u entre el SizedBox y el texto) y
  // el pie de página (~8mm). Mejor que sobre papel en blanco de más a que
  // el ticket quede cortado a la mitad.
  double _estimarAlturaMm(TrasladoModel t, NegocioModel negocio, {required bool tieneLogo}) {
    double alto = 16.0 // encabezado + "TRASLADO"
        + 44.0 // 4 separadores de sección fijos
        + 49.0 // 7 líneas de datos
        + 8.0 // encabezado de tabla CÓDIGO/DESCRIPCIÓN/CANT
        + 70.0 // las dos firmas (SizedBox + línea + texto) + separador final
        + 20.0; // pie de página + colchón de seguridad
    if (tieneLogo) alto += 24.0;
    if (t.observaciones.isNotEmpty) alto += 16.0 + (t.observaciones.length / 35).ceil() * 6.0;
    // Cada producto: código + nombre (puede partirse en varias líneas, la
    // columna de nombre es más angosta ahora que el código tiene su propia
    // columna) + la línea de Ubicación si la trae. Nombres en MAYÚSCULA
    // (como salen casi todos los productos migrados) pesan más por
    // carácter que el promedio, así que se estima con menos caracteres por
    // línea de los que en teoría entrarían -mejor sobrestimar líneas que
    // quedarse corto y que el ticket salga cortado, que es justo el
    // problema que este cálculo existe para evitar.
    for (final item in t.detalle) {
      alto += 13.0 + (item.nombreProducto.length / 15).ceil() * 6.5;
      if (item.ubicacion.trim().isNotEmpty) alto += 6.0;
    }
    return alto;
  }

  pw.Widget _fila(String etiqueta, String valor, double tamano) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1.5),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(text: '$etiqueta ', style: pw.TextStyle(fontSize: tamano, fontWeight: pw.FontWeight.bold)),
            pw.TextSpan(text: valor, style: pw.TextStyle(fontSize: tamano)),
          ],
        ),
      ),
    );
  }

  pw.Widget _lineaFirma(String etiqueta, double tamano) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(width: double.infinity, height: 1, color: PdfColor.fromInt(0xFF1A1A1A)),
        pw.SizedBox(height: 3),
        pw.Text(etiqueta, style: pw.TextStyle(fontSize: tamano)),
      ],
    );
  }

  pw.Widget _separador() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Container(height: 1, color: PdfColor.fromInt(0xFFBBBBBB)),
    );
  }

  String _formatoCantidad(double cantidad) {
    if (cantidad == cantidad.roundToDouble()) return cantidad.toInt().toString();
    return cantidad.toStringAsFixed(2);
  }
}
