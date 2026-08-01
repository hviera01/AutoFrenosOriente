import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/actualizacion_provider.dart';
import '../providers/tabs_provider.dart';
import '../models/tab_item.dart';
import '../services/actualizacion_service.dart';
import '../widgets/actualizacion_dialog.dart';
import '../widgets/side_menu.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/dispositivos/providers/dispositivos_provider.dart';
import '../version_app.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/negocio/providers/negocio_provider.dart';
import '../../features/productos/providers/productos_provider.dart';
import '../../features/traslados/data/impresion_en_vivo_traslado_service.dart';
import '../../features/traslados/data/traslado_model.dart';
import '../../features/traslados/providers/traslados_provider.dart';
import '../../features/ventas/data/impresion_en_vivo_service.dart';
import '../../features/ventas/data/venta_model.dart';
import '../../features/ventas/providers/ventas_provider.dart';
import '../services/tipografia_service.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _menuAbierto = false;

  // Esta es "la PC principal" (con impresora térmica conectada) solo cuando
  // corre como app de escritorio nativa: ni en el navegador (ahí no hay
  // forma de mandar un PDF directo a una impresora sin diálogo) ni en el
  // celular. Solo esta plataforma envía latido de presencia y procesa
  // solicitudes de impresión en vivo, ver PresenciaImpresionRepository.
  final bool _esPcPrincipal = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
  Timer? _latidoTimer;
  Timer? _actualizacionTimer;
  bool _dialogoActualizacionAbierto = false;
  final _servicioImpresionEnVivo = ImpresionEnVivoService();
  final _servicioImpresionEnVivoTraslado = ImpresionEnVivoTrasladoService();
  final _idsSolicitudEnProceso = <String>{};
  final _idsSolicitudTrasladoEnProceso = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tabsState = ref.read(tabsProvider);
      if (tabsState.tabs.isEmpty) {
        ref.read(tabsProvider.notifier).abrirTab(
          TabItem(
            id: 'inicio',
            titulo: 'Inicio',
            icono: Icons.home_outlined,
            contenido: const HomeScreen(),
            cerrable: false,
          ),
        );
      }
    });

    if (_esPcPrincipal) {
      final presencia = ref.read(presenciaImpresionRepositoryProvider);
      presencia.enviarLatido();
      _latidoTimer = Timer.periodic(const Duration(seconds: 25), (_) => presencia.enviarLatido());
    }

    // Reporta este equipo (versión instalada + quién inició sesión) al
    // módulo de Dispositivos. Silencioso: ver DispositivoRepository.reportar.
    final usuario = ref.read(authProvider).usuario;
    ref.read(dispositivoRepositoryProvider).reportar(versionApp: versionApp, usuario: usuario?.nombreCompleto ?? '');

    // Solo en Windows/Android: ver ActualizacionService. No bloquea el
    // arranque -si no hay internet o GitHub no responde a tiempo, sigue de
    // largo sin avisar nada-. Además de una vez al abrir la app, se repite
    // cada 10 minutos mientras quede abierta: así, si alguien deja la app
    // abierta todo el día y se publica una versión nueva mientras tanto, el
    // aviso igual le llega sin que tenga que cerrar y volver a abrir.
    if (ActualizacionService.aplica) {
      _chequearActualizacion();
      _actualizacionTimer = Timer.periodic(const Duration(minutes: 10), (_) => _chequearActualizacion());
    }
  }

  Future<void> _chequearActualizacion() async {
    if (_dialogoActualizacionAbierto) return;
    final actualizacion = await ActualizacionService.buscarActualizacion();
    if (actualizacion == null || !mounted) return;
    ref.read(actualizacionDisponibleProvider.notifier).establecer(actualizacion);
    _dialogoActualizacionAbierto = true;
    await mostrarDialogoActualizacion(context, actualizacion);
    _dialogoActualizacionAbierto = false;
  }

  @override
  void dispose() {
    _latidoTimer?.cancel();
    _actualizacionTimer?.cancel();
    super.dispose();
  }

  // Se dispara sola apenas una venta hecha desde el celular pide impresión
  // en vivo (ver RegistrarVentaScreen). No pregunta nada: imprime directo
  // en la impresora configurada en esta PC, sin ningún diálogo. Si falla o
  // no hay impresora configurada, no insiste: la venta ya había quedado
  // como pendienteImpresion, así que sigue disponible ahí para resolverla
  // a mano.
  Future<void> _procesarSolicitudImpresionEnVivo(VentaModel venta) async {
    if (_idsSolicitudEnProceso.contains(venta.id)) return;
    _idsSolicitudEnProceso.add(venta.id);
    try {
      final ventaRepo = ref.read(ventaRepositoryProvider);
      // [venta] ya llegó completa del stream salvo el detalle (que el
      // stream no trae, ver obtenerVentasConSolicitudImpresionEnVivo) —
      // incluida la elección de copia/original, así que no hace falta
      // releer el documento entero de nuevo: alcanza con pedir el detalle.
      // Esa lectura y la del negocio no dependen una de la otra, así que
      // van juntas; la limpieza de la solicitud tampoco espera a nada de
      // esto. Entre los tres ahorros (menos vueltas a Firestore, en
      // paralelo, sin esperar la limpieza) la impresión sale lo antes
      // posible.
      unawaited(ventaRepo.marcarSolicitudImpresionEnVivo(venta.id, false));
      final futureDetalle = ventaRepo.obtenerDetalleVenta(venta.id);
      final futureNegocio = ref.read(negocioRepositoryProvider).obtenerNegocioActual();
      final detalle = await futureDetalle;
      final negocio = await futureNegocio;
      final ventaCompleta = venta.copyWith(detalle: detalle);
      final ok = await _servicioImpresionEnVivo.imprimirSilencioso(ventaCompleta, negocio, forzarCopia: ventaCompleta.solicitudImpresionEsCopia);
      if (ok) {
        await ventaRepo.marcarPendienteImpresion(venta.id, false);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Venta ${ventaCompleta.numeroDocumento} recibida desde el celular: no se pudo imprimir automáticamente, quedó en Pendientes de Impresión.'),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      _idsSolicitudEnProceso.remove(venta.id);
    }
  }

  // Mismo patrón que _procesarSolicitudImpresionEnVivo (ventas), aplicado a
  // traslados: se dispara sola apenas un traslado registrado desde el
  // celular/web móvil pide impresión en vivo (ver RegistrarTrasladoScreen y
  // DetalleTrasladoScreen). Sin diálogo ni confirmación.
  Future<void> _procesarSolicitudImpresionEnVivoTraslado(TrasladoModel traslado) async {
    if (_idsSolicitudTrasladoEnProceso.contains(traslado.id)) return;
    _idsSolicitudTrasladoEnProceso.add(traslado.id);
    try {
      final trasladoRepo = ref.read(trasladoRepositoryProvider);
      unawaited(trasladoRepo.marcarSolicitudImpresionEnVivo(traslado.id, false));
      final futureCompleto = trasladoRepo.obtenerPorId(traslado.id);
      final futureNegocio = ref.read(negocioRepositoryProvider).obtenerNegocioActual();
      // Por si el stream de productos todavía no trajo el primer valor (la
      // PC principal recién abierta, por ejemplo): esperar antes de armar el
      // mapa de códigos, mismo criterio que en las pantallas de traslado.
      if (ref.read(productosStreamProvider).value == null) {
        try {
          await ref.read(productosStreamProvider.future);
        } catch (_) {}
      }
      final productos = ref.read(productosStreamProvider).value ?? [];
      final codigos = {for (final p in productos) p.id: p.codigo};
      final trasladoCompleto = await futureCompleto;
      final negocio = await futureNegocio;
      if (trasladoCompleto == null) return;
      final ok = await _servicioImpresionEnVivoTraslado.imprimirSilencioso(
        trasladoCompleto,
        negocio,
        codigos,
        forzarCopia: traslado.solicitudImpresionEsCopia,
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Traslado ${trasladoCompleto.numero} recibido desde el celular: no se pudo imprimir automáticamente.'),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      _idsSolicitudTrasladoEnProceso.remove(traslado.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabsState = ref.watch(tabsProvider);
    final authState = ref.watch(authProvider);
    final usuario = authState.usuario;
    // Escuchado acá (además de en SistemaVentasApp) para que las pestañas ya
    // abiertas -guardadas como Widget ya construido en tabsProvider- también
    // se reconstruyan con la fuente nueva. Ver KeyedSubtree más abajo: sin
    // eso, Flutter reconoce el mismo Widget de siempre y no la aplica hasta
    // reabrir la app.
    final fuente = ref.watch(tipografiaProvider);

    if (_esPcPrincipal) {
      ref.listen<AsyncValue<List<VentaModel>>>(ventasConSolicitudImpresionEnVivoStreamProvider, (previous, next) {
        for (final venta in next.value ?? const <VentaModel>[]) {
          unawaited(_procesarSolicitudImpresionEnVivo(venta));
        }
      });
      ref.listen<AsyncValue<List<TrasladoModel>>>(trasladosConSolicitudImpresionEnVivoStreamProvider, (previous, next) {
        for (final traslado in next.value ?? const <TrasladoModel>[]) {
          unawaited(_procesarSolicitudImpresionEnVivoTraslado(traslado));
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      body: Stack(
        children: [
          Column(
            children: [
              _barraSuperior(usuario),
              _barraPestanas(tabsState),
              Expanded(
                child: tabsState.tabs.isEmpty
                    ? const SizedBox()
                    : IndexedStack(
                        index: tabsState.indiceActivo,
                        // Key con la fuente actual: fuerza a reconstruir cada
                        // pestaña desde cero cuando cambia (t.contenido es el
                        // mismo Widget guardado en tabsProvider desde que se
                        // abrió, así que sin esto Flutter lo da por igual y
                        // no vuelve a llamar a su build()).
                        children: tabsState.tabs.map((t) => KeyedSubtree(key: ValueKey('${t.id}_$fuente'), child: t.contenido)).toList(),
                      ),
              ),
            ],
          ),
          if (_menuAbierto)
            GestureDetector(
              onTap: () => setState(() => _menuAbierto = false),
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            left: _menuAbierto ? 0 : -300,
            top: 0,
            bottom: 0,
            child: SideMenu(onCerrar: () => setState(() => _menuAbierto = false)),
          ),
        ],
      ),
    );
  }

  // El cambio de fuente ya no se aplica solo con tocar una opción (pedido
  // explícito del usuario, tras un caso real donde el cambio parecía no
  // aplicarse): ahora hay que elegir y confirmar con "Aplicar", y al aplicar
  // se muestra un aviso confirmando que se hizo.
  Future<void> _abrirSelectorTipografia() async {
    var seleccion = ref.read(tipografiaProvider);
    final aplicar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialogo) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Tipografía del sistema', style: appFont(fontWeight: FontWeight.w700)),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: tipografiasDisponibles.entries.map((e) {
                  return RadioListTile<String>(
                    value: e.key,
                    // ignore: deprecated_member_use
                    groupValue: seleccion,
                    activeColor: const Color(0xFF0D2B4E),
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.value, style: GoogleFonts.getFont(e.key, fontSize: 14.5)),
                    // ignore: deprecated_member_use
                    onChanged: (v) => setStateDialogo(() => seleccion = v ?? seleccion),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancelar', style: appFont())),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D2B4E)),
                onPressed: () => Navigator.pop(context, true),
                child: Text('Aplicar', style: appFont(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
    if (aplicar != true || !mounted) return;
    await ref.read(tipografiaProvider.notifier).establecer(seleccion);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tipografía aplicada: ${tipografiasDisponibles[seleccion] ?? seleccion}'), duration: const Duration(seconds: 3)),
    );
  }

 Widget _barraSuperior(dynamic usuario) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(color: Color(0xFF0D2B4E)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final esAngosto = constraints.maxWidth < 420;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: () => setState(() => _menuAbierto = !_menuAbierto),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                        // logo_redondo.png ya viene recortado en círculo con
                        // transparencia real (ver login_screen.dart).
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Image.asset('assets/images/logo_redondo.png', fit: BoxFit.contain),
                        ),
                      ),
                      if (!esAngosto) ...[
                        const SizedBox(width: 12),
                        Text(
                          'AUTO FRENOS ORIENTE',
                          style: appFont(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1),
                        ),
                      ],
                    ],
                  ),
                ),
                if (usuario != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: Text(
                          usuario.nombreCompleto.isNotEmpty ? usuario.nombreCompleto[0].toUpperCase() : '?',
                          style: appFont(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (!esAngosto) ...[
                        const SizedBox(width: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                usuario.nombreCompleto,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: appFont(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                usuario.rol,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: appFont(color: Colors.white.withOpacity(0.75), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.font_download_outlined, color: Colors.white, size: 20),
                        tooltip: 'Tipografía',
                        onPressed: _abrirSelectorTipografia,
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white, size: 20),
                        tooltip: 'Cerrar sesión',
                        onPressed: () => ref.read(authProvider.notifier).logout(),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _barraPestanas(TabsState tabsState) {
    return Container(
      height: 44,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: tabsState.tabs.length,
        itemBuilder: (context, index) {
          final tab = tabsState.tabs[index];
          final activo = index == tabsState.indiceActivo;
          return GestureDetector(
            onTap: () => ref.read(tabsProvider.notifier).seleccionarTab(index),
            child: Container(
              margin: const EdgeInsets.only(right: 6, top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: activo ? const Color(0xFFE6E9F2) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: activo ? Border.all(color: const Color(0xFF0D2B4E).withOpacity(0.25)) : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab.icono, size: 16, color: activo ? const Color(0xFF0D2B4E) : Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Text(
                    tab.titulo,
                    style: appFont(
                      fontSize: 12.5,
                      color: activo ? const Color(0xFF0D2B4E) : Colors.grey.shade600,
                      fontWeight: activo ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (tab.cerrable) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => ref.read(tabsProvider.notifier).cerrarTab(tab.id),
                      child: Icon(Icons.close, size: 14, color: Colors.grey.shade400),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}