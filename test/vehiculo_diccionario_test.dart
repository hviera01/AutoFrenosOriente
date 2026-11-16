import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_ventas/core/utils/busqueda_producto.dart';
import 'package:sistema_ventas/core/utils/texto_utils.dart';
import 'package:sistema_ventas/core/utils/vehiculo_diccionario.dart';
import 'package:sistema_ventas/features/productos/data/producto_model.dart';

ProductoModel _p(String id, String nombre) => ProductoModel(
      id: id,
      codigo: 'C$id',
      codigoBarras: '',
      nombre: nombre,
      descripcion: '',
      idCategoria: '',
      stock: 1,
      precioCompra: 0,
      precioVenta: 0,
      precioVenta2: 0,
      precioVenta3: 0,
      estado: true,
    );

void main() {
  final santaFe = _p('1', 'PASTILLAS DE FRENO HYUNDAI SANTA FE 10-, SORENTO 11');
  final hilux = _p('2', 'PASTILLA DE FRENO TRW HILUX VIGO 09-');
  final ranger = _p('3', 'DISCO DE FRENO FORD RANGER 07, BT50 4X4 06-12');
  final dimax = _p('4', 'ROTULA SUPERIOR ISUZU DIMAX 2WD 04-12');
  final bomba = _p('5', 'BOMBA DE RUEDA ISUZU NPR 13/16 KASHIMA');
  final sinVehiculo = _p('6', 'EMPAQUE DE BOMBA AUXILIAR SEIKEN COPA');
  final todos = [santaFe, hilux, ranger, dimax, bomba, sinVehiculo];

  test('reconoce modelos aunque el nombre no traiga la marca', () {
    final v = vehiculoDeProducto(hilux);
    expect(v.modelos, contains('toyota_hilux'));
    expect(v.marcas, contains('toyota'));
  });

  test('reconoce variantes de escritura', () {
    expect(vehiculoDeProducto(santaFe).marcas, contains('hyundai'));
    expect(vehiculoDeProducto(dimax).modelos, contains('isuzu_dmax'));
  });

  test('un producto sin vehiculo no se reconoce', () {
    final v = vehiculoDeProducto(sinVehiculo);
    expect(v.marcas, isEmpty);
    expect(v.modelos, isEmpty);
  });

  test('la consulta por marca encuentra productos que solo traen el modelo', () {
    final q = analizarConsultaVehiculo('toyota');
    expect(productoCumpleConsultaVehiculo(hilux, q, normalizarTexto(hilux.nombre)), isTrue);
    expect(productoCumpleConsultaVehiculo(ranger, q, normalizarTexto(ranger.nombre)), isFalse);
  });

  test('la consulta con variante mal escrita encuentra el producto', () {
    final q = analizarConsultaVehiculo('dmax');
    expect(productoCumpleConsultaVehiculo(dimax, q, normalizarTexto(dimax.nombre)), isTrue);
  });

  test('filtro por vehiculo con el diccionario', () {
    List<String> ids(FiltroVehiculo f) => filtrarPorVehiculo(todos, f).map((p) => p.id).toList();
    expect(ids(const FiltroVehiculo(texto: 'hyundai')), ['1']);
    expect(ids(const FiltroVehiculo(texto: 'isuzu')), containsAll(['4', '5']));
    expect(ids(const FiltroVehiculo(texto: 'ford ranger')), ['3']);
  });

  test('tipo de repuesto por la primera palabra', () {
    expect(tipoRepuestoDe(hilux), tipoRepuestoDe(santaFe));
    expect(tipoRepuestoDe(ranger), isNot(tipoRepuestoDe(hilux)));
    expect(tipoRepuestoDe(bomba), isNot(tipoRepuestoDe(hilux)));
  });

  test('filtro por tipo combinado con vehiculo', () {
    final tipoPastilla = tipoRepuestoDe(hilux);
    final r = filtrarPorVehiculo(todos, FiltroVehiculo(texto: 'toyota', tipo: tipoPastilla));
    expect(r.map((p) => p.id), ['2']);
    final soloTipo = filtrarPorVehiculo(todos, FiltroVehiculo(tipo: tipoPastilla));
    expect(soloTipo.map((p) => p.id), containsAll(['1', '2']));
    expect(soloTipo.map((p) => p.id), isNot(contains('3')));
  });

  test('tipos disponibles con conteo', () {
    final tipos = tiposDisponibles(todos);
    final pastillas = tipos.firstWhere((t) => t.etiqueta == tipoRepuestoDe(hilux));
    expect(pastillas.cantidad, 2);
  });

  test('sugerencias de vehiculo salen del inventario', () {
    final s = sugerenciasVehiculoDe(todos);
    final filtradas = filtrarSugerenciasVehiculo(s, 'hil');
    expect(filtradas, isNotEmpty);
    expect(filtradas.first.etiqueta.toLowerCase(), contains('hilux'));
  });
}
