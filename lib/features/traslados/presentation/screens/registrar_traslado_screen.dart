import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import '../../data/item_traslado_model.dart';
import '../../data/traslado_export_service.dart';
import '../../data/traslado_model.dart';
import '../../providers/traslados_provider.dart';
import '../../../sucursales/data/sucursal_model.dart';
import '../../../sucursales/providers/sucursales_provider.dart';
import '../../../productos/data/producto_model.dart';
import '../../../productos/providers/productos_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../negocio/providers/negocio_provider.dart';
import '../../../compras/presentation/widgets/buscar_producto_compra_dialog.dart';
import '../../../../core/widgets/pdf_preview_dialog.dart';

/// Registrar Traslado: antes era un diálogo chico centrado; ahora es una
/// pestaña grande como Registrar Venta/Compra, con la tabla de productos
/// ampliable ("Ver más grande") para que nunca quede apretada ni con texto
/// cortado, sin importar cuántos productos tenga el traslado.
class RegistrarTrasladoScreen extends ConsumerStatefulWidget {
  const RegistrarTrasladoScreen({super.key});

  @override
  ConsumerState<RegistrarTrasladoScreen> createState() => _RegistrarTrasladoScreenState();
}

class _RegistrarTrasladoScreenState extends ConsumerState<RegistrarTrasladoScreen> {
  final _observacionesController = TextEditingController();
  final _servicioExport = TrasladoExportService();
  SucursalModel? _origen;
  SucursalModel? _destino;
  List<ItemTrasladoModel> _items = [];
  final Map<int, TextEditingController> _ctrlCantidad = {};
  final Map<int, TextEditingController> _ctrlUbicacion = {};
  bool _guardando = false;
  String? _error;
  // Igual que el sistema viejo (frmTraslado, checkboxes Pendiente/Enviado/
  // Entregado mutuamente excluyentes): al registrar se puede elegir de una
  // vez en qué estado queda el traslado, en cadena (Entregado dispara
  // Enviado y Recepcionar uno detrás del otro). "Entregado" es el default
  // real del sistema viejo (chkEntregado.Checked = true en su Load), pensado
  // para cuando el traslado físico ya se hizo y se está registrando después.
  String _estadoDeseado = 'Entregado';

  @override
  void dispose() {
    _observacionesController.dispose();
    for (final c in _ctrlCantidad.values) {
      c.dispose();
    }
    for (final c in _ctrlUbicacion.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _mostrarError(String mensaje) => setState(() => _error = mensaje);

  Future<void> _agregarProducto() async {
    final producto = await Navigator.of(context).push<ProductoModel>(
      MaterialPageRoute(fullscreenDialog: true, builder: (context) => const BuscarProductoCompraDialog()),
    );
    if (producto == null || !mounted) return;
    if (_items.any((i) => i.idProducto == producto.id)) {
      _mostrarError('Ese producto ya está en el traslado');
      return;
    }
    setState(() {
      _items = [..._items, ItemTrasladoModel(idProducto: producto.id, nombreProducto: producto.nombre, cantidad: 1)];
      _error = null;
    });
  }

  void _quitarItem(int index) {
    _ctrlCantidad.remove(index)?.dispose();
    _ctrlUbicacion.remove(index)?.dispose();
    setState(() => _items = [..._items]..removeAt(index));
  }

  void _actualizarCantidad(int index, String texto) {
    final cantidad = double.tryParse(texto.replaceAll(',', '.'));
    if (cantidad == null || cantidad <= 0) return;
    final nuevos = [..._items];
    nuevos[index] = ItemTrasladoModel(idProducto: nuevos[index].idProducto, nombreProducto: nuevos[index].nombreProducto, cantidad: cantidad, ubicacion: nuevos[index].ubicacion);
    setState(() => _items = nuevos);
  }

  void _actualizarUbicacion(int index, String texto) {
    final nuevos = [..._items];
    nuevos[index] = ItemTrasladoModel(idProducto: nuevos[index].idProducto, nombreProducto: nuevos[index].nombreProducto, cantidad: nuevos[index].cantidad, ubicacion: texto.trim());
    setState(() => _items = nuevos);
  }

  Future<void> _guardar() async {
    if (_origen == null || _destino == null) {
      _mostrarError('Elegí la sucursal origen y destino');
      return;
    }
    if (_origen!.id == _destino!.id) {
      _mostrarError('La sucursal origen y destino no pueden ser la misma');
      return;
    }
    if (_items.isEmpty) {
      _mostrarError('Agregá al menos un producto');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final repo = ref.read(trasladoRepositoryProvider);
      final usuario = ref.read(authProvider).usuario?.nombreCompleto ?? '';
      var traslado = await repo.registrar(
        idSucursalOrigen: _origen!.id,
        nombreSucursalOrigen: _origen!.nombre,
        idSucursalDestino: _destino!.id,
        nombreSucursalDestino: _destino!.nombre,
        observaciones: _observacionesController.text.trim(),
        usuarioCrea: usuario,
        detalle: _items,
      );

      // Encadenado igual que el sistema viejo: "Entregado" dispara Enviar Y
      // Recepcionar uno detrás del otro (mismo usuario que crea, sin pedir
      // cantidades ni un segundo usuario de recepción aparte).
      final quiereEnviado = _estadoDeseado == 'Enviado' || _estadoDeseado == 'Entregado';
      final quiereEntregado = _estadoDeseado == 'Entregado';
      if (quiereEnviado) await repo.enviar(traslado.id);
      if (quiereEntregado) await repo.recepcionar(traslado.id, usuarioRecibe: usuario);
      if ((quiereEnviado || quiereEntregado)) {
        final actualizado = await repo.obtenerPorId(traslado.id);
        if (actualizado != null) traslado = actualizado;
      }
      if (!mounted) return;

      final numero = traslado.numero;
      final deseaImprimir = await _confirmarDialogo(
        'Traslado $numero creado',
        'Traslado $numero creado en estado ${traslado.estado.toUpperCase()}.\n\n¿Desea imprimir el ticket (ORIGINAL y COPIA)?',
      );
      if (deseaImprimir && mounted) await _imprimir(traslado);
      if (!mounted) return;
      _limpiar();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _guardando = false;
      });
    }
  }

  Future<bool> _confirmarDialogo(String titulo, String mensaje) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(titulo, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(mensaje, style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('No', style: GoogleFonts.poppins())),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D2B4E)),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sí, imprimir', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
    return confirmar ?? false;
  }

  void _limpiar() {
    setState(() {
      _origen = null;
      _destino = null;
      _items = [];
      _guardando = false;
      _error = null;
      _estadoDeseado = 'Entregado';
    });
    _observacionesController.clear();
    for (final c in _ctrlCantidad.values) {
      c.dispose();
    }
    _ctrlCantidad.clear();
    for (final c in _ctrlUbicacion.values) {
      c.dispose();
    }
    _ctrlUbicacion.clear();
  }

  Map<String, String> _codigosPorProducto() {
    final productos = ref.read(productosStreamProvider).value ?? [];
    return {for (final p in productos) p.id: p.codigo};
  }

  Future<void> _imprimir(TrasladoModel traslado) async {
    final negocio = await ref.read(negocioRepositoryProvider).obtenerNegocioActual();
    if (!mounted) return;
    final codigos = _codigosPorProducto();
    final impresora = negocio.impresoraTermicaUrl.isEmpty ? null : Printer(url: negocio.impresoraTermicaUrl, name: negocio.impresoraTermicaNombre);
    await showDialog(
      context: context,
      builder: (context) => PdfPreviewDialog(
        titulo: 'Traslado ${traslado.numero}',
        nombreArchivo: 'traslado_${traslado.numero}.pdf',
        generarPdf: () => _servicioExport.generarPdfTraslado(traslado, negocio, codigosPorProducto: codigos),
        generarPdfConFormato: (formato) => _servicioExport.generarPdfTraslado(traslado, negocio, codigosPorProducto: codigos, formatoImpresora: formato),
        impresora: impresora,
      ),
    );
  }

  Future<void> _verMasGrande() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: const Color(0xFFF2F3F7),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0D2B4E),
            title: Text('Productos del traslado', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700)),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: StatefulBuilder(
            builder: (context, setStateDialogo) => Padding(
              padding: const EdgeInsets.all(20),
              child: _tarjetaProductos(grande: true, alturaAcotada: true, alReconstruir: () => setStateDialogo(() {})),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoracion(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFE8EAF0),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  Widget _selectorSucursal({required String label, required SucursalModel? valor, required List<SucursalModel> opciones, required void Function(SucursalModel?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      height: 56,
      decoration: BoxDecoration(color: const Color(0xFFE8EAF0), borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<SucursalModel>(
          isExpanded: true,
          value: valor,
          hint: Text(label, style: GoogleFonts.poppins(fontSize: 13.5, color: Colors.grey.shade600)),
          style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF1A1A1A)),
          items: opciones.map((s) => DropdownMenuItem(value: s, child: Text(s.nombre, style: GoogleFonts.poppins(fontSize: 14)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _tarjeta({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC7CBD3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF2F3F7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final esMovil = constraints.maxWidth < 900;
          final altoTabla = (constraints.maxHeight * 0.5).clamp(320.0, 900.0);
          return SingleChildScrollView(
            padding: EdgeInsets.all(esMovil ? 14 : 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Registrar Traslado', style: GoogleFonts.poppins(fontSize: esMovil ? 19 : 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                const SizedBox(height: 14),
                _tarjetaDatos(esMovil),
                const SizedBox(height: 14),
                esMovil
                    ? _tarjetaProductos(grande: false, alturaAcotada: false, alReconstruir: () => setState(() {}))
                    : SizedBox(height: altoTabla, child: _tarjetaProductos(grande: false, alturaAcotada: true, alReconstruir: () => setState(() {}))),
                const SizedBox(height: 14),
                _tarjetaFooter(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tarjetaDatos(bool esMovil) {
    final sucursalesAsync = ref.watch(sucursalesActivasProvider);
    return _tarjeta(
      child: sucursalesAsync.when(
        data: (sucursales) {
          if (sucursales.length < 2) {
            return Text('Necesitás al menos 2 sucursales activas registradas para hacer un traslado.', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600));
          }
          return Wrap(
            spacing: 14,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: esMovil ? double.infinity : 260,
                child: _selectorSucursal(label: 'Sucursal origen', valor: _origen, opciones: sucursales, onChanged: (v) => setState(() => _origen = v)),
              ),
              Icon(Icons.arrow_forward, color: Colors.grey.shade400),
              SizedBox(
                width: esMovil ? double.infinity : 260,
                child: _selectorSucursal(label: 'Sucursal destino', valor: _destino, opciones: sucursales, onChanged: (v) => setState(() => _destino = v)),
              ),
              SizedBox(
                width: esMovil ? double.infinity : 320,
                child: TextField(controller: _observacionesController, style: GoogleFonts.poppins(fontSize: 13), decoration: _decoracion('Observaciones (opcional)')),
              ),
              SizedBox(width: esMovil ? double.infinity : 420, child: _selectorEstadoInicial()),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0D2B4E))),
        error: (e, st) => Text('Error: $e', style: GoogleFonts.poppins(color: Colors.red)),
      ),
    );
  }

  // Igual que el sistema viejo: al registrar se elige de una vez en qué
  // estado queda el traslado (Pendiente/Enviado/Entregado, mutuamente
  // excluyentes) — "Entregado" viene preseleccionado por defecto.
  Widget _selectorEstadoInicial() {
    Widget opcion(String valor, String etiqueta) {
      final activo = _estadoDeseado == valor;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _estadoDeseado = valor),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(color: activo ? const Color(0xFF0D2B4E) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
            child: Text(etiqueta, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: activo ? Colors.white : const Color(0xFF666A72))),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Queda registrado como', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.3)),
        const SizedBox(height: 4),
        Container(
          height: 46,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: const Color(0xFFE8EAF0), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFB6BCC7))),
          child: Row(
            children: [
              opcion('Pendiente', 'Pendiente'),
              opcion('Enviado', 'Enviado'),
              opcion('Entregado', 'Entregado'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tarjetaProductos({required bool grande, required bool alturaAcotada, required VoidCallback alReconstruir}) {
    return _tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: alturaAcotada ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('Productos', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
              const SizedBox(width: 10),
              Text('(${_items.length})', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500)),
              const Spacer(),
              if (!grande)
                OutlinedButton.icon(
                  onPressed: _verMasGrande,
                  icon: const Icon(Icons.open_in_full, size: 16),
                  label: Text('Ver más grande', style: GoogleFonts.poppins(fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1A1A1A), side: const BorderSide(color: Color(0xFFB6BCC7))),
                ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () async {
                  await _agregarProducto();
                  alReconstruir();
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text('Agregar', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D2B4E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('Sin productos todavía', style: GoogleFonts.poppins(fontSize: 13.5, color: Colors.grey.shade500))),
            )
          else
            // Column sin virtualizar (no ListView): un traslado no tiene la
            // escala de un inventario completo. Cuando la tarjeta tiene alto
            // acotado (escritorio con SizedBox, o la vista "más grande" a
            // pantalla completa) esta lista scrollea sola adentro de la
            // tarjeta; cuando no (celular, adentro del scroll general de la
            // pantalla) es una Column suelta, para no pelearse con
            // restricciones de alto no acotado.
            _construirListaItems(grande: grande, alturaAcotada: alturaAcotada, alReconstruir: alReconstruir),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)),
              child: Text(_error!, style: GoogleFonts.poppins(color: Colors.red.shade700, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _construirListaItems({required bool grande, required bool alturaAcotada, required VoidCallback alReconstruir}) {
    final columna = Column(
      children: [
        for (var index = 0; index < _items.length; index++) ...[
          if (index > 0) Divider(height: 1, color: Colors.grey.shade200),
          Builder(builder: (context) {
            final item = _items[index];
            final ctrl = _ctrlCantidad.putIfAbsent(index, () => TextEditingController(text: item.cantidad.toStringAsFixed(item.cantidad == item.cantidad.roundToDouble() ? 0 : 2)));
            final ctrlUbicacion = _ctrlUbicacion.putIfAbsent(index, () => TextEditingController(text: item.ubicacion));
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Letra clara y sin límite de líneas: por largo que sea
                      // el nombre del producto, nunca se recorta con "...",
                      // solo se envuelve.
                      Expanded(
                        child: Text(item.nombreProducto, style: GoogleFonts.poppins(fontSize: grande ? 16 : 14, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A))),
                      ),
                      SizedBox(
                        width: grande ? 110 : 80,
                        child: TextField(
                          controller: ctrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(fontSize: grande ? 15 : 13),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: grande ? 12 : 8),
                            filled: true,
                            fillColor: const Color(0xFFE8EAF0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                          onChanged: (v) {
                            _actualizarCantidad(index, v);
                            alReconstruir();
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Color(0xFF0D2B4E)),
                        onPressed: () {
                          _quitarItem(index);
                          alReconstruir();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Ubicación (bodega/estante en la sucursal de origen):
                  // opcional, igual que en el sistema viejo — se imprime en
                  // el ticket como "Ubicación: X" debajo del producto.
                  SizedBox(
                    width: grande ? 260 : 200,
                    child: TextField(
                      controller: ctrlUbicacion,
                      style: GoogleFonts.poppins(fontSize: grande ? 13 : 12),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Ubicación (opcional)',
                        hintStyle: GoogleFonts.poppins(fontSize: grande ? 12.5 : 11.5, color: Colors.grey.shade400),
                        prefixIcon: Icon(Icons.place_outlined, size: 16, color: Colors.grey.shade500),
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        filled: true,
                        fillColor: const Color(0xFFF2F3F7),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                      onChanged: (v) => _actualizarUbicacion(index, v),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );

    if (!alturaAcotada) return columna;
    return Expanded(child: SingleChildScrollView(child: columna));
  }

  Widget _tarjetaFooter() {
    final totalUnidades = _items.fold<double>(0, (s, i) => s + i.cantidad);
    return _tarjeta(
      child: Row(
        children: [
          Text('Total: ${totalUnidades.toStringAsFixed(totalUnidades == totalUnidades.roundToDouble() ? 0 : 2)} unidades', style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A))),
          const Spacer(),
          FilledButton.icon(
            onPressed: _guardando ? null : _guardar,
            icon: _guardando
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.sync_alt, size: 18),
            label: Text(_guardando ? 'Guardando...' : 'Registrar Traslado', style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white)),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D2B4E), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ],
      ),
    );
  }
}
