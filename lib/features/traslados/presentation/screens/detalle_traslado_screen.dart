import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../data/traslado_export_service.dart';
import '../../data/traslado_model.dart';
import '../../providers/traslados_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../negocio/providers/negocio_provider.dart';
import '../../../productos/providers/productos_provider.dart';
import '../../../../core/widgets/pdf_preview_dialog.dart';

/// Pantalla de consulta de un traslado ya registrado: buscá por número (o
/// abrila directo desde el Reporte de Traslados pasando [trasladoIdInicial])
/// para ver el detalle completo, reimprimir, o cambiarle el estado — mismo
/// patrón que Detalle de Venta/Compra.
class DetalleTrasladoScreen extends ConsumerStatefulWidget {
  final String? trasladoIdInicial;
  final String? numeroInicial;

  /// true cuando se abre como modal (push encima de otra pantalla, ej. desde
  /// una fila del Reporte de Traslados): muestra su propio Scaffold y flecha
  /// de volver. false cuando se abre como pestaña del menú (Traslados > Ver
  /// Detalle): se embebe como las demás pantallas.
  final bool esDialogo;

  const DetalleTrasladoScreen({super.key, this.trasladoIdInicial, this.numeroInicial, this.esDialogo = true});

  @override
  ConsumerState<DetalleTrasladoScreen> createState() => _DetalleTrasladoScreenState();
}

class _DetalleTrasladoScreenState extends ConsumerState<DetalleTrasladoScreen> {
  final _busquedaController = TextEditingController();
  final _servicioExport = TrasladoExportService();
  TrasladoModel? _traslado;
  bool _cargando = false;
  bool _actuando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.trasladoIdInicial != null) {
      _buscarPorId(widget.trasladoIdInicial!);
    } else if (widget.numeroInicial != null) {
      _busquedaController.text = widget.numeroInicial!;
      _buscarPorNumero();
    }
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _buscarPorId(String id) async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final traslado = await ref.read(trasladoRepositoryProvider).obtenerPorId(id);
      if (!mounted) return;
      if (traslado == null) {
        setState(() => _error = 'No se encontró el traslado');
      } else {
        _busquedaController.text = traslado.numero;
        setState(() => _traslado = traslado);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error al buscar: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _buscarPorNumero() async {
    final texto = _busquedaController.text.trim();
    if (texto.isEmpty) {
      setState(() => _error = 'Ingresá un número de traslado');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
      _traslado = null;
    });
    try {
      final traslado = await ref.read(trasladoRepositoryProvider).obtenerPorNumero(texto);
      if (!mounted) return;
      if (traslado == null) {
        setState(() => _error = 'No se encontró ningún traslado con ese número');
      } else {
        setState(() => _traslado = traslado);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error al buscar: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _limpiar() {
    _busquedaController.clear();
    setState(() {
      _traslado = null;
      _error = null;
    });
  }

  Future<bool> _confirmar(String titulo, String mensaje) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(titulo, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(mensaje, style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancelar', style: GoogleFonts.poppins())),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D2B4E)),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Confirmar', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
    return confirmar ?? false;
  }

  Future<void> _enviar() async {
    final t = _traslado;
    if (t == null) return;
    if (!await _confirmar('Marcar como Enviado', '¿Confirmás que el traslado ${t.numero} salió de ${t.nombreSucursalOrigen}?')) return;
    setState(() => _actuando = true);
    try {
      await ref.read(trasladoRepositoryProvider).enviar(t.id);
      if (mounted) await _buscarPorId(t.id);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _actuando = false);
    }
  }

  Future<void> _recepcionar() async {
    final t = _traslado;
    if (t == null) return;
    if (!await _confirmar('Confirmar recepción', '¿Confirmás que el traslado ${t.numero} fue RECIBIDO en ${t.nombreSucursalDestino}?')) return;
    setState(() => _actuando = true);
    try {
      final usuario = ref.read(authProvider).usuario?.nombreCompleto ?? '';
      await ref.read(trasladoRepositoryProvider).recepcionar(t.id, usuarioRecibe: usuario);
      if (mounted) await _buscarPorId(t.id);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _actuando = false);
    }
  }

  Future<void> _anular() async {
    final t = _traslado;
    if (t == null) return;
    if (!await _confirmar('Anular traslado', '¿Seguro que querés anular el traslado ${t.numero}? Esta acción no se puede deshacer.')) return;
    setState(() => _actuando = true);
    try {
      await ref.read(trasladoRepositoryProvider).anular(t.id);
      if (mounted) await _buscarPorId(t.id);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _actuando = false);
    }
  }

  // Reimprimir desde acá siempre sale como "COPIA" (una sola hoja), igual
  // que ImprimirTrasladoCopia() en el sistema viejo.
  Future<void> _reimprimir() async {
    final t = _traslado;
    if (t == null) return;
    final negocio = await ref.read(negocioRepositoryProvider).obtenerNegocioActual();
    if (!mounted) return;
    final productos = ref.read(productosStreamProvider).value ?? [];
    final codigos = {for (final p in productos) p.id: p.codigo};
    final impresora = negocio.impresoraTermicaUrl.isEmpty ? null : Printer(url: negocio.impresoraTermicaUrl, name: negocio.impresoraTermicaNombre);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => PdfPreviewDialog(
        titulo: 'Traslado ${t.numero} (copia)',
        nombreArchivo: 'traslado_${t.numero}_copia.pdf',
        generarPdf: () => _servicioExport.generarPdfTraslado(t, negocio, forzarCopia: true, codigosPorProducto: codigos),
        generarPdfConFormato: (formato) => _servicioExport.generarPdfTraslado(t, negocio, forzarCopia: true, codigosPorProducto: codigos, formatoImpresora: formato),
        impresora: impresora,
      ),
    );
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'Entregado':
        return const Color(0xFF16A34A);
      case 'Enviado':
        return const Color(0xFF3B82F6);
      case 'Anulado':
        return Colors.grey.shade500;
      default:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tamano = MediaQuery.of(context).size;
    final esMovil = tamano.width < 760;

    final contenido = Padding(
      padding: EdgeInsets.all(esMovil ? 14 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.esDialogo
              ? Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                    const SizedBox(width: 6),
                    Text('Detalle de Traslado', style: GoogleFonts.poppins(fontSize: esMovil ? 18 : 21, fontWeight: FontWeight.w700)),
                  ],
                )
              : Text('Detalle de Traslado', style: GoogleFonts.poppins(fontSize: esMovil ? 19 : 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: esMovil ? tamano.width - 28 : 320,
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFB6BCC7))),
                  child: TextField(
                    controller: _busquedaController,
                    autofocus: widget.trasladoIdInicial == null,
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Número de traslado...',
                      hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _buscarPorNumero(),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _cargando ? null : _buscarPorNumero,
                icon: const Icon(Icons.search, size: 18),
                label: Text('Buscar', style: GoogleFonts.poppins(fontSize: 13)),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1A1A1A), side: const BorderSide(color: Color(0xFFB6BCC7)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
              OutlinedButton.icon(
                onPressed: _cargando ? null : _limpiar,
                icon: const Icon(Icons.close, size: 18),
                label: Text('Limpiar', style: GoogleFonts.poppins(fontSize: 13)),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1A1A1A), side: const BorderSide(color: Color(0xFFB6BCC7)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D2B4E)))
                : _error != null
                    ? Center(child: Text(_error!, style: GoogleFonts.poppins(color: Colors.red)))
                    : _traslado == null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.sync_alt_outlined, size: 56, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text('Buscá un traslado por su número', style: GoogleFonts.poppins(color: Colors.grey.shade500)),
                              ],
                            ),
                          )
                        : SingleChildScrollView(child: _detalle(_traslado!, esMovil)),
          ),
        ],
      ),
    );

    if (widget.esDialogo) {
      return Scaffold(
        backgroundColor: const Color(0xFFF2F3F7),
        body: SafeArea(child: contenido),
      );
    }
    return Container(color: const Color(0xFFF2F3F7), child: contenido);
  }

  Widget _detalle(TrasladoModel t, bool esMovil) {
    final formatoFecha = DateFormat('dd/MM/yyyy HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tarjeta(
          child: Wrap(
            spacing: 24,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _campoInfo('Número', t.numero),
              _campoInfo('Fecha', t.fecha != null ? formatoFecha.format(t.fecha!) : '-'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: _colorEstado(t.estado).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Text(t.estado, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700, color: _colorEstado(t.estado))),
              ),
              _campoInfo('Sucursal origen', t.nombreSucursalOrigen),
              _campoInfo('Sucursal destino', t.nombreSucursalDestino),
              _campoInfo('Usuario crea', t.usuarioCrea.isEmpty ? '-' : t.usuarioCrea),
              _campoInfo('Usuario recibe', t.usuarioRecibe.isEmpty ? '-' : t.usuarioRecibe),
              if (t.fechaRecepcion != null) _campoInfo('Fecha recepción', formatoFecha.format(t.fechaRecepcion!)),
              if (t.observaciones.isNotEmpty) _campoInfo('Observaciones', t.observaciones),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Productos', style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        _tarjeta(child: esMovil ? _tarjetasItems(t) : _tablaItems(t)),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: _actuando ? null : _reimprimir,
              icon: const Icon(Icons.print_outlined, size: 18),
              label: Text('Reimprimir (copia)', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF0D2B4E), side: const BorderSide(color: Color(0xFF0D2B4E)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
            if (t.estado == 'Pendiente')
              FilledButton.icon(
                onPressed: _actuando ? null : _enviar,
                icon: const Icon(Icons.local_shipping_outlined, size: 18),
                label: Text('Marcar Enviado', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            if (t.estado == 'Enviado')
              FilledButton.icon(
                onPressed: _actuando ? null : _recepcionar,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: Text('Confirmar Recepción', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            if (t.estado == 'Pendiente' || t.estado == 'Enviado')
              OutlinedButton.icon(
                onPressed: _actuando ? null : _anular,
                icon: const Icon(Icons.block_outlined, size: 18),
                label: Text('Anular', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade600, side: BorderSide(color: Colors.red.shade300), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
          ],
        ),
      ],
    );
  }

  Widget _tarjeta({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC7CBD3)),
      ),
      child: child,
    );
  }

  Widget _campoInfo(String etiqueta, String valor) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.4)),
          const SizedBox(height: 3),
          // Sin límite de líneas: si el nombre de la sucursal o la
          // observación es larga, se envuelve, nunca se recorta.
          Text(valor, style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF1A1A1A))),
        ],
      ),
    );
  }

  Widget _tablaItems(TrasladoModel t) {
    final estiloEncabezado = GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.grey.shade600);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(flex: 6, child: Text('Producto', style: estiloEncabezado)),
            Expanded(flex: 2, child: Text('Cant.', textAlign: TextAlign.right, style: estiloEncabezado)),
          ],
        ),
        Divider(height: 18, color: Colors.grey.shade300),
        for (final item in t.detalle) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item.nombreProducto, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      if (item.ubicacion.trim().isNotEmpty)
                        Text('Ubicación: ${item.ubicacion}', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                Expanded(flex: 2, child: Text(_formatoCantidad(item.cantidad), textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700))),
              ],
            ),
          ),
          if (item != t.detalle.last) Divider(height: 1, color: Colors.grey.shade200),
        ],
      ],
    );
  }

  Widget _tarjetasItems(TrasladoModel t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in t.detalle) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.nombreProducto, style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      if (item.ubicacion.trim().isNotEmpty)
                        Text('Ubicación: ${item.ubicacion}', style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                Text(_formatoCantidad(item.cantidad), style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (item != t.detalle.last) Divider(height: 1, color: Colors.grey.shade200),
        ],
      ],
    );
  }

  String _formatoCantidad(double cantidad) {
    if (cantidad == cantidad.roundToDouble()) return cantidad.toInt().toString();
    return cantidad.toStringAsFixed(2);
  }
}
