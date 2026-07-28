import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/carrito_compra_provider.dart';
import '../../providers/compras_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../productos/data/producto_model.dart';
import '../../../productos/providers/productos_provider.dart';
import '../../../proveedores/data/proveedor_model.dart';
import '../../../../core/providers/tabs_provider.dart';
import '../../../../core/utils/formato_moneda.dart';
import '../widgets/buscar_producto_compra_dialog.dart';
import '../widgets/buscar_proveedor_dialog.dart';
import 'detalle_compra_screen.dart';

const _metodosPago = ['Efectivo', 'Transferencia', 'Tarjeta', 'Cheque'];

class RegistrarCompraScreen extends ConsumerStatefulWidget {
  // Id de la pestaña donde vive esta pantalla: los atajos de teclado
  // (F10/F12) lo usan para saber si esta es la pestaña activa antes de
  // responder (ver la misma explicación en RegistrarVentaScreen).
  final String? tabId;

  const RegistrarCompraScreen({super.key, this.tabId});

  @override
  ConsumerState<RegistrarCompraScreen> createState() => _RegistrarCompraScreenState();
}

class _RegistrarCompraScreenState extends ConsumerState<RegistrarCompraScreen> {
  final _proveedorController = TextEditingController();
  final _noFacturaController = TextEditingController();
  final _descuentoGlobalController = TextEditingController();
  final _isvController = TextEditingController(text: '15');
  final _ajusteManualController = TextEditingController();
  bool _datosExpandidos = false;
  bool _guardando = false;

  final Map<int, TextEditingController> _ctrlCantidad = {};
  final Map<int, TextEditingController> _ctrlPrecio = {};
  final Map<int, TextEditingController> _ctrlDescuento = {};
  final Map<int, TextEditingController> _ctrlMargen = {};
  final Map<int, TextEditingController> _ctrlPrecioVenta = {};
  final Map<int, TextEditingController> _ctrlDescripcion = {};
  // _focusInline y _confirmarInline respaldan a _campoInlineNumero: ver el
  // comentario junto a esa función para la explicación completa.
  final Map<String, FocusNode> _focusInline = {};
  final Map<String, VoidCallback> _confirmarInline = {};
  int _conteoItemsControladores = -1;

  @override
  void initState() {
    super.initState();
    // Atajos a nivel de hardware (no de foco): así funcionan sin importar
    // qué campo de la pantalla tenga el foco en ese momento.
    HardwareKeyboard.instance.addHandler(_manejarAtajoTeclado);
  }

  bool _manejarAtajoTeclado(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!mounted || _guardando) return false;
    if (!_esPestanaActiva()) return false;
    if (event.logicalKey == LogicalKeyboardKey.f10) {
      _agregarProductoDesdeBusqueda();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.f12) {
      _confirmarCompra();
      return true;
    }
    return false;
  }

  bool _esPestanaActiva() {
    final tabId = widget.tabId;
    if (tabId == null) return true;
    final tabsState = ref.read(tabsProvider);
    if (tabsState.indiceActivo < 0 || tabsState.indiceActivo >= tabsState.tabs.length) return false;
    return tabsState.tabs[tabsState.indiceActivo].id == tabId;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_manejarAtajoTeclado);
    _proveedorController.dispose();
    _noFacturaController.dispose();
    _descuentoGlobalController.dispose();
    _isvController.dispose();
    _ajusteManualController.dispose();
    for (final c in _ctrlCantidad.values) {
      c.dispose();
    }
    for (final c in _ctrlPrecio.values) {
      c.dispose();
    }
    for (final c in _ctrlDescuento.values) {
      c.dispose();
    }
    for (final c in _ctrlMargen.values) {
      c.dispose();
    }
    for (final c in _ctrlPrecioVenta.values) {
      c.dispose();
    }
    for (final c in _ctrlDescripcion.values) {
      c.dispose();
    }
    for (final f in _focusInline.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<bool> _confirmarDialogo(String titulo, String mensaje) async {
    final resultado = await showDialog<bool>(
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
            child: Text('Sí', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
    return resultado ?? false;
  }

  // ---------- Producto ----------

  Future<void> _agregarProductoDesdeBusqueda() async {
    final producto = await Navigator.of(context).push<ProductoModel>(
      MaterialPageRoute(fullscreenDialog: true, builder: (context) => const BuscarProductoCompraDialog()),
    );
    if (producto == null || !mounted) return;
    ref.read(carritoCompraProvider.notifier).agregarProductoDirecto(producto);
  }

  void _quitarItem(int index) {
    ref.read(carritoCompraProvider.notifier).quitarItem(index);
  }

  void _actualizarCantidad(int index, double nuevaCantidad) {
    if (nuevaCantidad <= 0) {
      _mostrarMensaje('La cantidad debe ser mayor a 0');
      return;
    }
    ref.read(carritoCompraProvider.notifier).actualizarLinea(index, cantidad: nuevaCantidad);
  }

  void _actualizarPrecio(int index, double nuevoPrecio) {
    if (nuevoPrecio < 0) {
      _mostrarMensaje('Precio inválido');
      return;
    }
    ref.read(carritoCompraProvider.notifier).actualizarLinea(index, precioCompra: nuevoPrecio);
    _sincronizarMargenControlador(index);
  }

  void _actualizarDescuentoLinea(int index, double descuento) {
    if (descuento < 0 || descuento > 100) {
      _mostrarMensaje('El descuento debe estar entre 0 y 100');
      return;
    }
    ref.read(carritoCompraProvider.notifier).actualizarLinea(index, descuentoPorcentaje: descuento);
    _sincronizarMargenControlador(index);
  }

  /// Costo final por unidad (con descuento de línea e ISV de la compra ya
  /// aplicados): la misma referencia que usa el margen de ganancia sugerido.
  double _costoFinalItem(dynamic item) {
    final isv = ref.read(carritoCompraProvider).isvPorcentaje;
    return redondearMoneda((item.precioCompra as double) * (1 - (item.descuentoPorcentaje as double) / 100) * (1 + isv / 100));
  }

  double _margenActual(dynamic item) {
    final costo = _costoFinalItem(item);
    final precioVenta = (item.precioVentaNuevo as double?) ?? 0;
    return costo > 0 ? ((precioVenta - costo) / costo * 100) : 0.0;
  }

  (TextEditingController, TextEditingController) _controladoresMargen(int index, dynamic item) {
    final ctrlMargen = _ctrlMargen.putIfAbsent(index, () => TextEditingController(text: _margenActual(item).toStringAsFixed(1)));
    final ctrlPrecioVenta = _ctrlPrecioVenta.putIfAbsent(index, () => TextEditingController(text: ((item.precioVentaNuevo as double?) ?? 0).toStringAsFixed(2)));
    return (ctrlMargen, ctrlPrecioVenta);
  }

  void _actualizarPrecioVentaCompra(int index, double nuevoPrecioVenta) {
    if (nuevoPrecioVenta < 0) {
      _mostrarMensaje('Precio inválido');
      return;
    }
    ref.read(carritoCompraProvider.notifier).actualizarLinea(index, precioVentaNuevo: nuevoPrecioVenta);
    _sincronizarMargenControlador(index);
  }

  void _actualizarDescripcionCompra(int index, String nuevaDescripcion) {
    ref.read(carritoCompraProvider.notifier).actualizarLinea(index, descripcionNueva: nuevaDescripcion);
  }

  void _actualizarMargenCompra(int index, double nuevoMargen) {
    final carrito = ref.read(carritoCompraProvider);
    if (index >= carrito.items.length) return;
    final costo = _costoFinalItem(carrito.items[index]);
    final nuevoPrecio = redondearMoneda(costo * (1 + nuevoMargen / 100));
    ref.read(carritoCompraProvider.notifier).actualizarLinea(index, precioVentaNuevo: nuevoPrecio);
    _ctrlPrecioVenta[index]?.text = nuevoPrecio.toStringAsFixed(2);
  }

  /// Recalcula el % de margen mostrado a partir del precio de venta y el
  /// costo final vigentes. Se llama después de editar el precio de venta, la
  /// cantidad, el costo unitario o el descuento de línea, para que el
  /// margen mostrado nunca quede desactualizado.
  void _sincronizarMargenControlador(int index) {
    final carrito = ref.read(carritoCompraProvider);
    if (index >= carrito.items.length) return;
    final item = carrito.items[index];
    final costo = _costoFinalItem(item);
    final precioVenta = item.precioVentaNuevo ?? 0;
    final margen = costo > 0 ? ((precioVenta - costo) / costo * 100) : 0.0;
    _ctrlMargen[index]?.text = margen.toStringAsFixed(1);
  }

  double _descuentoLineaMonto(dynamic item) {
    final sinDescuento = redondearMoneda((item.precioCompra as double) * (item.cantidad as double));
    return redondearMoneda(sinDescuento - (item.subtotal as double));
  }

  // ---------- Limpiar ----------

  void _limpiarTodo() {
    ref.read(carritoCompraProvider.notifier).limpiar();
    _proveedorController.clear();
    _noFacturaController.clear();
    _descuentoGlobalController.clear();
    _isvController.text = '15';
    _ajusteManualController.clear();
    for (final c in _ctrlCantidad.values) {
      c.dispose();
    }
    for (final c in _ctrlPrecio.values) {
      c.dispose();
    }
    for (final c in _ctrlDescuento.values) {
      c.dispose();
    }
    for (final c in _ctrlMargen.values) {
      c.dispose();
    }
    for (final c in _ctrlPrecioVenta.values) {
      c.dispose();
    }
    for (final c in _ctrlDescripcion.values) {
      c.dispose();
    }
    _ctrlCantidad.clear();
    _ctrlPrecio.clear();
    _ctrlDescuento.clear();
    _ctrlMargen.clear();
    _ctrlPrecioVenta.clear();
    _ctrlDescripcion.clear();
    _conteoItemsControladores = 0;
  }

  Future<void> _confirmarLimpiar() async {
    final carrito = ref.read(carritoCompraProvider);
    final hayAlgoQuePerder = carrito.items.isNotEmpty || carrito.razonSocial.isNotEmpty;
    if (hayAlgoQuePerder) {
      final continuar = await _confirmarDialogo('Limpiar compra', '¿Seguro que querés borrar todos los productos y datos ingresados en esta compra?');
      if (!continuar) return;
    }
    _limpiarTodo();
  }

  // ---------- Confirmar compra ----------

  Future<void> _confirmarCompra() async {
    final carrito = ref.read(carritoCompraProvider);
    if (carrito.items.isEmpty) {
      _mostrarMensaje('Debe ingresar productos en la compra');
      return;
    }
    if (carrito.idProveedor.isEmpty) {
      _mostrarMensaje('Seleccioná un proveedor');
      return;
    }
    if (carrito.esCredito && carrito.fechaVencimiento == null) {
      _mostrarMensaje('Definí la fecha de vencimiento del crédito');
      return;
    }

    setState(() => _guardando = true);
    try {
      final usuario = ref.read(authProvider).usuario?.nombreCompleto ?? '';
      final compra = await ref.read(compraRepositoryProvider).registrarCompra(
            noFactura: _noFacturaController.text.trim(),
            idProveedor: carrito.idProveedor,
            documentoProveedor: carrito.documentoProveedor,
            razonSocial: carrito.razonSocial,
            condicion: carrito.condicion,
            metodoPago: carrito.esCredito ? 'N/A' : carrito.metodoPago,
            fechaRegistro: carrito.fecha,
            fechaVencimiento: carrito.esCredito ? carrito.fechaVencimiento : null,
            descuentoGlobalPorcentaje: carrito.descuentoGlobalPorcentaje,
            descuentoTotalMonto: carrito.descuentoTotalMonto,
            isvPorcentaje: carrito.isvPorcentaje,
            ajusteManual: carrito.ajusteManual,
            items: carrito.items,
            subtotal: carrito.subtotal,
            impuesto: carrito.impuesto,
            totalAPagar: carrito.totalAPagar,
            usuario: usuario,
          );

      if (!mounted) return;
      _limpiarTodo();
      _mostrarMensaje('Compra registrada: ${compra.numeroDocumento}');
    } catch (e) {
      _mostrarMensaje(e is TimeoutException
          ? 'No se pudo guardar: se agotó el tiempo de espera. Revisá la conexión a internet e intentá de nuevo.'
          : 'Error al registrar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final carrito = ref.watch(carritoCompraProvider);

    return Container(
      color: const Color(0xFFF2F3F7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final esMovil = constraints.maxWidth < 900;
          final altoTabla = (constraints.maxHeight * 0.58).clamp(360.0, 1000.0);
          return SingleChildScrollView(
            padding: EdgeInsets.all(esMovil ? 14 : 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _encabezado(esMovil),
                const SizedBox(height: 14),
                _tarjetaDatosCompra(carrito, esMovil),
                const SizedBox(height: 14),
                esMovil
                    ? _tarjetaCarritoGrande(carrito, esMovil)
                    : SizedBox(height: altoTabla, child: _tarjetaCarritoGrande(carrito, esMovil)),
                const SizedBox(height: 14),
                _tarjetaTotales(carrito, esMovil),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _encabezado(bool esMovil) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        Text('Registrar Compra', style: GoogleFonts.poppins(fontSize: esMovil ? 19 : 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
        OutlinedButton.icon(
          onPressed: _confirmarLimpiar,
          icon: const Icon(Icons.delete_sweep_outlined, size: 18),
          label: Text('Limpiar Compra', style: GoogleFonts.poppins(fontSize: 13)),
          style: _estiloBotonSecundario(),
        ),
        OutlinedButton.icon(
          onPressed: _verDetalleCompra,
          icon: const Icon(Icons.receipt_long_outlined, size: 18),
          label: Text('Ver Detalle', style: GoogleFonts.poppins(fontSize: 13)),
          style: _estiloBotonSecundario(),
        ),
      ],
    );
  }

  void _verDetalleCompra() {
    Navigator.of(context).push(
      MaterialPageRoute(fullscreenDialog: true, builder: (context) => const DetalleCompraScreen()),
    );
  }

  ButtonStyle _estiloBotonSecundario() {
    return OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF1A1A1A),
      side: const BorderSide(color: Color(0xFFB6BCC7)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  InputDecoration _decoracion(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.poppins(fontSize: 12.5),
      hintStyle: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey.shade400),
      filled: true,
      fillColor: const Color(0xFFE8EAF0),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Future<void> _buscarProveedor() async {
    final proveedor = await showDialog<ProveedorModel>(context: context, builder: (context) => const BuscarProveedorDialog());
    if (proveedor == null || !mounted) return;
    _proveedorController.text = proveedor.razonSocial;
    ref.read(carritoCompraProvider.notifier).establecerProveedor(idProveedor: proveedor.id, documentoProveedor: proveedor.rtn, razonSocial: proveedor.razonSocial);
  }

  Widget _tarjetaDatosCompra(CarritoCompraState carrito, bool esMovil) {
    final formatoFecha = DateFormat('dd/MM/yyyy');

    return _tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: esMovil ? double.infinity : 160,
                child: InkWell(
                  onTap: () async {
                    final fecha = await showDatePicker(context: context, initialDate: carrito.fecha, firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (fecha != null) ref.read(carritoCompraProvider.notifier).establecerFecha(fecha);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(color: const Color(0xFFE8EAF0), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey.shade500),
                        const SizedBox(width: 10),
                        Flexible(child: Text(formatoFecha.format(carrito.fecha), overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF1A1A1A)))),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: esMovil ? double.infinity : 260,
                child: TextField(
                  readOnly: true,
                  onTap: _buscarProveedor,
                  controller: _proveedorController,
                  style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF1A1A1A)),
                  decoration: _decoracion('Proveedor').copyWith(
                    hintText: 'Tocá para buscar (hay muchos)...',
                    hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400),
                    suffixIcon: const Icon(Icons.search, size: 20),
                  ),
                ),
              ),
              SizedBox(
                width: esMovil ? double.infinity : 180,
                child: TextField(
                  controller: _noFacturaController,
                  style: GoogleFonts.poppins(fontSize: 13),
                  decoration: _decoracion('No. Factura'),
                  onChanged: (v) => ref.read(carritoCompraProvider.notifier).establecerNoFactura(v),
                ),
              ),
              SizedBox(
                width: esMovil ? double.infinity : 150,
                child: DropdownButtonFormField<String>(
                  initialValue: carrito.condicion,
                  isExpanded: true,
                  decoration: _decoracion('Condición'),
                  style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF1A1A1A)),
                  items: const [
                    DropdownMenuItem(value: 'Contado', child: Text('Contado')),
                    DropdownMenuItem(value: 'Credito', child: Text('Crédito')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    ref.read(carritoCompraProvider.notifier).establecerCondicion(v);
                  },
                ),
              ),
              if (carrito.condicion == 'Credito')
                SizedBox(
                  width: esMovil ? double.infinity : 160,
                  child: InkWell(
                    onTap: () async {
                      final fecha = await showDatePicker(
                        context: context,
                        initialDate: carrito.fechaVencimiento ?? DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (fecha != null) ref.read(carritoCompraProvider.notifier).establecerFechaVencimiento(fecha);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(color: const Color(0xFFE8EAF0), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Icon(Icons.event_outlined, size: 16, color: Colors.grey.shade500),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Vence: ${carrito.fechaVencimiento != null ? formatoFecha.format(carrito.fechaVencimiento!) : 'Sin definir'}',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF1A1A1A)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: esMovil ? double.infinity : 160,
                  child: DropdownButtonFormField<String>(
                    initialValue: _metodosPago.contains(carrito.metodoPago) ? carrito.metodoPago : null,
                    isExpanded: true,
                    decoration: _decoracion('Método de pago'),
                    style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF1A1A1A)),
                    items: _metodosPago.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      ref.read(carritoCompraProvider.notifier).establecerMetodoPago(v);
                    },
                  ),
                ),
              InkWell(
                onTap: () => setState(() => _datosExpandidos = !_datosExpandidos),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _datosExpandidos ? 'Ver menos' : 'Más datos',
                        style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0D2B4E)),
                      ),
                      Icon(_datosExpandidos ? Icons.expand_less : Icons.expand_more, size: 20, color: const Color(0xFF0D2B4E)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topLeft,
            child: !_datosExpandidos
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(color: Colors.grey.shade200),
                        const SizedBox(height: 14),
                        Text('Descuento global, ISV y ajuste manual', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 14,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: esMovil ? double.infinity : 220,
                              child: TextField(
                                controller: _descuentoGlobalController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: GoogleFonts.poppins(fontSize: 13),
                                decoration: _decoracion('Descuento global (%)'),
                                onChanged: (v) {
                                  final valor = double.tryParse(v.replaceAll(',', '').trim());
                                  if (valor == null || valor < 0 || valor > 100) return;
                                  ref.read(carritoCompraProvider.notifier).establecerDescuentoGlobal(valor);
                                },
                              ),
                            ),
                            SizedBox(
                              width: esMovil ? double.infinity : 160,
                              child: TextField(
                                controller: _isvController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: GoogleFonts.poppins(fontSize: 13),
                                decoration: _decoracion('ISV (%)'),
                                onChanged: (v) {
                                  final valor = double.tryParse(v.replaceAll(',', '').trim());
                                  if (valor == null || valor < 0) return;
                                  ref.read(carritoCompraProvider.notifier).establecerIsv(valor);
                                },
                              ),
                            ),
                            SizedBox(
                              width: esMovil ? double.infinity : 260,
                              child: TextField(
                                controller: _ajusteManualController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                style: GoogleFonts.poppins(fontSize: 13),
                                decoration: _decoracion('Ajuste manual (+/-)', hint: 'Para cuadrar centavos con la factura'),
                                onChanged: (v) {
                                  final valor = double.tryParse(v.replaceAll(',', '').trim());
                                  ref.read(carritoCompraProvider.notifier).establecerAjusteManual(valor ?? 0);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaCarritoGrande(CarritoCompraState carrito, bool esMovil) {
    final productos = ref.watch(productosStreamProvider).value ?? [];
    final mapaProductos = {for (final p in productos) p.id: p};

    if (carrito.items.length != _conteoItemsControladores) {
      for (final c in _ctrlCantidad.values) {
        c.dispose();
      }
      for (final c in _ctrlPrecio.values) {
        c.dispose();
      }
      for (final c in _ctrlDescuento.values) {
        c.dispose();
      }
      for (final c in _ctrlMargen.values) {
        c.dispose();
      }
      for (final c in _ctrlPrecioVenta.values) {
        c.dispose();
      }
      for (final c in _ctrlDescripcion.values) {
        c.dispose();
      }
      _ctrlCantidad.clear();
      _ctrlPrecio.clear();
      _ctrlDescuento.clear();
      _ctrlMargen.clear();
      _ctrlPrecioVenta.clear();
      _ctrlDescripcion.clear();
      for (final f in _focusInline.values) {
        f.dispose();
      }
      _focusInline.clear();
      _confirmarInline.clear();
      _conteoItemsControladores = carrito.items.length;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC7CBD3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          esMovil
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Productos en la compra', style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _agregarProductoDesdeBusqueda,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text('Agregar Producto', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D2B4E), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Text('Productos en la compra', style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _agregarProductoDesdeBusqueda,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text('Agregar Producto', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D2B4E), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ],
                ),
          const SizedBox(height: 14),
          if (!esMovil) ...[
            _encabezadoTablaCarrito(),
            Divider(height: 18, color: Colors.grey.shade300),
          ],
          if (carrito.items.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Todavía no agregaste productos.\nUsá "Agregar Producto" para buscar del inventario.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.grey.shade500),
                ),
              ),
            )
          else if (esMovil)
            // Ver nota equivalente en registrar_venta_screen.dart: en móvil
            // evitamos una lista con scroll propio anidada dentro del scroll
            // de toda la pantalla.
            Column(
              children: [
                for (var i = 0; i < carrito.items.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: Colors.grey.shade200),
                  _filaCarritoMovil(i, carrito.items[i], mapaProductos),
                ],
              ],
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: carrito.items.length,
                separatorBuilder: (context, i) => Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (context, i) => _filaCarritoTabla(i, carrito.items[i], mapaProductos),
              ),
            ),
        ],
      ),
    );
  }

  Widget _encabezadoTablaCarrito() {
    final estilo = GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.grey.shade600);
    return Row(
      children: [
        Expanded(flex: 2, child: Text('Código', style: estilo)),
        Expanded(flex: 4, child: Text('Descripción', style: estilo)),
        Expanded(flex: 2, child: Text('Cantidad', textAlign: TextAlign.center, style: estilo)),
        Expanded(flex: 2, child: Text('Costo unitario', textAlign: TextAlign.center, style: estilo)),
        Expanded(flex: 2, child: Text('Descuento %', textAlign: TextAlign.center, style: estilo)),
        Expanded(flex: 2, child: Text('Descuento (L)', textAlign: TextAlign.right, style: estilo)),
        Expanded(flex: 2, child: Text('Importe', textAlign: TextAlign.right, style: estilo)),
        const SizedBox(width: 40),
      ],
    );
  }

  // [claveFoco] identifica el campo (p.ej. "cantidad_2") para cachear su
  // FocusNode entre reconstrucciones. Antes esto confirmaba solo al enviar
  // (onSubmitted) o al tocar literalmente fuera del campo (onTapOutside): en
  // el celular, si el usuario tocaba un botón directamente (sin pasar antes
  // por un área vacía), el valor tecleado se perdía. Ahora se confirma al
  // perder el foco por cualquier motivo (FocusNode.addListener), que es lo
  // único que cubre "cualquier forma de salir del campo". El listener del
  // FocusNode se crea una sola vez (putIfAbsent) pero llama indirectamente a
  // través de _confirmarInline[claveFoco], que se refresca en cada build:
  // así siempre usa el [valorActual]/[alConfirmar] vigentes en vez de quedar
  // atado a los del primer build (que sería el bug si el listener capturara
  // esos parámetros directamente).
  Widget _campoInlineNumero(String claveFoco, TextEditingController controlador, double valorActual, void Function(double) alConfirmar, {String? sufijo, String? prefijo}) {
    void confirmar() {
      final valor = double.tryParse(controlador.text.replaceAll(',', '').trim());
      if (valor == null || (valor - valorActual).abs() < 0.005) return;
      alConfirmar(valor);
    }
    _confirmarInline[claveFoco] = confirmar;

    final focusNode = _focusInline.putIfAbsent(claveFoco, () {
      final node = FocusNode();
      node.addListener(() {
        if (!node.hasFocus) _confirmarInline[claveFoco]?.call();
      });
      return node;
    });

    return TextField(
      controller: controlador,
      focusNode: focusNode,
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: GoogleFonts.poppins(fontSize: 13),
      decoration: InputDecoration(
        suffixText: sufijo,
        prefixText: prefijo,
        prefixStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
        filled: true,
        fillColor: const Color(0xFFE8EAF0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      onSubmitted: (_) => confirmar(),
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
    );
  }

  // Igual que _campoInlineNumero (confirma al perder el foco o con Enter,
  // no en cada tecla) pero para texto libre: se usa para poder agregarle o
  // corregirle la descripción al producto de una vez, sin ir aparte a
  // Inventario.
  Widget _campoInlineTexto(String claveFoco, TextEditingController controlador, String valorActual, void Function(String) alConfirmar) {
    void confirmar() {
      final valor = controlador.text.trim();
      if (valor == valorActual.trim()) return;
      alConfirmar(valor);
    }
    _confirmarInline[claveFoco] = confirmar;

    final focusNode = _focusInline.putIfAbsent(claveFoco, () {
      final node = FocusNode();
      node.addListener(() {
        if (!node.hasFocus) _confirmarInline[claveFoco]?.call();
      });
      return node;
    });

    return TextField(
      controller: controlador,
      focusNode: focusNode,
      style: GoogleFonts.poppins(fontSize: 13),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFE8EAF0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      onSubmitted: (_) => confirmar(),
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
    );
  }

  Widget _campoInlineConEtiquetaTexto(String claveFoco, String etiqueta, TextEditingController controlador, String valorActual, void Function(String) alConfirmar) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade500)),
        const SizedBox(height: 4),
        _campoInlineTexto(claveFoco, controlador, valorActual, alConfirmar),
      ],
    );
  }

  Widget _campoInlineConEtiqueta(String claveFoco, String etiqueta, TextEditingController controlador, double valorActual, void Function(double) alConfirmar, {String? prefijo}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade500)),
        const SizedBox(height: 4),
        _campoInlineNumero(claveFoco, controlador, valorActual, alConfirmar, prefijo: prefijo),
      ],
    );
  }

  Widget _filaCarritoTabla(int index, dynamic item, Map<String, ProductoModel> mapaProductos) {
    final producto = mapaProductos[item.idProducto as String];

    final ctrlCantidad = _ctrlCantidad.putIfAbsent(index, () => TextEditingController(text: _formatoCantidad(item.cantidad as double)));
    final ctrlPrecio = _ctrlPrecio.putIfAbsent(index, () => TextEditingController(text: (item.precioCompra as double).toStringAsFixed(2)));
    final ctrlDescuento = _ctrlDescuento.putIfAbsent(index, () => TextEditingController(text: _formatoCantidad(item.descuentoPorcentaje as double)));
    final (ctrlMargen, ctrlPrecioVenta) = _controladoresMargen(index, item);
    final ctrlDescripcion = _ctrlDescripcion.putIfAbsent(index, () => TextEditingController(text: (item.descripcionNueva as String?) ?? ''));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 2, child: Text(producto?.codigo ?? '-', style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade600))),
              Expanded(
                flex: 4,
                child: Text(item.nombreProducto as String, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              ),
              Expanded(flex: 2, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _campoInlineNumero('cantidad_$index', ctrlCantidad, item.cantidad as double, (v) => _actualizarCantidad(index, v)))),
              Expanded(flex: 2, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _campoInlineNumero('precio_$index', ctrlPrecio, item.precioCompra as double, (v) => _actualizarPrecio(index, v), prefijo: 'L.'))),
              Expanded(flex: 2, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _campoInlineNumero('descuento_$index', ctrlDescuento, item.descuentoPorcentaje as double, (v) => _actualizarDescuentoLinea(index, v), sufijo: '%'))),
              Expanded(flex: 2, child: Text(formatearMoneda(_descuentoLineaMonto(item)), textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade600))),
              Expanded(flex: 2, child: Text(formatearMoneda(item.subtotal as double), textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700))),
              SizedBox(
                width: 40,
                child: IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF0D2B4E)), onPressed: () => _quitarItem(index)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Spacer(flex: 2),
                Expanded(flex: 2, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _campoInlineConEtiqueta('margen_$index', 'Margen %', ctrlMargen, _margenActual(item), (v) => _actualizarMargenCompra(index, v)))),
                Expanded(flex: 2, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _campoInlineConEtiqueta('precioVenta_$index', 'Precio de venta', ctrlPrecioVenta, (item.precioVentaNuevo as double?) ?? 0, (v) => _actualizarPrecioVentaCompra(index, v), prefijo: 'L.'))),
                Expanded(flex: 4, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _campoInlineConEtiquetaTexto('descripcion_$index', 'Ubicación física (opcional)', ctrlDescripcion, (item.descripcionNueva as String?) ?? '', (v) => _actualizarDescripcionCompra(index, v)))),
                const SizedBox(width: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaCarritoMovil(int index, dynamic item, Map<String, ProductoModel> mapaProductos) {
    final producto = mapaProductos[item.idProducto as String];

    final ctrlCantidad = _ctrlCantidad.putIfAbsent(index, () => TextEditingController(text: _formatoCantidad(item.cantidad as double)));
    final ctrlPrecio = _ctrlPrecio.putIfAbsent(index, () => TextEditingController(text: (item.precioCompra as double).toStringAsFixed(2)));
    final ctrlDescuento = _ctrlDescuento.putIfAbsent(index, () => TextEditingController(text: _formatoCantidad(item.descuentoPorcentaje as double)));
    final (ctrlMargen, ctrlPrecioVenta) = _controladoresMargen(index, item);
    final ctrlDescripcion = _ctrlDescripcion.putIfAbsent(index, () => TextEditingController(text: (item.descripcionNueva as String?) ?? ''));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8F9FB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFC7CBD3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.nombreProducto as String, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(producto?.codigo ?? '-', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF0D2B4E)), onPressed: () => _quitarItem(index)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _campoInlineConEtiqueta('cantidad_$index', 'Cantidad', ctrlCantidad, item.cantidad as double, (v) => _actualizarCantidad(index, v))),
              const SizedBox(width: 8),
              Expanded(child: _campoInlineConEtiqueta('precio_$index', 'Costo unitario', ctrlPrecio, item.precioCompra as double, (v) => _actualizarPrecio(index, v), prefijo: 'L.')),
              const SizedBox(width: 8),
              Expanded(child: _campoInlineConEtiqueta('descuento_$index', 'Desc. %', ctrlDescuento, item.descuentoPorcentaje as double, (v) => _actualizarDescuentoLinea(index, v))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _campoInlineConEtiqueta('margen_$index', 'Margen %', ctrlMargen, _margenActual(item), (v) => _actualizarMargenCompra(index, v))),
              const SizedBox(width: 8),
              Expanded(child: _campoInlineConEtiqueta('precioVenta_$index', 'Precio de venta', ctrlPrecioVenta, (item.precioVentaNuevo as double?) ?? 0, (v) => _actualizarPrecioVentaCompra(index, v), prefijo: 'L.')),
            ],
          ),
          const SizedBox(height: 10),
          _campoInlineConEtiquetaTexto('descripcion_$index', 'Ubicación física (opcional)', ctrlDescripcion, (item.descripcionNueva as String?) ?? '', (v) => _actualizarDescripcionCompra(index, v)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Descuento: ${formatearMoneda(_descuentoLineaMonto(item))}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
              Text('Importe: ${formatearMoneda(item.subtotal as double)}', style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatoCantidad(double cantidad) {
    if (cantidad == cantidad.roundToDouble()) return cantidad.toInt().toString();
    return cantidad.toStringAsFixed(2);
  }

  Widget _tarjetaTotales(CarritoCompraState carrito, bool esMovil) {
    return _tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              _filaTotalTexto('Subtotal', carrito.subtotal),
              if (carrito.descuentoTotalMonto > 0) _filaTotalTexto('Descuento total', carrito.descuentoTotalMonto),
              _filaTotalTexto('ISV (${_formatoCantidad(carrito.isvPorcentaje)}%)', carrito.impuesto),
              if (carrito.ajusteManual != 0) _filaTotalTexto('Ajuste', carrito.ajusteManual),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(color: const Color(0xFF0D2B4E), borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TOTAL A PAGAR', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(formatearMoneda(carrito.totalAPagar), style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _guardando ? null : _confirmarCompra,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1A1A1A), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _guardando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
                  : Text('Registrar Compra', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaTotalTexto(String etiqueta, double valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.4)),
        Text(formatearMoneda(valor), style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
      ],
    );
  }
}
