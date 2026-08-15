import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../services/tipografia_service.dart';
import '../services/impresora_usb_windows_service.dart';

class PdfPreviewDialog extends StatefulWidget {
  final String titulo;
  final Future<Uint8List> Function() generarPdf;
  // Opcional: para imprimir directo en Windows, algunos PDF (el ticket
  // térmico) necesitan saber el formato real que reporta la impresora
  // seleccionada para no salir desalineados (ver venta_export_service.dart).
  // Si no se manda, se usa generarPdf() igual que siempre.
  final Future<Uint8List> Function(PdfPageFormat formato)? generarPdfConFormato;
  final String nombreArchivo;
  final Printer? impresora;
  // Opcionales: cuando se manda esto (y [nombreImpresoraWindows]), imprimir
  // en Windows NO pasa por el PDF -algunos drivers de impresora térmica
  // tienen un tamaño de página máximo fijo (ver traslado_export_service.dart)
  // y recortan o reescalan cualquier documento más largo que eso, sin
  // importar qué le pidamos al PDF-. En vez de eso se mandan directo los
  // bytes ESC/POS crudos por USB (ImpresoraUsbWindowsService), el mismo
  // mecanismo que ya usa la impresión por red/celular y que no tiene ese
  // límite. Si no se manda (el resto de los documentos) sigue exactamente
  // igual que antes.
  final Future<List<int>> Function()? generarTicketEscPos;
  final String? nombreImpresoraWindows;
  // Widget opcional que reproduce en pantalla, con widgets normales (no un
  // PDF), el mismo contenido que imprime [generarTicketEscPos]. En Windows,
  // cuando se va a usar esa vía, la vista previa en PDF ya no representa lo
  // que realmente se manda a imprimir, así que se muestra esto en su lugar.
  final Widget Function()? vistaPreviaTicket;

  const PdfPreviewDialog({
    super.key,
    required this.titulo,
    required this.generarPdf,
    this.generarPdfConFormato,
    required this.nombreArchivo,
    this.impresora,
    this.generarTicketEscPos,
    this.nombreImpresoraWindows,
    this.vistaPreviaTicket,
  });

  @override
  State<PdfPreviewDialog> createState() => _PdfPreviewDialogState();
}

class _PdfPreviewDialogState extends State<PdfPreviewDialog> {
  bool _imprimiendo = false;

  bool get _usaEscPosEnWindows =>
      !kIsWeb && Platform.isWindows && widget.generarTicketEscPos != null && (widget.nombreImpresoraWindows?.isNotEmpty ?? false);

  Future<void> _imprimirDirecto() async {
    final impresora = widget.impresora;
    if (impresora == null) return;
    setState(() => _imprimiendo = true);
    try {
      if (_usaEscPosEnWindows) {
        final bytes = await widget.generarTicketEscPos!();
        final ok = ImpresoraUsbWindowsService().imprimir(nombreImpresora: widget.nombreImpresoraWindows!, bytes: bytes);
        if (!ok) throw Exception('No se pudo escribir en la impresora');
        return;
      }
      final generarConFormato = widget.generarPdfConFormato;
      await Printing.directPrintPdf(
        printer: impresora,
        onLayout: generarConFormato != null ? (format) => generarConFormato(format) : (format) => widget.generarPdf(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo imprimir en la impresora configurada')));
      }
    } finally {
      if (mounted) setState(() => _imprimiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tamano = MediaQuery.of(context).size;
    final anchoDialog = tamano.width < 760 ? tamano.width - 24 : 640.0;
    final altoDialog = tamano.height < 700 ? tamano.height - 60 : 720.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        width: anchoDialog,
        height: kIsWeb ? null : altoDialog,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: kIsWeb ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Row(
              children: [
                Expanded(child: Text(widget.titulo, style: appFont(fontSize: 15, fontWeight: FontWeight.w700))),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
              ],
            ),
            if (widget.impresora != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _imprimiendo ? null : _imprimirDirecto,
                  icon: _imprimiendo
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.print_outlined, size: 18),
                  label: Text(
                    _imprimiendo ? 'Imprimiendo...' : 'Imprimir en ${widget.impresora!.name}',
                    style: appFont(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D2B4E), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ],
            // Cuando la vista previa de acá abajo es la reproducción del
            // ticket ESC/POS (no el PDF real, ver _vistaPreviaNativa) se
            // pierde el ícono de compartir que traía el visor de PDF nativo,
            // así que se ofrece un botón aparte por si igual se quiere
            // mandar el documento en PDF.
            if (_usaEscPosEnWindows) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final bytes = await widget.generarPdf();
                    await Printing.sharePdf(bytes: bytes, filename: widget.nombreArchivo);
                  },
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: Text('Compartir PDF', style: appFont(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A1A1A),
                    side: const BorderSide(color: Color(0xFFB6BCC7)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            // En la web, la vista previa dentro del diálogo necesita cargar
            // pdf.js desde un CDN externo (unpkg.com) la primera vez, sin
            // límite de tiempo: si esa carga falla o tarda (red restringida,
            // CDN caído), el diálogo queda "cargando" para siempre. Para no
            // depender de eso, en web se ofrece descargar/imprimir directo
            // (no necesita pdf.js) en vez de mostrar la vista previa en pantalla.
            if (kIsWeb) _accionesWeb() else _vistaPreviaNativa(),
          ],
        ),
      ),
    );
  }

  Widget _vistaPreviaNativa() {
    final vistaTicket = widget.vistaPreviaTicket;
    if (_usaEscPosEnWindows && vistaTicket != null) {
      // La vía real de impresión acá es ESC/POS crudo, no el PDF (ver
      // _imprimirDirecto): mostrar el PDF en la vista previa daría una idea
      // equivocada de qué va a salir. En su lugar se muestra una
      // reproducción con widgets normales del mismo contenido/orden que
      // imprime de verdad.
      return Expanded(
        child: Container(
          decoration: BoxDecoration(color: const Color(0xFFF2F3F7), borderRadius: BorderRadius.circular(12)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: vistaTicket()),
          ),
        ),
      );
    }
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: PdfPreview(
          // Si hay generarPdfConFormato, se usa con el [format] real que la
          // vista previa/impresión reporta en vez del genérico de siempre:
          // antes esto ignoraba [format] y llamaba generarPdf() a ciegas,
          // por lo que el botón de imprimir DENTRO de la vista previa nunca
          // se enteraba del ancho real de la impresora térmica elegida.
          build: (format) => widget.generarPdfConFormato != null ? widget.generarPdfConFormato!(format) : widget.generarPdf(),
          pdfFileName: widget.nombreArchivo,
          canChangeOrientation: false,
          canChangePageFormat: false,
          allowPrinting: widget.generarTicketEscPos == null,
          allowSharing: true,
          useActions: true,
        ),
      ),
    );
  }

  Widget _accionesWeb() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.picture_as_pdf_outlined, size: 44, color: Colors.grey.shade400),
        const SizedBox(height: 10),
        Text('El documento está listo', style: appFont(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () async {
              final bytes = await widget.generarPdf();
              await Printing.sharePdf(bytes: bytes, filename: widget.nombreArchivo);
            },
            icon: const Icon(Icons.download_outlined, size: 18),
            label: Text('Descargar PDF', style: appFont(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1A1A1A), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Printing.layoutPdf(onLayout: (format) => widget.generarPdf(), name: widget.nombreArchivo),
            icon: const Icon(Icons.print_outlined, size: 18),
            label: Text('Ver / imprimir', style: appFont(fontSize: 13)),
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1A1A1A), side: const BorderSide(color: Color(0xFFB6BCC7)), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
      ],
    );
  }
}
