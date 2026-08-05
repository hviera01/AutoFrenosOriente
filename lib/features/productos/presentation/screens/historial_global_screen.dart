import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/movimiento_global_model.dart';
import '../../providers/productos_provider.dart';
import '../../../ventas/presentation/screens/detalle_venta_screen.dart';
import '../../../compras/presentation/screens/detalle_compra_screen.dart';
import '../../../traslados/presentation/screens/detalle_traslado_screen.dart';
import '../../../../core/services/tipografia_service.dart';
import '../../../../core/utils/origen_historial_utils.dart';

/// Historial de existencia de TODOS los productos juntos, por fecha —
/// pensado para ver de un vistazo qué movimientos (ventas, compras,
/// traslados, ajustes) hubo en el negocio en un día puntual, sin tener que
/// entrar producto por producto. Por defecto muestra el día de hoy.
class HistorialGlobalScreen extends ConsumerStatefulWidget {
  const HistorialGlobalScreen({super.key});

  @override
  ConsumerState<HistorialGlobalScreen> createState() => _HistorialGlobalScreenState();
}

class _HistorialGlobalScreenState extends ConsumerState<HistorialGlobalScreen> {
  late DateTime _fechaInicio;
  late DateTime _fechaFin;
  Future<List<MovimientoGlobalModel>>? _future;
  Map<String, String>? _nombresPorIdCargados;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _fechaInicio = DateTime(hoy.year, hoy.month, hoy.day);
    _fechaFin = _fechaInicio;
  }

  void _cargar(Map<String, String> nombresPorId) {
    if (identical(nombresPorId, _nombresPorIdCargados) && _future != null) return;
    _nombresPorIdCargados = nombresPorId;
    _future = ref.read(productoRepositoryProvider).obtenerHistorialGlobal(
          _fechaInicio,
          DateTime(_fechaFin.year, _fechaFin.month, _fechaFin.day, 23, 59, 59),
          nombresPorId,
        );
  }

  Future<void> _seleccionarFecha(bool esInicio) async {
    final fecha = await showDatePicker(context: context, initialDate: esInicio ? _fechaInicio : _fechaFin, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (fecha == null) return;
    setState(() {
      if (esInicio) {
        _fechaInicio = fecha;
      } else {
        _fechaFin = fecha;
      }
      _future = null;
    });
  }

  void _irAHoy() {
    final hoy = DateTime.now();
    setState(() {
      _fechaInicio = DateTime(hoy.year, hoy.month, hoy.day);
      _fechaFin = _fechaInicio;
      _future = null;
    });
  }

  void _abrirOrigen(MovimientoGlobalModel r) {
    final origen = origenDeMotivo(r.motivo);
    if (origen == null) return;
    Widget pantalla;
    switch (origen.tipo) {
      case 'venta':
        pantalla = DetalleVentaScreen(numeroDocumentoInicial: origen.numero);
        break;
      case 'compra':
        pantalla = DetalleCompraScreen(numeroDocumentoInicial: origen.numero);
        break;
      case 'traslado':
        pantalla = DetalleTrasladoScreen(numeroInicial: origen.numero);
        break;
      default:
        return;
    }
    Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (context) => pantalla));
  }

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosStreamProvider);
    final formatoFecha = DateFormat('dd/MM/yyyy HH:mm');
    final formatoDia = DateFormat('dd/MM/yyyy');
    final tamano = MediaQuery.of(context).size;
    final esMovil = tamano.width < 720;
    final mismoDia = _fechaInicio.year == _fechaFin.year && _fechaInicio.month == _fechaFin.month && _fechaInicio.day == _fechaFin.day;
    final esHoy = mismoDia && _esHoy(_fechaInicio);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(esMovil ? 14 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Historial Global de Existencias', style: appFont(fontSize: esMovil ? 17 : 21, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: EdgeInsets.only(left: esMovil ? 0 : 54),
                child: Text(
                  'Todos los movimientos de existencia del negocio — tocá una fila para abrir la venta/compra/traslado que la originó',
                  style: appFont(fontSize: esMovil ? 11.5 : 12.5, color: Colors.grey.shade500),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _botonFecha('Desde', _fechaInicio, formatoDia, () => _seleccionarFecha(true)),
                  _botonFecha('Hasta', _fechaFin, formatoDia, () => _seleccionarFecha(false)),
                  if (!esHoy) TextButton.icon(onPressed: _irAHoy, icon: const Icon(Icons.today_outlined, size: 16), label: Text('Hoy', style: appFont(fontSize: 12))),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFC7CBD3))),
                  child: productosAsync.when(
                    data: (productos) {
                      final nombresPorId = {for (final p in productos) p.id: p.nombre};
                      _cargar(nombresPorId);
                      return FutureBuilder<List<MovimientoGlobalModel>>(
                        future: _future,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Color(0xFF0D2B4E)));
                          }
                          if (snapshot.hasError) {
                            return Center(child: Text('Error: ${snapshot.error}', style: appFont(color: Colors.red)));
                          }
                          final registros = snapshot.data ?? [];
                          if (registros.isEmpty) {
                            return Center(child: Text('Sin movimientos en el rango seleccionado', textAlign: TextAlign.center, style: appFont(color: Colors.grey.shade500)));
                          }
                          return esMovil ? _listaMovil(registros, formatoFecha) : _tablaEscritorio(registros, formatoFecha);
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0D2B4E))),
                    error: (e, st) => Center(child: Text('Error: $e', style: appFont(color: Colors.red))),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _esHoy(DateTime fecha) {
    final hoy = DateTime.now();
    return fecha.year == hoy.year && fecha.month == hoy.month && fecha.day == hoy.day;
  }

  Widget _botonFecha(String label, DateTime fecha, DateFormat formato, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFE8EAF0), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFB6BCC7))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF6B7280)),
            const SizedBox(width: 8),
            Text('$label: ${formato.format(fecha)}', style: appFont(fontSize: 12.5, color: const Color(0xFF1A1A1A))),
          ],
        ),
      ),
    );
  }

  // Tabla en un Container con scroll horizontal propio (nunca desborda la
  // pantalla en ventanas angostas de escritorio): las columnas tienen un
  // ancho mínimo razonable para el motivo/producto en vez de comprimirse
  // hasta ser ilegibles.
  Widget _tablaEscritorio(List<MovimientoGlobalModel> registros, DateFormat formatoFecha) {
    final encabezado = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: Color(0xFFECEEF3), borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('FECHA', style: appFont(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.grey.shade600))),
          Expanded(flex: 4, child: Text('PRODUCTO', style: appFont(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.grey.shade600))),
          Expanded(flex: 2, child: Text('ANTERIOR', style: appFont(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.grey.shade600))),
          Expanded(flex: 2, child: Text('NUEVO', style: appFont(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.grey.shade600))),
          Expanded(flex: 4, child: Text('MOTIVO', style: appFont(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.grey.shade600))),
          Expanded(flex: 3, child: Text('USUARIO', style: appFont(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.grey.shade600))),
        ],
      ),
    );

    final filas = Expanded(
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFB6BCC7)), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12))),
        child: ListView.separated(
          itemCount: registros.length,
          separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
          itemBuilder: (context, index) => _filaMovimiento(registros[index], formatoFecha),
        ),
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(width: 900, child: Column(children: [encabezado, filas])),
    );
  }

  Widget _filaMovimiento(MovimientoGlobalModel r, DateFormat formatoFecha) {
    final subio = r.stockNuevo >= r.stockAnterior;
    final esClicable = origenDeMotivo(r.motivo) != null;
    return InkWell(
      onTap: esClicable ? () => _abrirOrigen(r) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(flex: 3, child: Text(r.fecha != null ? formatoFecha.format(r.fecha!) : '-', style: appFont(fontSize: 12))),
            Expanded(flex: 4, child: Text(r.nombreProducto, style: appFont(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis, maxLines: 2)),
            Expanded(flex: 2, child: Text(r.stockAnterior.toString(), style: appFont(fontSize: 12))),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Icon(subio ? Icons.arrow_upward : Icons.arrow_downward, size: 13, color: subio ? const Color(0xFF16A34A) : const Color(0xFF0D2B4E)),
                  const SizedBox(width: 4),
                  Text(r.stockNuevo.toString(), style: appFont(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                r.motivo.isEmpty ? '-' : r.motivo,
                style: appFont(fontSize: 12, color: esClicable ? const Color(0xFF0D2B4E) : Colors.grey.shade600, decoration: esClicable ? TextDecoration.underline : null),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            Expanded(flex: 3, child: Text(r.usuario, style: appFont(fontSize: 12), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  Widget _listaMovil(List<MovimientoGlobalModel> registros, DateFormat formatoFecha) {
    return ListView.separated(
      itemCount: registros.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final r = registros[index];
        final subio = r.stockNuevo >= r.stockAnterior;
        final esClicable = origenDeMotivo(r.motivo) != null;
        return Material(
          color: const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: esClicable ? () => _abrirOrigen(r) : null,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFC7CBD3))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.nombreProducto, style: appFont(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(subio ? Icons.arrow_upward : Icons.arrow_downward, size: 15, color: subio ? const Color(0xFF16A34A) : const Color(0xFF0D2B4E)),
                      const SizedBox(width: 6),
                      Text('${r.stockAnterior} → ${r.stockNuevo}', style: appFont(fontSize: 13, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text(r.fecha != null ? formatoFecha.format(r.fecha!) : '-', style: appFont(fontSize: 10.5, color: Colors.grey.shade500)),
                    ],
                  ),
                  if (r.motivo.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(r.motivo, style: appFont(fontSize: 12, color: esClicable ? const Color(0xFF0D2B4E) : Colors.grey.shade700, decoration: esClicable ? TextDecoration.underline : null)),
                  ],
                  const SizedBox(height: 6),
                  Text(r.usuario, style: appFont(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
