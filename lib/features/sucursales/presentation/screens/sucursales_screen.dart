import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/sucursal_model.dart';
import '../../providers/sucursales_provider.dart';
import '../widgets/sucursal_form_dialog.dart';

class SucursalesScreen extends ConsumerStatefulWidget {
  const SucursalesScreen({super.key});

  @override
  ConsumerState<SucursalesScreen> createState() => _SucursalesScreenState();
}

class _SucursalesScreenState extends ConsumerState<SucursalesScreen> {
  String _busqueda = '';

  void _abrirFormulario([SucursalModel? sucursal]) {
    showDialog(context: context, builder: (context) => SucursalFormDialog(sucursal: sucursal));
  }

  @override
  Widget build(BuildContext context) {
    final sucursalesAsync = ref.watch(sucursalesStreamProvider);

    return Container(
      color: const Color(0xFFF2F3F7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final esMovil = constraints.maxWidth < 640;
          return Padding(
            padding: EdgeInsets.all(esMovil ? 16 : 28),
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Text('Sucursales', style: GoogleFonts.poppins(fontSize: esMovil ? 19 : 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
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
                child: sucursalesAsync.when(
                  data: (sucursales) {
                    final filtradas = sucursales.where((s) => s.textoBusqueda.toLowerCase().contains(_busqueda.toLowerCase())).toList();

                    if (filtradas.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.store_mall_directory_outlined, size: 56, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('No hay sucursales', style: GoogleFonts.poppins(color: Colors.grey.shade500)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: filtradas.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F8),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                            ),
                            child: Row(
                              children: [
                                Expanded(flex: 3, child: Text('NOMBRE', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600, letterSpacing: 0.5))),
                                if (!esMovil) Expanded(flex: 3, child: Text('DIRECCIÓN', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600, letterSpacing: 0.5))),
                                Expanded(flex: 1, child: Text('ESTADO', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600, letterSpacing: 0.5))),
                                const SizedBox(width: 40),
                              ],
                            ),
                          );
                        }
                        final sucursal = filtradas[index - 1];
                        return Column(
                          children: [
                            if (index > 1) Divider(height: 1, color: Colors.grey.shade200),
                            InkWell(
                              onTap: () => _abrirFormulario(sucursal),
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: esMovil ? 14 : 20, vertical: 14),
                                child: Row(
                                  children: [
                                    Expanded(flex: 3, child: Text(sucursal.nombre, style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A)), overflow: TextOverflow.ellipsis)),
                                    if (!esMovil)
                                      Expanded(
                                        flex: 3,
                                        child: Text(sucursal.direccion.isEmpty ? '-' : sucursal.direccion, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
                                      ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        constraints: const BoxConstraints(maxWidth: 80),
                                        decoration: BoxDecoration(color: sucursal.estado ? const Color(0xFFE8F8EE) : Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                                        child: Text(
                                          sucursal.estado ? 'Activo' : 'Inactivo',
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: sucursal.estado ? const Color(0xFF16A34A) : Colors.grey.shade600),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 30, child: Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
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
                hintText: 'Buscar por nombre o dirección...',
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
      onPressed: () => ref.invalidate(sucursalesStreamProvider),
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
      label: Text('Nueva Sucursal', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF0D2B4E),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
