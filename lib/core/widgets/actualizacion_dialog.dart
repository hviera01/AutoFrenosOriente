import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/actualizacion_service.dart';

/// Diálogo central que avisa que hay una versión nueva publicada. Se abre
/// solo (al iniciar la app, ver AppShell) o a mano desde "Buscar
/// actualizaciones" en el menú (ver SideMenu). "Después" solo cierra el
/// diálogo: no queda nada guardado, así que la próxima vez que se abra la
/// app (o se busque a mano) vuelve a preguntar si la instalada sigue sin
/// ser la más nueva -a propósito, para no complicar el flujo con "no
/// preguntar de nuevo" cuando en este negocio conviene que quede siempre al
/// día-.
Future<void> mostrarDialogoActualizacion(BuildContext context, ActualizacionDisponible actualizacion) {
  return showDialog(
    context: context,
    builder: (context) => PopScope(
      canPop: false,
      child: _ActualizacionDialog(actualizacion: actualizacion),
    ),
  );
}

class _ActualizacionDialog extends StatefulWidget {
  final ActualizacionDisponible actualizacion;
  const _ActualizacionDialog({required this.actualizacion});

  @override
  State<_ActualizacionDialog> createState() => _ActualizacionDialogState();
}

class _ActualizacionDialogState extends State<_ActualizacionDialog> {
  bool _descargando = false;
  double _progreso = 0;
  String? _error;

  Future<void> _actualizar() async {
    setState(() {
      _descargando = true;
      _error = null;
    });
    try {
      await ActualizacionService.descargarEInstalar(
        widget.actualizacion,
        (p) {
          if (mounted) setState(() => _progreso = p);
        },
      );
      // En Windows, si el await termina y seguimos acá, algo falló:
      // descargarEInstalar cierra la app (exit) apenas el instalador queda
      // lanzado. En Android, en cambio, terminar acá es el camino normal
      // -la app sigue corriendo, con la pantalla del instalador de Android
      // encima-: hay que cerrar este diálogo a mano, si no se quedaba
      // pegado mostrando "Descargando..." al 100% para siempre.
      if (!kIsWeb && Platform.isAndroid && mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _descargando = false;
        // En Android, "probá de nuevo" no alcanza si la causa es algo del
        // equipo/ROM que el reintento automático no arregla solo (ver
        // ActualizacionService.descargarEInstalar): por eso acá también se
        // ofrece el link directo de descarga, para que el usuario pueda
        // terminar la actualización a mano con el navegador -que no
        // depende de ningún plugin ni permiso especial de la app- en vez
        // de quedar sin ninguna salida.
        _error = (!kIsWeb && Platform.isAndroid)
            ? 'No se pudo instalar automáticamente. Podés descargarla manualmente abajo.'
            : 'No se pudo descargar la actualización. Probá de nuevo más tarde.';
      });
    }
  }

  Future<void> _descargarManualmente() async {
    final uri = Uri.parse(widget.actualizacion.urlDescarga);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo abrir el navegador. Descargala a mano desde:\n${widget.actualizacion.urlDescarga}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Actualización disponible', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hay una nueva versión (v${widget.actualizacion.version}) disponible para instalar.',
              style: GoogleFonts.poppins(fontSize: 13.5),
            ),
            if (widget.actualizacion.notas.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(widget.actualizacion.notas, style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade600)),
            ],
            if (_descargando) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progreso > 0 ? _progreso : null),
              const SizedBox(height: 6),
              Text('Descargando...', style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey.shade500)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: GoogleFonts.poppins(fontSize: 12, color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: _descargando
          ? const []
          : [
              TextButton(onPressed: () => Navigator.pop(context), child: Text('Después', style: GoogleFonts.poppins())),
              if (_error != null && !kIsWeb && Platform.isAndroid)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF0D2B4E), side: const BorderSide(color: Color(0xFF0D2B4E))),
                  onPressed: _descargarManualmente,
                  child: Text('Descargar manualmente', style: GoogleFonts.poppins()),
                ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D2B4E)),
                onPressed: _actualizar,
                child: Text(_error != null ? 'Reintentar' : 'Actualizar ahora', style: GoogleFonts.poppins()),
              ),
            ],
    );
  }
}
