import 'package:printing/printing.dart';
import '../../negocio/data/negocio_model.dart';
import 'traslado_export_service.dart';
import 'traslado_model.dart';

/// Imprime automáticamente, sin ningún diálogo ni confirmación, un traslado
/// que llegó como "solicitud de impresión en vivo" desde el celular/web
/// móvil (ver TrasladoRepository.obtenerTrasladosConSolicitudImpresionEnVivo).
/// Mismo criterio que ImpresionEnVivoService (ventas): solo tiene sentido en
/// la PC principal, en modo escritorio nativo.
class ImpresionEnVivoTrasladoService {
  final _servicioExport = TrasladoExportService();

  /// Devuelve true si logró imprimir.
  Future<bool> imprimirSilencioso(
    TrasladoModel traslado,
    NegocioModel negocio,
    Map<String, String> codigosPorProducto, {
    bool? forzarCopia,
  }) async {
    if (negocio.impresoraTermicaUrl.isEmpty) return false;
    try {
      final impresora = Printer(url: negocio.impresoraTermicaUrl, name: negocio.impresoraTermicaNombre);
      await Printing.directPrintPdf(
        printer: impresora,
        onLayout: (formato) => _servicioExport.generarPdfTraslado(traslado, negocio, forzarCopia: forzarCopia, codigosPorProducto: codigosPorProducto, formatoImpresora: formato),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
