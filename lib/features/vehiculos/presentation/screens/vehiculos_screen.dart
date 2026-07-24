import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/vehiculo_model.dart';
import '../../providers/vehiculos_provider.dart';
import '../widgets/vehiculo_form_dialog.dart';

class VehiculosScreen extends ConsumerStatefulWidget {
  const VehiculosScreen({super.key});

  @override
  ConsumerState<VehiculosScreen> createState() => _VehiculosScreenState();
}

class _VehiculosScreenState extends ConsumerState<VehiculosScreen> {
  String _busqueda = '';

  void _abrirFormulario([VehiculoModel? vehiculo]) {
    showDialog(context: context, builder: (context) => VehiculoFormDialog(vehiculo: vehiculo));
  }

  @override
  Widget build(BuildContext context) {
    final vehiculosAsync = ref.watch(vehiculosStreamProvider);

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
                  child: Text('Vehículos', style: GoogleFonts.poppins(fontSize: esMovil ? 19 : 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                ),
                SliverToBoxAdapter(child: const SizedBox(height: 4)),
                SliverToBoxAdapter(
                  child: Text('Registro de vehículos por cliente, para elegirlos rápido al facturar', style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade600)),
                ),
                SliverToBoxAdapter(child: const SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: esMovil
                      ? Column(
                          children: [
                            _buscador(),
                            const SizedBox(height: 12),
                            Row(children: [Expanded(child: _botonRefrescar()), const SizedBox(width: 10), Expanded(child: _botonNuevo())]),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: _buscador()),
                            const SizedBox(width: 12),
                            _botonRefrescar(),
                            const SizedBox(width: 12),
                            _botonNuevo(),
                          ],
                        ),
                ),
                SliverToBoxAdapter(child: const SizedBox(height: 20)),
              ],
              body: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFB6BCC7), width: 1.2),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.13), blurRadius: 24, offset: const Offset(0, 10))],
                ),
                child: vehiculosAsync.when(
                  data: (vehiculos) {
                    final filtrados = vehiculos.where((v) => v.textoBusqueda.toLowerCase().contains(_busqueda.toLowerCase())).toList();

                    if (filtrados.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.directions_car_filled_outlined, size: 56, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(_busqueda.isEmpty ? 'No hay vehículos registrados' : 'No se encontraron vehículos', style: GoogleFonts.poppins(color: Colors.grey.shade500)),
                          ],
                        ),
                      );
                    }

                    return esMovil ? _tarjetas(filtrados) : _tabla(filtrados);
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0D2B4E))),
                  error: (e, st) => Center(child: Text('Error: $e', style: GoogleFonts.poppins(color: Colors.red))),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tabla(List<VehiculoModel> lista) {
    return ListView.builder(
      itemCount: lista.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: const Color(0xFFECEEF3), borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
            child: Row(
              children: [
                _celdaHeader('CLIENTE', 3),
                _celdaHeader('MARCA / MODELO', 3),
                _celdaHeader('AÑO', 1),
                _celdaHeader('PLACA', 2),
                const SizedBox(width: 40),
              ],
            ),
          );
        }
        final v = lista[index - 1];
        return Column(
          children: [
            if (index > 1) Divider(height: 1, color: Colors.grey.shade200),
            InkWell(
              onTap: () => _abrirFormulario(v),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    _celda(3, v.nombreCliente.isEmpty ? '-' : v.nombreCliente, peso: FontWeight.w600),
                    _celda(3, '${v.marca} ${v.modelo}'.trim()),
                    _celda(1, v.anio.isEmpty ? '-' : v.anio, gris: true),
                    _celda(2, v.placa.isEmpty ? '-' : v.placa, gris: true),
                    SizedBox(width: 40, child: Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _celdaHeader(String texto, int flex) {
    return Expanded(
      flex: flex,
      child: Text(texto, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF666A72), letterSpacing: 0.35)),
    );
  }

  Widget _celda(int flex, String texto, {bool gris = false, FontWeight peso = FontWeight.w400}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Text(texto, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: peso, color: gris ? Colors.grey.shade600 : const Color(0xFF1A1A1A))),
      ),
    );
  }

  Widget _tarjetas(List<VehiculoModel> lista) {
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: lista.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final v = lista[index];
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _abrirFormulario(v),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFC7CBD3))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.nombreCliente.isEmpty ? 'Sin cliente' : v.nombreCliente, style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chipInfo('Vehículo', '${v.marca} ${v.modelo}'.trim()),
                    if (v.anio.isNotEmpty) _chipInfo('Año', v.anio),
                    if (v.placa.isNotEmpty) _chipInfo('Placa', v.placa),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chipInfo(String label, String valor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFE8EAF0), borderRadius: BorderRadius.circular(8)),
      child: Text('$label: $valor', style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF3F434A))),
    );
  }

  Widget _buscador() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 46,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFB6BCC7))),
      child: Row(
        children: [
          Icon(Icons.search, size: 20, color: Colors.grey.shade400),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              style: GoogleFonts.poppins(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Buscar por cliente, marca, modelo o placa...',
                hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (v) => setState(() => _busqueda = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonRefrescar() {
    return OutlinedButton.icon(
      onPressed: () => ref.invalidate(vehiculosStreamProvider),
      icon: const Icon(Icons.refresh, size: 18),
      label: Text('Refrescar', style: GoogleFonts.poppins(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1A1A1A),
        side: const BorderSide(color: Color(0xFFB6BCC7)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _botonNuevo() {
    return FilledButton.icon(
      onPressed: () => _abrirFormulario(),
      icon: const Icon(Icons.add, size: 18),
      label: Text('Nuevo Vehículo', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF0D2B4E),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
