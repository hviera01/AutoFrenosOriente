import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'venta_model.dart';
import 'numero_a_letras.dart';
import 'tipos_documento.dart';
import '../../../core/utils/formato_moneda.dart';
import '../../../core/utils/logo_escpos.dart';
import '../../../core/utils/texto_utils.dart';
import '../../negocio/data/negocio_model.dart';

bool caiValido(String cai) {
  final limpio = cai.trim();
  return limpio.isNotEmpty && limpio != '0';
}

String encabezadoDocumentoVenta(VentaModel venta, NegocioModel negocio) {
  final prefijo = venta.tipoDocumento == 'Factura' ? negocio.rangoPrefijo : '';
  return '${etiquetaTipoDocumento(venta.tipoDocumento).toUpperCase()} $prefijo${venta.numeroDocumento}';
}

double montoRecargoTarjetaVenta(VentaModel venta) {
  if (venta.porcentajeTarjeta <= 0) return 0;
  return redondearMoneda(venta.totalAPagar - (venta.subtotal + venta.impuesto));
}

class VentaTicketEscPosService {
  Future<List<int>> generarTicket(VentaModel venta, NegocioModel negocio, {bool? forzarCopia}) async {
    final perfil = await CapabilityProfile.load();
    final paperSize = negocio.anchoTicketMm <= 60 ? PaperSize.mm58 : PaperSize.mm80;
    final generador = Generator(paperSize, perfil);
    final logo = !negocio.logoEnTicket ? null : decodificarLogoEscPos(negocio.logoBnBase64, maxDimension: paperSize == PaperSize.mm58 ? 130 : 180);
    final anchoDescripcion = paperSize == PaperSize.mm58 ? 20 : 31;
    final anchoTexto = paperSize == PaperSize.mm58 ? 32 : 48;

    List<int> bytes = [];
    bytes += generador.reset();
    bytes += _construirTicket(generador, venta, negocio, logo, esCopia: forzarCopia ?? false, anchoDescripcion: anchoDescripcion, anchoTexto: anchoTexto);
    if (forzarCopia == null && negocio.facturaImprimirCopia) {
      bytes += _construirTicket(generador, venta, negocio, logo, esCopia: true, anchoDescripcion: anchoDescripcion, anchoTexto: anchoTexto);
    }
    return bytes;
  }

  List<int> _texto(Generator g, String texto, {PosStyles styles = const PosStyles(), int? maxAncho}) {
    final limpio = quitarTildes(texto);
    if (maxAncho == null) return g.text(limpio, styles: styles);
    List<int> bytes = [];
    for (final linea in _envolver(limpio, maxAncho)) {
      bytes += g.text(linea, styles: styles);
    }
    return bytes;
  }

  PosColumn _columna(String texto, {required int width, PosStyles styles = const PosStyles()}) {
    return PosColumn(text: quitarTildes(texto), width: width, styles: styles);
  }

  List<String> _envolver(String texto, int maxAncho) {
    final palabras = texto.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (palabras.isEmpty) return [''];

    final lineas = <String>[];
    var actual = '';

    void cerrarLinea() {
      if (actual.isNotEmpty) {
        lineas.add(actual);
        actual = '';
      }
    }

    for (final palabra in palabras) {
      if (palabra.length <= maxAncho) {
        if (actual.isEmpty) {
          actual = palabra;
        } else if (actual.length + 1 + palabra.length <= maxAncho) {
          actual = '$actual $palabra';
        } else {
          cerrarLinea();
          actual = palabra;
        }
        continue;
      }
      cerrarLinea();
      var restante = palabra;
      while (restante.length > maxAncho) {
        lineas.add('${restante.substring(0, maxAncho - 1)}-');
        restante = restante.substring(maxAncho - 1);
      }
      actual = restante;
    }
    cerrarLinea();
    return lineas;
  }

  List<int> _construirTicket(Generator generador, VentaModel venta, NegocioModel negocio, img.Image? logo, {required bool esCopia, required int anchoDescripcion, required int anchoTexto}) {
    final formatoFecha = DateFormat('dd/MM/yyyy hh:mm a');
    final formatoDia = DateFormat('dd/MM/yyyy');
    final esFactura = venta.tipoDocumento == 'Factura';

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

    List<int> bytes = [];

    if (logo != null) bytes += rasterEscPos(logo);
    if (negocio.nombre.isNotEmpty) bytes += _encabezadoNombreNegocio(generador, negocio.nombre, anchoTexto);
    if (negocio.eslogan.isNotEmpty) bytes += _texto(generador, negocio.eslogan, styles: const PosStyles(align: PosAlign.center), maxAncho: anchoTexto);
    if (negocio.direccion.isNotEmpty) bytes += _texto(generador, 'Direccion: ${negocio.direccion}', styles: const PosStyles(align: PosAlign.center), maxAncho: anchoTexto);
    if (negocio.rtn.isNotEmpty) bytes += _texto(generador, 'RTN: ${negocio.rtn}', styles: const PosStyles(align: PosAlign.center), maxAncho: anchoTexto);
    if (negocio.telefono.isNotEmpty) bytes += _texto(generador, 'Tel: ${negocio.telefono}', styles: const PosStyles(align: PosAlign.center), maxAncho: anchoTexto);
    if (negocio.correo.isNotEmpty) bytes += _texto(generador, 'Email: ${negocio.correo}', styles: const PosStyles(align: PosAlign.center), maxAncho: anchoTexto);
    if (esFactura && caiValido(negocio.cai)) bytes += _texto(generador, 'CAI: ${negocio.cai}', styles: const PosStyles(align: PosAlign.center), maxAncho: anchoTexto);
    bytes += generador.emptyLines(1);
    bytes += generador.hr();

    bytes += _texto(generador, encabezadoDocumentoVenta(venta, negocio), styles: const PosStyles(bold: true), maxAncho: anchoTexto);
    bytes += _texto(generador, 'Fecha: ${venta.fechaRegistro != null ? formatoFecha.format(venta.fechaRegistro!) : '-'}', maxAncho: anchoTexto);
    bytes += _texto(generador, 'Atendido por: ${venta.usuarioRegistro}', maxAncho: anchoTexto);
    bytes += _texto(generador, 'Condicion: ${venta.condicion}', maxAncho: anchoTexto);
    if (venta.condicion == 'Credito' && venta.fechaVencimiento != null) {
      bytes += _texto(generador, 'Fecha de vencimiento: ${formatoDia.format(venta.fechaVencimiento!)}', maxAncho: anchoTexto);
    }
    bytes += generador.hr();

    bytes += _texto(generador, 'Cliente: ${venta.nombreCliente.isEmpty ? 'CONSUMIDOR FINAL' : venta.nombreCliente}', maxAncho: anchoTexto);
    bytes += _texto(generador, 'ID/RTN Cliente: ${venta.documentoCliente.isEmpty ? 'N/A' : venta.documentoCliente}', maxAncho: anchoTexto);
    if (venta.vehiculo.isNotEmpty) bytes += _texto(generador, 'Vehiculo: ${venta.vehiculo}', maxAncho: anchoTexto);
    if (venta.oc.isNotEmpty) bytes += _texto(generador, 'No. O/C exenta: ${venta.oc}', maxAncho: anchoTexto);
    if (venta.regExonerado.isNotEmpty) bytes += _texto(generador, 'No. Reg de exonerado: ${venta.regExonerado}', maxAncho: anchoTexto);
    if (venta.regSag.isNotEmpty) bytes += _texto(generador, 'No. De reg de la SAG: ${venta.regSag}', maxAncho: anchoTexto);
    bytes += generador.hr();

    bytes += generador.row([
      _columna('CANT DESCRIPCION', width: 8, styles: const PosStyles(bold: true)),
      _columna('IMPORTE', width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);
    bytes += generador.hr();

    for (final item in venta.detalle) {
      for (final linea in _envolver(item.nombreProducto, anchoDescripcion)) {
        bytes += generador.row([
          _columna(linea, width: 8),
          _columna('', width: 4),
        ]);
      }
      bytes += generador.row([
        _columna('${_formatoCantidad(item.cantidad)} x ${formatearMoneda(precioMostrado(item))}${item.descuentoPorcentaje > 0 ? ' (-${_formatoCantidad(item.descuentoPorcentaje)}%)' : ''}', width: 8),
        _columna(formatearMoneda(importeMostrado(item)), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generador.emptyLines(1);
    }
    bytes += generador.hr();

    bytes += _filaTotal(generador, 'SUBTOTAL:', venta.subtotal);
    if (venta.descuentoGlobal > 0) bytes += _texto(generador, 'Descuento global: ${_formatoCantidad(venta.descuentoGlobal)}%');
    if (descuentosYRebajas > 0 || esFacturable) bytes += _filaTotal(generador, 'Descuentos y rebajas:', descuentosYRebajas);
    if (esFacturable) {
      bytes += _filaTotal(generador, 'Importe exonerado:', 0);
      bytes += _filaTotal(generador, 'Importe exento:', 0);
      bytes += _filaTotal(generador, 'Gravado 15%:', venta.subtotal);
      bytes += _filaTotal(generador, 'Gravado 18%:', 0);
      bytes += _filaTotal(generador, 'ISV 15%:', venta.impuesto);
      bytes += _filaTotal(generador, 'ISV 18%:', 0);
    }
    if (recargo > 0) bytes += _filaTotal(generador, 'Recargo tarjeta (${_formatoCantidad(venta.porcentajeTarjeta)}%):', recargo);
    bytes += _filaTotal(generador, 'TOTAL A PAGAR:', venta.totalAPagar, negrita: true);
    bytes += generador.emptyLines(1);
    bytes += generador.hr();

    bytes += _texto(generador, 'Son: ${convertirNumeroALetras(venta.totalAPagar)}', maxAncho: anchoTexto);
    if (venta.condicion != 'Credito') {
      if (venta.metodoPago == 'Efectivo') {
        bytes += _texto(generador, 'Efectivo: ${formatearMoneda(venta.montoPago)}', maxAncho: anchoTexto);
        bytes += _texto(generador, 'Cambio: ${formatearMoneda(venta.montoCambio)}', maxAncho: anchoTexto);
      } else if (venta.metodoPago == 'Tarjeta') {
        bytes += _texto(generador, 'Pago con tarjeta: ${formatearMoneda(venta.totalAPagar)}', maxAncho: anchoTexto);
      } else if (venta.metodoPago == 'Transferencia') {
        bytes += _texto(generador, 'Transferencia');
      } else if (venta.metodoPago == 'Mixto') {
        for (final pago in venta.pagosMixtos) {
          bytes += _texto(generador, '${pago.metodoPago}: ${formatearMoneda(pago.monto)}', maxAncho: anchoTexto);
        }
      }
    }
    bytes += generador.hr();

    if (esFactura && (negocio.rangoPrefijo.isNotEmpty || negocio.rangoDesde.isNotEmpty)) {
      bytes += _texto(generador, 'Rango Aut.: ${negocio.rangoPrefijo}${negocio.rangoDesde} al ${negocio.rangoPrefijo}${negocio.rangoHasta}', maxAncho: anchoTexto);
    }
    if (esFactura && negocio.fechaLimiteEmision != null) {
      bytes += _texto(generador, 'Fecha Limite: ${formatoDia.format(negocio.fechaLimiteEmision!)}', maxAncho: anchoTexto);
    }
    bytes += generador.emptyLines(1);
    bytes += _texto(generador, 'GRACIAS POR SU COMPRA!', styles: const PosStyles(align: PosAlign.center, bold: true), maxAncho: anchoTexto);
    bytes += generador.emptyLines(1);
    bytes += _texto(generador, esCopia ? 'COPIA' : 'ORIGINAL', styles: const PosStyles(align: PosAlign.right, bold: true));
    bytes += generador.cut();

    return bytes;
  }

  List<int> _encabezadoNombreNegocio(Generator g, String nombre, int anchoTexto) {
    final nombreMayus = nombre.toUpperCase().trim();
    const styles = PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2);
    return _texto(g, nombreMayus, styles: styles, maxAncho: anchoTexto ~/ 2);
  }

  List<int> _filaTotal(Generator generador, String etiqueta, double valor, {bool negrita = false}) {
    return generador.row([
      _columna(etiqueta, width: 8, styles: PosStyles(bold: negrita)),
      _columna(formatearMoneda(valor), width: 4, styles: PosStyles(align: PosAlign.right, bold: negrita)),
    ]);
  }

  String _formatoCantidad(double cantidad) {
    if (cantidad == cantidad.roundToDouble()) return cantidad.toInt().toString();
    return cantidad.toStringAsFixed(2);
  }
}
