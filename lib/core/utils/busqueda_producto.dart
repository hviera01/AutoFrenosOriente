import '../../features/productos/data/producto_model.dart';
import 'texto_utils.dart';

// Búsqueda de productos igual a la del sistema viejo (WinForms,
// frmProducto/mdProducto): se separa lo escrito en palabras y CADA palabra
// tiene que aparecer, tal cual, dentro del texto del producto. Sin tolerancia
// a errores de tipeo (coincideFuzzy traía resultados sin relación).
String _soloAlfanumerico(String texto) => texto.replaceAll(RegExp(r'[^a-z0-9]'), '');

bool coincideProductoEstricto(ProductoModel p, String consulta) {
  final tokens = normalizarTexto(consulta).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  if (tokens.isEmpty) return true;
  final texto = normalizarTexto(p.textoBusqueda);
  final codigoCompacto = _soloAlfanumerico(normalizarTexto('${p.codigo} ${p.codigoBarras}'));
  return tokens.every((t) {
    if (texto.contains(t)) return true;
    // El código se puede escribir sin guiones/espacios/barras
    // ("4881035020" para "48810-35020 / SL-379").
    final compacto = _soloAlfanumerico(t);
    return compacto.length >= 4 && codigoCompacto.contains(compacto);
  });
}

// Para que quien busca por código vea primero lo que escribió: código
// idéntico, luego código que empieza igual, luego el resto.
int _prioridadCodigo(ProductoModel p, String consultaCompacta) {
  if (consultaCompacta.isEmpty) return 2;
  final cod = _soloAlfanumerico(normalizarTexto(p.codigo));
  final barras = _soloAlfanumerico(normalizarTexto(p.codigoBarras));
  if (cod == consultaCompacta || barras == consultaCompacta) return 0;
  if (cod.startsWith(consultaCompacta) || barras.startsWith(consultaCompacta)) return 1;
  return 2;
}

List<ProductoModel> ordenarPorCodigoPrimero(List<ProductoModel> lista, String consulta) {
  final compacta = _soloAlfanumerico(normalizarTexto(consulta));
  if (compacta.length < 3) return lista;
  final prioridades = {for (final p in lista) p.id: _prioridadCodigo(p, compacta)};
  if (prioridades.values.every((v) => v == 2)) return lista;
  final indice = {for (var i = 0; i < lista.length; i++) lista[i].id: i};
  final copia = [...lista];
  copia.sort((a, b) {
    final c = prioridades[a.id]!.compareTo(prioridades[b.id]!);
    return c != 0 ? c : indice[a.id]!.compareTo(indice[b.id]!);
  });
  return copia;
}

// --- Filtro por vehículo y año --------------------------------------------
// Los repuestos no tienen campos de marca/modelo/año: van escritos en el
// nombre ("PASTILLAS DE FRENO NEW YORK BRAKE FORD RANGER 07, BT50 4X4
// 06-12"). El vehículo se busca como texto en el nombre y el año se deduce de
// los rangos que trae el nombre ("02-05", "01-", "94-UP") o años sueltos
// ("CRV 17").

class FiltroVehiculo {
  final String texto;
  final int? anio;
  const FiltroVehiculo({this.texto = '', this.anio});

  bool get activo => texto.trim().isNotEmpty || anio != null;
}

int? parsearAnio(String entrada) {
  final limpio = entrada.trim();
  if (!RegExp(r'^\d{2}$|^\d{4}$').hasMatch(limpio)) return null;
  final n = int.parse(limpio);
  if (limpio.length == 4) return n >= 1950 && n <= 2035 ? n : null;
  return n <= 35 ? 2000 + n : 1900 + n;
}

int? _anioDeToken(String t) {
  final n = int.tryParse(t);
  if (n == null) return null;
  if (t.length == 4) return n >= 1950 && n <= 2035 ? n : null;
  if (n <= 35) return 2000 + n;
  if (n >= 50) return 1900 + n;
  return null;
}

final _regexRango = RegExp(r'(?<![\w#/.(\-])(\d{2}|\d{4})\s*-\s*(\d{2}|\d{4}|UP|\+)?(?![\w/.])', caseSensitive: false);
final _regexSuelto = RegExp(r'(?<![\w#/.(\-])(\d{2}|\d{4})(?![\w/.\-)])');

class _RangoAnios {
  final int desde;
  final int hasta;
  const _RangoAnios(this.desde, this.hasta);
}

final Map<String, List<_RangoAnios>> _cacheRangos = {};

List<_RangoAnios> _rangosDeNombre(String nombre) {
  return _cacheRangos.putIfAbsent(nombre, () {
    final rangos = <_RangoAnios>[];
    var resto = nombre.toUpperCase();
    for (final m in _regexRango.allMatches(resto)) {
      final desde = _anioDeToken(m.group(1)!);
      if (desde == null) continue;
      final finTxt = m.group(2);
      final hasta = (finTxt == null || finTxt == 'UP' || finTxt == '+') ? 2035 : _anioDeToken(finTxt);
      if (hasta == null || hasta < desde) continue;
      rangos.add(_RangoAnios(desde, hasta));
    }
    resto = resto.replaceAll(_regexRango, ' ');
    for (final m in _regexSuelto.allMatches(resto)) {
      final a = _anioDeToken(m.group(1)!);
      if (a != null) rangos.add(_RangoAnios(a, a));
    }
    return rangos;
  });
}

enum CoincidenciaVehiculo { no, confirmada, sinDatoDeAnio }

CoincidenciaVehiculo coincideVehiculo(ProductoModel p, FiltroVehiculo filtro) {
  if (!filtro.activo) return CoincidenciaVehiculo.confirmada;
  final nombre = normalizarTexto(p.nombre);
  final tokens = normalizarTexto(filtro.texto).split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
  for (final t in tokens) {
    if (!nombre.contains(t)) return CoincidenciaVehiculo.no;
  }
  final anio = filtro.anio;
  if (anio == null) return CoincidenciaVehiculo.confirmada;
  final rangos = _rangosDeNombre(p.nombre);
  if (rangos.isEmpty) return CoincidenciaVehiculo.sinDatoDeAnio;
  return rangos.any((r) => anio >= r.desde && anio <= r.hasta) ? CoincidenciaVehiculo.confirmada : CoincidenciaVehiculo.no;
}

// Aplica el filtro de vehículo; los productos del vehículo que no traen año
// en el nombre se muestran igual pero al final, para no esconder un repuesto
// que sí podría servir.
List<ProductoModel> filtrarPorVehiculo(List<ProductoModel> lista, FiltroVehiculo filtro) {
  if (!filtro.activo) return lista;
  final confirmados = <ProductoModel>[];
  final sinAnio = <ProductoModel>[];
  for (final p in lista) {
    switch (coincideVehiculo(p, filtro)) {
      case CoincidenciaVehiculo.confirmada:
        confirmados.add(p);
      case CoincidenciaVehiculo.sinDatoDeAnio:
        sinAnio.add(p);
      case CoincidenciaVehiculo.no:
        break;
    }
  }
  return [...confirmados, ...sinAnio];
}
