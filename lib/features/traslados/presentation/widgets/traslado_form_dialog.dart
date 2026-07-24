import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/item_traslado_model.dart';
import '../../providers/traslados_provider.dart';
import '../../../sucursales/data/sucursal_model.dart';
import '../../../sucursales/providers/sucursales_provider.dart';
import '../../../productos/data/producto_model.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../compras/presentation/widgets/buscar_producto_compra_dialog.dart';

class TrasladoFormDialog extends ConsumerStatefulWidget {
  const TrasladoFormDialog({super.key});

  @override
  ConsumerState<TrasladoFormDialog> createState() => _TrasladoFormDialogState();
}

class _TrasladoFormDialogState extends ConsumerState<TrasladoFormDialog> {
  final _observacionesController = TextEditingController();
  SucursalModel? _origen;
  SucursalModel? _destino;
  List<ItemTrasladoModel> _items = [];
  final Map<int, TextEditingController> _ctrlCantidad = {};
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _observacionesController.dispose();
    for (final c in _ctrlCantidad.values) {
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
    setState(() => _items = [..._items]..removeAt(index));
  }

  void _actualizarCantidad(int index, String texto) {
    final cantidad = double.tryParse(texto.replaceAll(',', '.'));
    if (cantidad == null || cantidad <= 0) return;
    final nuevos = [..._items];
    nuevos[index] = ItemTrasladoModel(idProducto: nuevos[index].idProducto, nombreProducto: nuevos[index].nombreProducto, cantidad: cantidad);
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
      final usuario = ref.read(authProvider).usuario?.nombreCompleto ?? '';
      await ref.read(trasladoRepositoryProvider).registrar(
            idSucursalOrigen: _origen!.id,
            nombreSucursalOrigen: _origen!.nombre,
            idSucursalDestino: _destino!.id,
            nombreSucursalDestino: _destino!.nombre,
            observaciones: _observacionesController.text.trim(),
            usuarioCrea: usuario,
            detalle: _items,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _guardando = false;
      });
    }
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
          hint: Text(label, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
          items: opciones.map((s) => DropdownMenuItem(value: s, child: Text(s.nombre, style: GoogleFonts.poppins(fontSize: 13.5)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sucursalesAsync = ref.watch(sucursalesActivasProvider);
    final tamano = MediaQuery.of(context).size;
    final esMovil = tamano.width < 560;
    final anchoDialog = esMovil ? tamano.width - 32 : 560.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: anchoDialog,
        constraints: BoxConstraints(maxHeight: tamano.height - 80),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 16, 0),
              child: Row(
                children: [
                  Expanded(child: Text('Nuevo Traslado', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)))),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: sucursalesAsync.when(
                  data: (sucursales) {
                    if (sucursales.length < 2) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text('Necesitás al menos 2 sucursales activas registradas para hacer un traslado.', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: _selectorSucursal(label: 'Sucursal origen', valor: _origen, opciones: sucursales, onChanged: (v) => setState(() => _origen = v))),
                            const SizedBox(width: 10),
                            Icon(Icons.arrow_forward, color: Colors.grey.shade400),
                            const SizedBox(width: 10),
                            Expanded(child: _selectorSucursal(label: 'Sucursal destino', valor: _destino, opciones: sucursales, onChanged: (v) => setState(() => _destino = v))),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextField(controller: _observacionesController, style: GoogleFonts.poppins(fontSize: 13), decoration: _decoracion('Observaciones (opcional)')),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text('Productos', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                            const Spacer(),
                            TextButton.icon(onPressed: _agregarProducto, icon: const Icon(Icons.add, size: 18), label: Text('Agregar', style: GoogleFonts.poppins(fontSize: 12.5))),
                          ],
                        ),
                        if (_items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text('Sin productos todavía', style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade500)),
                          )
                        else
                          ..._items.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            final ctrl = _ctrlCantidad.putIfAbsent(index, () => TextEditingController(text: item.cantidad.toStringAsFixed(item.cantidad == item.cantidad.roundToDouble() ? 0 : 2)));
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(child: Text(item.nombreProducto, style: GoogleFonts.poppins(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                  SizedBox(
                                    width: 70,
                                    child: TextField(
                                      controller: ctrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(fontSize: 13),
                                      decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8), filled: true, fillColor: const Color(0xFFE8EAF0), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
                                      onChanged: (v) => _actualizarCantidad(index, v),
                                    ),
                                  ),
                                  IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => _quitarItem(index)),
                                ],
                              ),
                            );
                          }),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)),
                            child: Text(_error!, style: GoogleFonts.poppins(color: Colors.red.shade700, fontSize: 12)),
                          ),
                        ],
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                  loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: CircularProgressIndicator(color: Color(0xFF0D2B4E)))),
                  error: (e, st) => Text('Error: $e', style: GoogleFonts.poppins(color: Colors.red)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 22),
              child: Row(
                children: [
                  const Spacer(),
                  TextButton(onPressed: _guardando ? null : () => Navigator.pop(context), child: Text('Cancelar', style: GoogleFonts.poppins(color: Colors.grey.shade700))),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _guardando ? null : _guardar,
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D2B4E), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _guardando
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
                        : Text('Crear Traslado', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
