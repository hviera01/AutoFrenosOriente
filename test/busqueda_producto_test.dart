import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_ventas/core/utils/busqueda_producto.dart';
import 'package:sistema_ventas/features/productos/data/producto_model.dart';

ProductoModel _p(String id, String codigo, String nombre, [String descripcion = '']) => ProductoModel(
      id: id,
      codigo: codigo,
      codigoBarras: '',
      nombre: nombre,
      descripcion: descripcion,
      idCategoria: '',
      stock: 1,
      precioCompra: 0,
      precioVenta: 0,
      precioVenta2: 0,
      precioVenta3: 0,
      estado: true,
    );

void main() {
  final ranger = _p('1', 'SMR517 NYB / 1574', 'PASTILLAS DE FRENO NEW YORK BRAKE FORD RANGER 07, BT50 4X4 06-12', '(9D)');
  final hilux = _p('2', 'D1567', 'PASTILLA DE FRENO TRW HILUX VIGO 09-', '(7I)');
  final hiluxViejo = _p('3', '43360-39015', 'ROTULA SUPERIOR HILUX 2WD 68-83  DAICHI', '(5H)');
  final sinAnio = _p('4', 'SMR553 INTERBRAND', 'PASTILLAS DE FRENO INTERBRAND HILUX', '(7K)');
  final bomba = _p('5', '8-97022-031-1', 'BOMBA DE RUEDA ISUZU NPR 13/16 KASHIMA', '(8J)');
  final fanta = _p('6', '10-47601', 'EMPAQUE DE BOMBA AUXILIAR SEIKEN 1\'\' COPA', '12A');
  final todos = [ranger, hilux, hiluxViejo, sinAnio, bomba, fanta];

  test('busqueda estricta: sin tolerancia a errores de tipeo', () {
    expect(coincideProductoEstricto(hilux, 'hilux pastilla'), isTrue);
    expect(coincideProductoEstricto(hilux, 'hilax'), isFalse);
    expect(coincideProductoEstricto(bomba, 'bonba'), isFalse);
    expect(coincideProductoEstricto(bomba, 'bomba rueda'), isTrue);
  });

  test('codigo con o sin guiones', () {
    expect(coincideProductoEstricto(hiluxViejo, '4336039015'), isTrue);
    expect(coincideProductoEstricto(hiluxViejo, '43360-39015'), isTrue);
    expect(coincideProductoEstricto(hiluxViejo, '43361'), isFalse);
  });

  test('codigo exacto va primero', () {
    final r = ordenarPorCodigoPrimero(todos.where((p) => coincideProductoEstricto(p, 'd1567')).toList(), 'd1567');
    expect(r.first.id, '2');
    final lista = [hiluxViejo, hilux];
    expect(ordenarPorCodigoPrimero(lista, 'D1567').first.id, '2');
  });

  test('filtro por vehiculo y anio', () {
    List<String> ids(FiltroVehiculo f) => filtrarPorVehiculo(todos, f).map((p) => p.id).toList();
    expect(ids(FiltroVehiculo(texto: 'hilux', anio: 2012)), ['2', '4']);
    expect(ids(FiltroVehiculo(texto: 'hilux', anio: 1975)), ['3', '4']);
    expect(ids(FiltroVehiculo(texto: 'hilux', anio: 1990)), ['4']);
    expect(ids(FiltroVehiculo(texto: 'ford ranger', anio: 2007)), ['1']);
    expect(ids(FiltroVehiculo(texto: 'ford ranger', anio: 2010)), ['1']);
    expect(ids(FiltroVehiculo(texto: 'ford ranger', anio: 2015)), isEmpty);
    expect(ids(const FiltroVehiculo(texto: 'hilux')), ['2', '3', '4']);
  });

  test('medidas no se confunden con anios', () {
    expect(coincideVehiculo(bomba, FiltroVehiculo(texto: 'isuzu', anio: 2013)), CoincidenciaVehiculo.sinDatoDeAnio);
    expect(coincideVehiculo(fanta, const FiltroVehiculo(anio: 2012)), CoincidenciaVehiculo.sinDatoDeAnio);
  });

  test('parsearAnio', () {
    expect(parsearAnio('07'), 2007);
    expect(parsearAnio('94'), 1994);
    expect(parsearAnio('2012'), 2012);
    expect(parsearAnio('123'), isNull);
  });
}
