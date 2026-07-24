import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/traslado_model.dart';
import '../../providers/traslados_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../widgets/traslado_form_dialog.dart';

class TrasladosScreen extends ConsumerStatefulWidget {
  const TrasladosScreen({super.key});

  @override
  ConsumerState<TrasladosScreen> createState() => _TrasladosScreenState();
}

class _TrasladosScreenState extends ConsumerState<TrasladosScreen> {
  final _formatoFecha = DateFormat('dd/MM/yyyy HH:mm');

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  void _nuevoTraslado() {
    showDialog(context: context, builder: (context) => const TrasladoFormDialog());
  }

  Future<void> _enviar(TrasladoModel t) async {
    try {
      await ref.read(trasladoRepositoryProvider).enviar(t.id);
      _mostrarMensaje('Traslado ${t.numero} marcado como Enviado');
    } catch (e) {
      _mostrarMensaje(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _recepcionar(TrasladoModel t) async {
    try {
      final usuario = ref.read(authProvider).usuario?.nombreCompleto ?? '';
      await ref.read(trasladoRepositoryProvider).recepcionar(t.id, usuarioRecibe: usuario);
      _mostrarMensaje('Traslado ${t.numero} marcado como Entregado');
    } catch (e) {
      _mostrarMensaje(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _anular(TrasladoModel t) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Anular traslado', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('¿Seguro que querés anular el traslado ${t.numero}?', style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancelar', style: GoogleFonts.poppins())),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Anular', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await ref.read(trasladoRepositoryProvider).anular(t.id);
      _mostrarMensaje('Traslado ${t.numero} anulado');
    } catch (e) {
      _mostrarMensaje(e.toString().replaceAll('Exception: ', ''));
    }
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
    final trasladosAsync = ref.watch(trasladosStreamProvider);

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
                  child: Text('Traslados', style: GoogleFonts.poppins(fontSize: esMovil ? 19 : 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                ),
                SliverToBoxAdapter(child: const SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => ref.invalidate(trasladosStreamProvider),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text('Refrescar', style: GoogleFonts.poppins(fontSize: 13)),
                        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1A1A1A), side: const BorderSide(color: Color(0xFFB6BCC7)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _nuevoTraslado,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text('Nuevo Traslado', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D2B4E), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(child: const SizedBox(height: 20)),
              ],
              body: Container(
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFB6BCC7), width: 1.2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.13), blurRadius: 24, offset: const Offset(0, 10))]),
                child: trasladosAsync.when(
                  data: (traslados) {
                    if (traslados.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sync_alt_outlined, size: 56, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('No hay traslados registrados', style: GoogleFonts.poppins(color: Colors.grey.shade500)),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(14),
                      itemCount: traslados.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final t = traslados[index];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFC7CBD3))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text('${t.numero}  ·  ${t.nombreSucursalOrigen} → ${t.nombreSucursalDestino}', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)), overflow: TextOverflow.ellipsis),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(color: _colorEstado(t.estado).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                    child: Text(t.estado, style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w700, color: _colorEstado(t.estado))),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${t.fecha != null ? _formatoFecha.format(t.fecha!) : '-'} · ${t.totalItems.toStringAsFixed(0)} unidades · ${t.detalle.length} producto(s) · por ${t.usuarioCrea}',
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              if (t.observaciones.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(t.observaciones, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                              ],
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ...t.detalle.map((i) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(color: const Color(0xFFE8EAF0), borderRadius: BorderRadius.circular(8)),
                                        child: Text('${i.nombreProducto} × ${i.cantidad.toStringAsFixed(i.cantidad == i.cantidad.roundToDouble() ? 0 : 2)}', style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF3F434A))),
                                      )),
                                ],
                              ),
                              if (t.estado == 'Pendiente' || t.estado == 'Enviado') ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    if (t.estado == 'Pendiente')
                                      OutlinedButton.icon(
                                        onPressed: () => _enviar(t),
                                        icon: const Icon(Icons.local_shipping_outlined, size: 16),
                                        label: Text('Marcar Enviado', style: GoogleFonts.poppins(fontSize: 12)),
                                        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF3B82F6), side: const BorderSide(color: Color(0xFF3B82F6))),
                                      ),
                                    if (t.estado == 'Enviado') ...[
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        onPressed: () => _recepcionar(t),
                                        icon: const Icon(Icons.check_circle_outline, size: 16),
                                        label: Text('Confirmar Recepción', style: GoogleFonts.poppins(fontSize: 12)),
                                        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF16A34A), side: const BorderSide(color: Color(0xFF16A34A))),
                                      ),
                                    ],
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: () => _anular(t),
                                      icon: const Icon(Icons.cancel_outlined, size: 16),
                                      label: Text('Anular', style: GoogleFonts.poppins(fontSize: 12)),
                                      style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
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
}
