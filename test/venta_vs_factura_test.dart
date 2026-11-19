import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_ventas/features/ventas/data/item_venta_model.dart';
import 'package:sistema_ventas/features/ventas/providers/carrito_provider.dart';

ItemVentaModel _item(double precioCatalogo, double cantidad, {double descuento = 0}) {
  final sinIsv = precioCatalogo / 1.15;
  return ItemVentaModel(
    idProducto: 'p$precioCatalogo',
    idCategoria: 'c',
    nombreProducto: 'Producto',
    precioVenta: sinIsv,
    cantidad: cantidad,
    subtotal: double.parse((sinIsv * cantidad * (1 - descuento / 100)).toStringAsFixed(2)),
    precioCompraUsado: 0,
    descuentoPorcentaje: descuento,
  );
}

void main() {
  final items = [_item(100, 2), _item(57.5, 1, descuento: 10), _item(0, 1)];

  test('Factura desglosa ISV y el total es el precio de catalogo', () {
    final c = CarritoVentaState(items: items, tipoDocumento: 'Factura');
    expect(c.aplicaIsv, isTrue);
    expect(c.subtotal + c.impuesto, closeTo(251.75, 0.01));
    expect(c.impuesto, greaterThan(0));
    expect(c.itemsParaGuardar, same(items));
  });

  test('Venta no lleva ISV y cobra lo mismo que la factura', () {
    final factura = CarritoVentaState(items: items, tipoDocumento: 'Factura');
    final venta = CarritoVentaState(items: items, tipoDocumento: 'VentaSinFacturar');
    expect(venta.impuesto, 0);
    expect(venta.subtotal, closeTo(251.75, 0.001));
    expect(venta.totalAPagar, factura.totalAPagar);
    final guardar = venta.itemsParaGuardar;
    expect(guardar[0].precioVenta, 100);
    expect(guardar[1].precioVenta, 57.5);
    expect(guardar.fold<double>(0, (s, i) => s + i.subtotal), closeTo(venta.subtotal, 0.001));
  });

  test('Tipo heredado o desconocido cae al documento por defecto', () {
    tipoDocumentoVentaPorDefecto = 'Factura';
    expect(CarritoVentaState(tipoDocumento: 'Venta').tipoDocumento, 'Factura');
    tipoDocumentoVentaPorDefecto = 'VentaSinFacturar';
    expect(CarritoVentaState().tipoDocumento, 'VentaSinFacturar');
    expect(CarritoVentaState(tipoDocumento: 'Cotizacion').tipoDocumento, 'Cotizacion');
  });

  test('Producto sin precio se detecta', () {
    expect(CarritoVentaState(items: items).tienePrecioCero, isTrue);
  });
}
