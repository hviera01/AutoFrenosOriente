import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/traslado_model.dart';
import '../../../negocio/data/negocio_model.dart';
import '../../../../core/utils/texto_utils.dart';

/// Reproduce en pantalla, con widgets normales de Flutter (no un PDF), el
/// mismo contenido y el mismo orden que imprime de verdad
/// TrasladoTicketEscPosService en la impresora térmica -la vía que se usa en
/// Windows, ver PdfPreviewDialog-. No es pixel-perfecto (una impresora
/// térmica real usa su propia tipografía de matriz de puntos), pero muestra
/// las mismas secciones, los mismos datos y en el mismo orden, a diferencia
/// de la vista previa en PDF -que en ese camino ya no es lo que de verdad se
/// manda a imprimir-.
class TrasladoTicketEscPosPreview extends StatelessWidget {
  final TrasladoModel traslado;
  final NegocioModel negocio;
  final Map<String, String> codigosPorProducto;
  final bool esCopia;

  const TrasladoTicketEscPosPreview({
    super.key,
    required this.traslado,
    required this.negocio,
    required this.codigosPorProducto,
    required this.esCopia,
  });

  @override
  Widget build(BuildContext context) {
    const estiloBase = TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black, height: 1.35);
    final formatoFecha = DateFormat('dd/MM/yyyy HH:mm');

    // quitarTildes acá también: esta vista previa tiene que mostrar
    // exactamente lo que va a salir impreso.
    Widget linea(String texto, {bool centrado = false, bool negrita = false, double tamano = 12}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Text(
          quitarTildes(texto),
          textAlign: centrado ? TextAlign.center : TextAlign.left,
          style: estiloBase.copyWith(fontWeight: negrita ? FontWeight.bold : FontWeight.normal, fontSize: tamano),
        ),
      );
    }

    Widget fila(String izquierda, String derecha, {bool negrita = false}) {
      final estilo = estiloBase.copyWith(fontWeight: negrita ? FontWeight.bold : FontWeight.normal);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: [
            Expanded(child: Text(quitarTildes(izquierda), style: estilo)),
            Text(quitarTildes(derecha), style: estilo),
          ],
        ),
      );
    }

    Widget separador() => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(height: 1, color: Colors.black26),
        );

    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          fila(negocio.nombre.isEmpty ? 'MI NEGOCIO' : negocio.nombre.toUpperCase(), esCopia ? 'COPIA' : 'ORIGINAL', negrita: true),
          linea('TRASLADO', centrado: true, negrita: true, tamano: 16),
          separador(),
          linea('No: ${traslado.numero}'),
          linea('Fecha: ${traslado.fecha != null ? formatoFecha.format(traslado.fecha!) : '-'}'),
          linea('Estado: ${traslado.estado.toUpperCase()}'),
          linea('Sucursal origen: ${traslado.nombreSucursalOrigen}'),
          linea('Sucursal destino: ${traslado.nombreSucursalDestino}'),
          linea('Usuario crea: ${traslado.usuarioCrea.isEmpty ? '-' : traslado.usuarioCrea}'),
          linea('Usuario recibe: ${traslado.usuarioRecibe.isEmpty ? '-' : traslado.usuarioRecibe}'),
          separador(),
          Row(
            children: [
              SizedBox(width: 60, child: Text('CODIGO', style: estiloBase.copyWith(fontWeight: FontWeight.bold))),
              const SizedBox(width: 14),
              Expanded(child: Text('DESCRIPCION', style: estiloBase.copyWith(fontWeight: FontWeight.bold))),
              Text('CANT', style: estiloBase.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          separador(),
          for (final item in traslado.detalle) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 60, child: Text(quitarTildes(codigosPorProducto[item.idProducto] ?? ''), style: estiloBase)),
                const SizedBox(width: 14),
                Expanded(child: Text(quitarTildes(item.nombreProducto), style: estiloBase)),
                Text(_formatoCantidad(item.cantidad), style: estiloBase.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            linea('Ubicacion: ${item.ubicacion.trim().isEmpty ? '-' : item.ubicacion}', negrita: true),
            const SizedBox(height: 18),
          ],
          separador(),
          if (traslado.observaciones.isNotEmpty) ...[
            linea('OBSERVACIONES:', negrita: true),
            linea(traslado.observaciones),
            separador(),
          ],
          const SizedBox(height: 16),
          linea('________________________________'),
          linea('Entrega Origen'),
          const SizedBox(height: 12),
          linea('________________________________'),
          linea('Recibe Destino'),
          separador(),
          linea('Documento generado por el sistema', centrado: true),
        ],
      ),
    );
  }

  String _formatoCantidad(double cantidad) {
    if (cantidad == cantidad.roundToDouble()) return cantidad.toInt().toString();
    return cantidad.toStringAsFixed(2);
  }
}
