import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/dispositivos_provider.dart';
import '../../data/dispositivo_model.dart';
import '../../../../core/services/actualizacion_service.dart';
import '../../../../core/services/tipografia_service.dart';

/// Ancho por debajo del cual se muestra una lista de cards apiladas en vez
/// de la tabla de columnas -en pantallas angostas (celular, ventana chica)
/// la tabla de columnas fijas quedaba con texto cortado e ilegible.
const _anchoAngosto = 700.0;

class DispositivosScreen extends ConsumerStatefulWidget {
  const DispositivosScreen({super.key});

  @override
  ConsumerState<DispositivosScreen> createState() => _DispositivosScreenState();
}

class _DispositivosScreenState extends ConsumerState<DispositivosScreen> {
  int? _ultimaVersionPublicada;

  @override
  void initState() {
    super.initState();
    ActualizacionService.obtenerUltimaVersionPublicada().then((v) {
      if (mounted) setState(() => _ultimaVersionPublicada = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dispositivosAsync = ref.watch(dispositivosStreamProvider);
    final formatoFecha = DateFormat('dd/MM/yyyy hh:mm a');

    return LayoutBuilder(
      builder: (context, constraints) {
        final angosto = constraints.maxWidth < _anchoAngosto;
        final padding = angosto ? 14.0 : 26.0;

        return Container(
          color: const Color(0xFFF2F3F7),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    Text('Dispositivos', style: appFont(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                    if (_ultimaVersionPublicada != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(10)),
                        child: Text('Última versión publicada: v$_ultimaVersionPublicada', style: appFont(fontSize: 12.5, color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Cada equipo actualiza este registro solo al iniciar sesión: si alguien no ha abierto la app en un tiempo, su fila va a quedar vieja.',
                  style: appFont(fontSize: 12.5, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFAEB4C0), width: 1.3),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 26, offset: const Offset(0, 12))],
                    ),
                    child: dispositivosAsync.when(
                      data: (dispositivos) {
                        if (dispositivos.isEmpty) {
                          return Center(
                            child: Text('Todavía no hay dispositivos registrados', style: appFont(color: Colors.grey.shade500)),
                          );
                        }
                        return angosto
                            ? _listaCards(dispositivos, formatoFecha)
                            : _tabla(dispositivos, formatoFecha);
                      },
                      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0D2B4E))),
                      error: (e, st) => Center(child: Text('Error: $e', style: appFont(color: Colors.red))),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _desactualizado(DispositivoModel d) => _ultimaVersionPublicada != null && d.versionApp < _ultimaVersionPublicada!;

  Widget _badgeVersion(DispositivoModel d) {
    final desactualizado = _desactualizado(d);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: desactualizado ? const Color(0xFFFCE4E4) : const Color(0xFFE8F8EE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('v${d.versionApp}', style: appFont(fontSize: 12, fontWeight: FontWeight.w700, color: desactualizado ? const Color(0xFFB91C1C) : const Color(0xFF16A34A))),
          if (desactualizado) ...[
            const SizedBox(width: 4),
            const Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFB91C1C)),
          ],
        ],
      ),
    );
  }

  // Tabla de columnas para pantallas anchas (escritorio/tablet): igual al
  // diseño original.
  Widget _tabla(List<DispositivoModel> dispositivos, DateFormat formatoFecha) {
    return ListView.builder(
      itemCount: dispositivos.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: const Color(0xFFECEEF3), borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
            child: Row(
              children: [
                _celdaHeader('DISPOSITIVO', 3),
                _celdaHeader('PLATAFORMA', 2),
                _celdaHeader('VERSIÓN', 2),
                _celdaHeader('ÚLTIMO USUARIO', 2),
                _celdaHeader('ÚLTIMA CONEXIÓN', 3),
              ],
            ),
          );
        }
        final d = dispositivos[index - 1];
        return Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _celda(3, d.id, peso: FontWeight.w600),
              _celda(2, d.plataforma),
              Expanded(flex: 2, child: _badgeVersion(d)),
              _celda(2, d.usuario.isEmpty ? '-' : d.usuario),
              _celda(3, d.ultimaConexion != null ? formatoFecha.format(d.ultimaConexion!) : '-', gris: true),
            ],
          ),
        );
      },
    );
  }

  // Cards apiladas para pantallas angostas: cada campo en su propia línea,
  // sin truncar con ellipsis -en vez de forzar 5 columnas en poco ancho-.
  Widget _listaCards(List<DispositivoModel> dispositivos, DateFormat formatoFecha) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: dispositivos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final d = dispositivos[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(d.id, style: appFont(fontSize: 14.5, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                  ),
                  _badgeVersion(d),
                ],
              ),
              const SizedBox(height: 10),
              _filaCard('Plataforma', d.plataforma),
              _filaCard('Último usuario', d.usuario.isEmpty ? '-' : d.usuario),
              _filaCard('Última conexión', d.ultimaConexion != null ? formatoFecha.format(d.ultimaConexion!) : '-'),
            ],
          ),
        );
      },
    );
  }

  Widget _filaCard(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(etiqueta, style: appFont(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(valor, style: appFont(fontSize: 12.5, color: const Color(0xFF1A1A1A))),
          ),
        ],
      ),
    );
  }

  Widget _celdaHeader(String texto, int flex) {
    return Expanded(
      flex: flex,
      child: Text(texto, maxLines: 1, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF666A72), letterSpacing: 0.3)),
    );
  }

  Widget _celda(int flex, String texto, {bool gris = false, FontWeight peso = FontWeight.w400}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Text(texto, maxLines: 1, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 12.5, fontWeight: peso, color: gris ? Colors.grey.shade600 : const Color(0xFF1A1A1A))),
      ),
    );
  }
}
