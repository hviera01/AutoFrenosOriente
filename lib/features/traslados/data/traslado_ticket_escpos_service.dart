import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'traslado_model.dart';
import '../../negocio/data/negocio_model.dart';
import '../../../core/utils/texto_utils.dart';

/// Genera el mismo contenido del comprobante de traslado de
/// `TrasladoExportService.generarPdfTraslado` (mismos campos, mismo orden)
/// pero como comandos ESC/POS crudos, para mandarlos directo a la impresora
/// -por USB en Windows (ImpresoraUsbWindowsService) o por red/celular
/// (ImpresoraRedService)- en vez de un PDF: el driver de esta impresora
/// térmica tiene un tamaño de página máximo fijo que recorta o reescala
/// cualquier traslado más largo que eso, sin importar qué altura declare el
/// PDF (ver el comentario grande en traslado_export_service.dart). El
/// ESC/POS no tiene ese concepto: imprime seguido hasta el corte.
class TrasladoTicketEscPosService {
  /// [forzarCopia] mismo significado que en
  /// `TrasladoExportService.generarPdfTraslado`: null (recién registrado)
  /// imprime ORIGINAL y COPIA, una detrás de otra (cada una con su propio
  /// corte de papel); true/false fuerza una sola copia -para reimprimir
  /// desde el Reporte de Traslados-.
  Future<List<int>> generarTicket(
    TrasladoModel traslado,
    NegocioModel negocio, {
    bool? forzarCopia,
    required Map<String, String> codigosPorProducto,
  }) async {
    final perfil = await CapabilityProfile.load();
    final generador = Generator(PaperSize.mm80, perfil);

    List<int> bytes = [];
    bytes += generador.reset();
    bytes += _construirTicket(generador, traslado, negocio, codigosPorProducto, esCopia: forzarCopia ?? false);
    if (forzarCopia == null) {
      bytes += _construirTicket(generador, traslado, negocio, codigosPorProducto, esCopia: true);
    }
    return bytes;
  }

  // Muchas impresoras térmicas no tienen bien configurada la página de
  // códigos para tildes/eñes y las imprimen mal (un carácter random, o
  // cortan la línea ahí) — por eso todo el texto pasa por quitarTildes.
  List<int> _texto(Generator g, String texto, {PosStyles styles = const PosStyles()}) {
    return g.text(quitarTildes(texto), styles: styles);
  }

  PosColumn _columna(String texto, {required int width, PosStyles styles = const PosStyles()}) {
    return PosColumn(text: quitarTildes(texto), width: width, styles: styles);
  }

  List<int> _construirTicket(
    Generator generador,
    TrasladoModel t,
    NegocioModel negocio,
    Map<String, String> codigosPorProducto, {
    required bool esCopia,
  }) {
    final formatoFecha = DateFormat('dd/MM/yyyy HH:mm');
    List<int> bytes = [];

    bytes += generador.row([
      _columna(negocio.nombre.isEmpty ? 'MI NEGOCIO' : negocio.nombre.toUpperCase(), width: 8, styles: const PosStyles(bold: true)),
      _columna(esCopia ? 'COPIA' : 'ORIGINAL', width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);
    bytes += _texto(generador, 'TRASLADO', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
    bytes += generador.hr();

    bytes += _texto(generador, 'No: ${t.numero}');
    bytes += _texto(generador, 'Fecha: ${t.fecha != null ? formatoFecha.format(t.fecha!) : '-'}');
    bytes += _texto(generador, 'Estado: ${t.estado.toUpperCase()}');
    bytes += _texto(generador, 'Sucursal origen: ${t.nombreSucursalOrigen}');
    bytes += _texto(generador, 'Sucursal destino: ${t.nombreSucursalDestino}');
    bytes += _texto(generador, 'Usuario crea: ${t.usuarioCrea.isEmpty ? '-' : t.usuarioCrea}');
    bytes += _texto(generador, 'Usuario recibe: ${t.usuarioRecibe.isEmpty ? '-' : t.usuarioRecibe}');
    bytes += generador.hr();

    // Columna 4 vacía entre CODIGO y DESCRIPCION a propósito: sin ese
    // "colchón" quedaban pegados (el ancho que le sobra a un código corto
    // no alcanza para que se note el espacio antes de la descripción).
    bytes += generador.row([
      _columna('CODIGO', width: 3, styles: const PosStyles(bold: true)),
      _columna('', width: 1),
      _columna('DESCRIPCION', width: 5, styles: const PosStyles(bold: true)),
      _columna('CANT', width: 3, styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);
    bytes += generador.hr();

    for (final item in t.detalle) {
      bytes += generador.row([
        _columna(codigosPorProducto[item.idProducto] ?? '', width: 3),
        _columna('', width: 1),
        _columna(item.nombreProducto, width: 5),
        _columna(_formatoCantidad(item.cantidad), width: 3, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
      bytes += _texto(generador, 'Ubicacion: ${item.ubicacion.trim().isEmpty ? '-' : item.ubicacion}', styles: const PosStyles(bold: true));
      // Más espacio antes del siguiente producto: antes quedaban todos los
      // renglones pegados uno con otro ("una sola choricera").
      bytes += generador.emptyLines(2);
    }
    bytes += generador.hr();

    if (t.observaciones.isNotEmpty) {
      bytes += _texto(generador, 'OBSERVACIONES:', styles: const PosStyles(bold: true));
      bytes += _texto(generador, t.observaciones);
      bytes += generador.hr();
    }

    bytes += generador.emptyLines(2);
    bytes += _texto(generador, '________________________________');
    bytes += _texto(generador, 'Entrega Origen');
    bytes += generador.emptyLines(2);
    bytes += _texto(generador, '________________________________');
    bytes += _texto(generador, 'Recibe Destino');
    bytes += generador.hr();
    bytes += _texto(generador, 'Documento generado por el sistema', styles: const PosStyles(align: PosAlign.center));
    bytes += generador.cut();

    return bytes;
  }

  String _formatoCantidad(double cantidad) {
    if (cantidad == cantidad.roundToDouble()) return cantidad.toInt().toString();
    return cantidad.toStringAsFixed(2);
  }
}
