import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:printing/printing.dart';
import '../../negocio/data/negocio_model.dart';
import '../../../core/services/impresora_usb_windows_service.dart';
import 'traslado_export_service.dart';
import 'traslado_model.dart';
import 'traslado_ticket_escpos_service.dart';

/// Imprime automáticamente, sin ningún diálogo ni confirmación, un traslado
/// que llegó como "solicitud de impresión en vivo" desde el celular/web
/// móvil (ver TrasladoRepository.obtenerTrasladosConSolicitudImpresionEnVivo).
/// Mismo criterio que ImpresionEnVivoService (ventas): solo tiene sentido en
/// la PC principal, en modo escritorio nativo.
class ImpresionEnVivoTrasladoService {
  final _servicioExport = TrasladoExportService();
  final _servicioTicketEscPos = TrasladoTicketEscPosService();

  /// Devuelve true si logró imprimir.
  Future<bool> imprimirSilencioso(
    TrasladoModel traslado,
    NegocioModel negocio,
    Map<String, String> codigosPorProducto, {
    bool? forzarCopia,
  }) async {
    if (negocio.impresoraTermicaUrl.isEmpty) return false;
    // En Windows se manda el ticket como ESC/POS crudo por USB en vez de
    // como PDF (ver el mismo cambio en venta_export_service.dart / Super
    // Color): el driver de esta impresora tiene un tope de tamaño de página
    // fijo que recorta o reescala traslados largos sin importar la altura
    // del PDF.
    if (!kIsWeb && Platform.isWindows) {
      try {
        final bytes = await _servicioTicketEscPos.generarTicket(traslado, negocio, forzarCopia: forzarCopia, codigosPorProducto: codigosPorProducto);
        return ImpresoraUsbWindowsService().imprimir(nombreImpresora: negocio.impresoraTermicaNombre, bytes: bytes);
      } catch (_) {
        return false;
      }
    }
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
