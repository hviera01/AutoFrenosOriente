import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import '../../data/venta_model.dart';
import '../../data/numero_a_letras.dart';
import '../../data/venta_ticket_escpos_service.dart';
import '../../../negocio/data/negocio_model.dart';
import '../../../../core/utils/formato_moneda.dart';
import '../../../../core/utils/logo_escpos.dart';
import '../../../../core/utils/texto_utils.dart';

class TicketEscPosPreview extends StatelessWidget {
  final VentaModel venta;
  final NegocioModel negocio;
  final bool esCopia;

  const TicketEscPosPreview({super.key, required this.venta, required this.negocio, required this.esCopia});

  @override
  Widget build(BuildContext context) {
    const estiloBase = TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black, height: 1.35);
    final formatoFecha = DateFormat('dd/MM/yyyy hh:mm a');
    final formatoDia = DateFormat('dd/MM/yyyy');
    final esFactura = venta.tipoDocumento == 'Factura';
    final es58 = negocio.anchoTicketMm <= 60;

    final esFacturable = venta.llevaIsv;
    final mostrarConIsv = esFacturable && negocio.facturaPreciosConIsv;
    double precioMostrado(dynamic item) => mostrarConIsv ? redondearMoneda((item.precioVenta as double) * 1.15) : item.precioVenta as double;
    double importeMostrado(dynamic item) {
      if (!mostrarConIsv) return item.subtotal as double;
      final precio = precioMostrado(item);
      return redondearMoneda(precio * (item.cantidad as double) * (1 - (item.descuentoPorcentaje as double) / 100));
    }

    final descuentosYRebajas = venta.descuentosYRebajas;
    final recargo = montoRecargoTarjetaVenta(venta);

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

    Widget nombreProducto(String texto) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 8, child: Text(quitarTildes(texto), style: estiloBase)),
            const Expanded(flex: 4, child: SizedBox()),
          ],
        ),
      );
    }

    final logoDecodificado = negocio.logoEnTicket ? decodificarLogoEscPos(negocio.logoBnBase64, maxDimension: es58 ? 130 : 180) : null;
    final Uint8List? logoBytes = logoDecodificado == null ? null : Uint8List.fromList(img.encodePng(logoDecodificado));
    final anchoContenedor = es58 ? 320.0 * 384 / 576 : 320.0;

    return Container(
      width: anchoContenedor,
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (logoBytes != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Center(child: Image.memory(logoBytes, width: 100, filterQuality: FilterQuality.none)),
            ),
          if (negocio.nombre.isNotEmpty) linea(negocio.nombre.toUpperCase().trim(), centrado: true, negrita: true, tamano: 15),
          if (negocio.eslogan.isNotEmpty) linea(negocio.eslogan, centrado: true),
          if (negocio.direccion.isNotEmpty) linea('Dirección: ${negocio.direccion}', centrado: true),
          if (negocio.rtn.isNotEmpty) linea('RTN: ${negocio.rtn}', centrado: true),
          if (negocio.telefono.isNotEmpty) linea('Tel: ${negocio.telefono}', centrado: true),
          if (negocio.correo.isNotEmpty) linea('Email: ${negocio.correo}', centrado: true),
          if (esFactura && caiValido(negocio.cai)) linea('CAI: ${negocio.cai}', centrado: true),
          const SizedBox(height: 6),
          separador(),
          linea(encabezadoDocumentoVenta(venta, negocio), negrita: true),
          linea('Fecha: ${venta.fechaRegistro != null ? formatoFecha.format(venta.fechaRegistro!) : '-'}'),
          linea('Atendido por: ${venta.usuarioRegistro}'),
          linea('Condición: ${venta.condicion}'),
          if (venta.condicion == 'Credito' && venta.fechaVencimiento != null) linea('Fecha de vencimiento: ${formatoDia.format(venta.fechaVencimiento!)}'),
          separador(),
          linea('Cliente: ${venta.nombreCliente.isEmpty ? 'CONSUMIDOR FINAL' : venta.nombreCliente}'),
          linea('ID/RTN Cliente: ${venta.documentoCliente.isEmpty ? 'N/A' : venta.documentoCliente}'),
          if (venta.vehiculo.isNotEmpty) linea('Vehículo: ${venta.vehiculo}'),
          if (venta.oc.isNotEmpty) linea('No. O/C exenta: ${venta.oc}'),
          if (venta.regExonerado.isNotEmpty) linea('No. Reg de exonerado: ${venta.regExonerado}'),
          if (venta.regSag.isNotEmpty) linea('No. De reg de la SAG: ${venta.regSag}'),
          separador(),
          fila('CANT DESCRIPCIÓN', 'IMPORTE', negrita: true),
          separador(),
          for (final item in venta.detalle) ...[
            nombreProducto(item.nombreProducto),
            fila(
              '${_formatoCantidad(item.cantidad)} x ${formatearMoneda(precioMostrado(item))}${item.descuentoPorcentaje > 0 ? ' (-${_formatoCantidad(item.descuentoPorcentaje)}%)' : ''}',
              formatearMoneda(importeMostrado(item)),
            ),
            const SizedBox(height: 8),
          ],
          separador(),
          fila('SUBTOTAL:', formatearMoneda(venta.subtotal)),
          if (venta.descuentoGlobal > 0) linea('Descuento global: ${_formatoCantidad(venta.descuentoGlobal)}%'),
          if (descuentosYRebajas > 0 || esFacturable) fila('Descuentos y rebajas:', formatearMoneda(descuentosYRebajas)),
          if (esFacturable) ...[
            fila('Importe exonerado:', formatearMoneda(0)),
            fila('Importe exento:', formatearMoneda(0)),
            fila('Gravado 15%:', formatearMoneda(venta.subtotal)),
            fila('Gravado 18%:', formatearMoneda(0)),
            fila('ISV 15%:', formatearMoneda(venta.impuesto)),
            fila('ISV 18%:', formatearMoneda(0)),
          ],
          if (recargo > 0) fila('Recargo tarjeta (${_formatoCantidad(venta.porcentajeTarjeta)}%):', formatearMoneda(recargo)),
          fila('TOTAL A PAGAR:', formatearMoneda(venta.totalAPagar), negrita: true),
          const SizedBox(height: 6),
          separador(),
          linea('Son: ${convertirNumeroALetras(venta.totalAPagar)}'),
          if (venta.condicion != 'Credito') ...[
            if (venta.metodoPago == 'Efectivo') ...[
              linea('Efectivo: ${formatearMoneda(venta.montoPago)}'),
              linea('Cambio: ${formatearMoneda(venta.montoCambio)}'),
            ] else if (venta.metodoPago == 'Tarjeta')
              linea('Pago con tarjeta: ${formatearMoneda(venta.totalAPagar)}')
            else if (venta.metodoPago == 'Transferencia')
              linea('Transferencia')
            else if (venta.metodoPago == 'Mixto')
              for (final pago in venta.pagosMixtos) linea('${pago.metodoPago}: ${formatearMoneda(pago.monto)}'),
          ],
          separador(),
          if (esFactura && (negocio.rangoPrefijo.isNotEmpty || negocio.rangoDesde.isNotEmpty))
            linea('Rango Aut.: ${negocio.rangoPrefijo}${negocio.rangoDesde} al ${negocio.rangoPrefijo}${negocio.rangoHasta}'),
          if (esFactura && negocio.fechaLimiteEmision != null) linea('Fecha Límite: ${formatoDia.format(negocio.fechaLimiteEmision!)}'),
          const SizedBox(height: 6),
          linea('¡GRACIAS POR SU COMPRA!', centrado: true, negrita: true),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerRight, child: linea(esCopia ? 'COPIA' : 'ORIGINAL', negrita: true)),
        ],
      ),
    );
  }

  String _formatoCantidad(double cantidad) {
    if (cantidad == cantidad.roundToDouble()) return cantidad.toInt().toString();
    return cantidad.toStringAsFixed(2);
  }
}
