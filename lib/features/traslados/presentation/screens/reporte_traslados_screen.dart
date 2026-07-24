import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/traslado_model.dart';
import '../../providers/traslados_provider.dart';
import '../../../sucursales/providers/sucursales_provider.dart';

class ReporteTrasladosScreen extends ConsumerStatefulWidget {
  const ReporteTrasladosScreen({super.key});

  @override
  ConsumerState<ReporteTrasladosScreen> createState() => _ReporteTrasladosScreenState();
}

class _ReporteTrasladosScreenState extends ConsumerState<ReporteTrasladosScreen> {
  late DateTime _fechaInicio;
  late DateTime _fechaFin;
  String? _estadoFiltro;
  String? _sucursalFiltro;
  bool _cargando = false;
  String? _error;
  List<TrasladoModel>? _traslados;
  final _formatoFecha = DateFormat('dd/MM/yyyy HH:mm');

  static const _estados = ['Pendiente', 'Enviado', 'Entregado', 'Anulado'];

  @override
  void initState() {
    super.initState();
    final ahora = DateTime.now();
    _fechaInicio = DateTime(ahora.year, ahora.month, 1);
    _fechaFin = DateTime(ahora.year, ahora.month, ahora.day);
    _buscar();
  }

  Future<void> _buscar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final finInclusive = DateTime(_fechaFin.year, _fechaFin.month, _fechaFin.day, 23, 59, 59);
      final traslados = await ref.read(trasladoRepositoryProvider).obtenerPorRango(_fechaInicio, finInclusive, estado: _estadoFiltro, idSucursal: _sucursalFiltro);
      if (mounted) setState(() => _traslados = traslados);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo cargar el reporte');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
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
    });
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

  InputDecoration _decoracion(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(fontSize: 12.5),
      filled: true,
      fillColor: const Color(0xFFE8EAF0),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _campoFecha(String label, DateTime valor, bool esInicio) {
    return InkWell(
      onTap: () => _seleccionarFecha(esInicio),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _decoracion(label),
        child: Text(DateFormat('dd/MM/yyyy').format(valor), style: GoogleFonts.poppins(fontSize: 13)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sucursalesAsync = ref.watch(sucursalesActivasProvider);

    return Container(
      color: const Color(0xFFF2F3F7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final esMovil = constraints.maxWidth < 720;
          return Padding(
            padding: EdgeInsets.all(esMovil ? 16 : 28),
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Text('Reporte de Traslados', style: GoogleFonts.poppins(fontSize: esMovil ? 19 : 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                ),
                SliverToBoxAdapter(child: const SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(width: esMovil ? constraints.maxWidth : 160, child: _campoFecha('Desde', _fechaInicio, true)),
                      SizedBox(width: esMovil ? constraints.maxWidth : 160, child: _campoFecha('Hasta', _fechaFin, false)),
                      SizedBox(
                        width: esMovil ? constraints.maxWidth : 180,
                        child: DropdownButtonFormField<String>(
                          initialValue: _estadoFiltro,
                          decoration: _decoracion('Estado (todos)'),
                          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF1A1A1A)),
                          items: _estados.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) => setState(() => _estadoFiltro = v),
                        ),
                      ),
                      sucursalesAsync.when(
                        data: (sucursales) => SizedBox(
                          width: esMovil ? constraints.maxWidth : 200,
                          child: DropdownButtonFormField<String>(
                            initialValue: _sucursalFiltro,
                            decoration: _decoracion('Sucursal (todas)'),
                            style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF1A1A1A)),
                            items: sucursales.map((s) => DropdownMenuItem(value: s.id, child: Text(s.nombre, overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (v) => setState(() => _sucursalFiltro = v),
                          ),
                        ),
                        loading: () => const SizedBox(),
                        error: (e, st) => const SizedBox(),
                      ),
                      SizedBox(
                        height: 46,
                        child: FilledButton.icon(
                          onPressed: _cargando ? null : _buscar,
                          icon: _cargando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.search, size: 18),
                          label: Text('Buscar', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D2B4E), padding: const EdgeInsets.symmetric(horizontal: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(child: const SizedBox(height: 20)),
              ],
              body: Container(
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFB6BCC7), width: 1.2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.13), blurRadius: 24, offset: const Offset(0, 10))]),
                child: _error != null
                    ? Center(child: Text(_error!, style: GoogleFonts.poppins(color: Colors.red)))
                    : (_traslados == null
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D2B4E)))
                        : _traslados!.isEmpty
                            ? Center(child: Text('No hay traslados en este rango', style: GoogleFonts.poppins(color: Colors.grey.shade500)))
                            : ListView.separated(
                                padding: const EdgeInsets.all(14),
                                itemCount: _traslados!.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final t = _traslados![index];
                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFC7CBD3))),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('${t.numero}  ·  ${t.nombreSucursalOrigen} → ${t.nombreSucursalDestino}', style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                                              const SizedBox(height: 4),
                                              Text('${t.fecha != null ? _formatoFecha.format(t.fecha!) : '-'} · ${t.totalItems.toStringAsFixed(0)} unidades · por ${t.usuarioCrea}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(color: _colorEstado(t.estado).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                          child: Text(t.estado, style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w700, color: _colorEstado(t.estado))),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              )),
              ),
            ),
          );
        },
      ),
    );
  }
}
