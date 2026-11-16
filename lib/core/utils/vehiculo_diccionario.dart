import '../../features/productos/data/producto_model.dart';
import 'texto_utils.dart';

String _limpio(String texto) => normalizarTexto(texto).replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

class _Marca {
  final String id;
  final String nombre;
  final List<String> alias;
  const _Marca(this.id, this.nombre, this.alias);
}

class _Modelo {
  final String id;
  final String nombre;
  final String marcaId;
  final List<String> alias;
  const _Modelo(this.id, this.nombre, this.marcaId, this.alias);
}

const _marcas = <_Marca>[
  _Marca('toyota', 'Toyota', ['toyota', 'toy', 'yoyota']),
  _Marca('honda', 'Honda', ['honda']),
  _Marca('nissan', 'Nissan', ['nissan', 'datsun']),
  _Marca('ford', 'Ford', ['ford']),
  _Marca('isuzu', 'Isuzu', ['isuzu']),
  _Marca('mazda', 'Mazda', ['mazda']),
  _Marca('kia', 'Kia', ['kia']),
  _Marca('hyundai', 'Hyundai', ['hyundai', 'hyunday', 'hyundal', 'hiundai']),
  _Marca('mitsubishi', 'Mitsubishi', ['mitsubishi', 'mitsu']),
  _Marca('chevrolet', 'Chevrolet', ['chevrolet', 'chevy', 'chev']),
  _Marca('suzuki', 'Suzuki', ['suzuki']),
  _Marca('dodge', 'Dodge', ['dodge']),
  _Marca('jeep', 'Jeep', ['jeep']),
  _Marca('volkswagen', 'Volkswagen', ['volkswagen', 'vw']),
  _Marca('subaru', 'Subaru', ['subaru']),
  _Marca('daihatsu', 'Daihatsu', ['daihatsu']),
  _Marca('bmw', 'BMW', ['bmw']),
  _Marca('mercedes', 'Mercedes-Benz', ['mercedes', 'benz']),
  _Marca('renault', 'Renault', ['renault']),
  _Marca('fiat', 'Fiat', ['fiat']),
  _Marca('peugeot', 'Peugeot', ['peugeot']),
  _Marca('lexus', 'Lexus', ['lexus']),
];

const _modelos = <_Modelo>[
  _Modelo('toyota_hilux', 'Hilux', 'toyota', ['hilux', 'vigo', 'revo', 'hilux vigo']),
  _Modelo('toyota_22r', 'Pickup 22R', 'toyota', ['22r']),
  _Modelo('toyota_tacoma', 'Tacoma', 'toyota', ['tacoma']),
  _Modelo('toyota_4runner', '4Runner', 'toyota', ['4runner', '4 runner']),
  _Modelo('toyota_corolla', 'Corolla', 'toyota', ['corolla']),
  _Modelo('toyota_yaris', 'Yaris', 'toyota', ['yaris']),
  _Modelo('toyota_camry', 'Camry', 'toyota', ['camry']),
  _Modelo('toyota_rav4', 'RAV4', 'toyota', ['rav4', 'rav 4']),
  _Modelo('toyota_prado', 'Prado', 'toyota', ['prado']),
  _Modelo('toyota_landcruiser', 'Land Cruiser', 'toyota', ['land cruiser', 'landcruiser', 'landcruser', 'cruiser']),
  _Modelo('toyota_hiace', 'Hiace', 'toyota', ['hiace']),
  _Modelo('toyota_fortuner', 'Fortuner', 'toyota', ['fortuner']),
  _Modelo('toyota_sequoia', 'Sequoia', 'toyota', ['sequoia']),
  _Modelo('toyota_highlander', 'Highlander', 'toyota', ['highlander']),
  _Modelo('toyota_avanza', 'Avanza', 'toyota', ['avanza']),
  _Modelo('toyota_tundra', 'Tundra', 'toyota', ['tundra']),
  _Modelo('toyota_previa', 'Previa', 'toyota', ['previa']),
  _Modelo('toyota_matrix', 'Matrix', 'toyota', ['matrix']),
  _Modelo('toyota_prius', 'Prius', 'toyota', ['prius', 'priu']),
  _Modelo('toyota_celica', 'Celica', 'toyota', ['celica']),
  _Modelo('toyota_echo', 'Echo', 'toyota', ['echo']),
  _Modelo('daihatsu_terios', 'Terios', 'daihatsu', ['terios']),
  _Modelo('honda_crv', 'CR-V', 'honda', ['crv', 'cr v']),
  _Modelo('honda_civic', 'Civic', 'honda', ['civic']),
  _Modelo('honda_accord', 'Accord', 'honda', ['accord']),
  _Modelo('honda_fit', 'Fit', 'honda', ['fit']),
  _Modelo('honda_hrv', 'HR-V', 'honda', ['hrv', 'hr v']),
  _Modelo('honda_pilot', 'Pilot', 'honda', ['pilot']),
  _Modelo('honda_odyssey', 'Odyssey', 'honda', ['odyssey']),
  _Modelo('honda_element', 'Element', 'honda', ['element']),
  _Modelo('nissan_frontier', 'Frontier', 'nissan', ['frontier']),
  _Modelo('nissan_navara', 'Navara / NP300', 'nissan', ['navara', 'np300', 'np 300']),
  _Modelo('nissan_d22', 'D22', 'nissan', ['d22']),
  _Modelo('nissan_sentra', 'Sentra', 'nissan', ['sentra']),
  _Modelo('nissan_tiida', 'Tiida', 'nissan', ['tiida']),
  _Modelo('nissan_versa', 'Versa', 'nissan', ['versa']),
  _Modelo('nissan_march', 'March', 'nissan', ['march']),
  _Modelo('nissan_pathfinder', 'Pathfinder', 'nissan', ['pathfinder']),
  _Modelo('nissan_xtrail', 'X-Trail', 'nissan', ['xtrail', 'x trail']),
  _Modelo('nissan_murano', 'Murano', 'nissan', ['murano']),
  _Modelo('nissan_almera', 'Almera', 'nissan', ['almera']),
  _Modelo('nissan_patrol', 'Patrol', 'nissan', ['patrol']),
  _Modelo('nissan_qashqai', 'Qashqai', 'nissan', ['qashqai']),
  _Modelo('nissan_kicks', 'Kicks', 'nissan', ['kicks']),
  _Modelo('nissan_urvan', 'Urvan', 'nissan', ['urvan']),
  _Modelo('nissan_maxima', 'Maxima', 'nissan', ['maxima']),
  _Modelo('ford_ranger', 'Ranger', 'ford', ['ranger']),
  _Modelo('ford_escape', 'Escape', 'ford', ['escape']),
  _Modelo('ford_explorer', 'Explorer', 'ford', ['explorer']),
  _Modelo('ford_f150', 'F-150', 'ford', ['f150', 'f 150']),
  _Modelo('ford_f250', 'F-250', 'ford', ['f250', 'f 250']),
  _Modelo('ford_f350', 'F-350', 'ford', ['f350', 'f 350']),
  _Modelo('ford_excursion', 'Excursion', 'ford', ['excursion']),
  _Modelo('ford_focus', 'Focus', 'ford', ['focus']),
  _Modelo('ford_fiesta', 'Fiesta', 'ford', ['fiesta']),
  _Modelo('ford_expedition', 'Expedition', 'ford', ['expedition']),
  _Modelo('ford_ecosport', 'EcoSport', 'ford', ['ecosport']),
  _Modelo('isuzu_dmax', 'D-Max', 'isuzu', ['dmax', 'd max', 'dimax', 'di max']),
  _Modelo('isuzu_npr', 'NPR', 'isuzu', ['npr']),
  _Modelo('isuzu_trooper', 'Trooper', 'isuzu', ['trooper']),
  _Modelo('isuzu_rodeo', 'Rodeo', 'isuzu', ['rodeo']),
  _Modelo('isuzu_amigo', 'Amigo', 'isuzu', ['amigo']),
  _Modelo('isuzu_sportero', 'Sportero', 'isuzu', ['sportero']),
  _Modelo('mazda_bt50', 'BT-50', 'mazda', ['bt50', 'bt 50']),
  _Modelo('mazda_cx5', 'CX-5', 'mazda', ['cx5', 'cx 5']),
  _Modelo('mazda_cx7', 'CX-7', 'mazda', ['cx7', 'cx 7']),
  _Modelo('mazda_cx3', 'CX-3', 'mazda', ['cx3', 'cx 3']),
  _Modelo('mazda_3', 'Mazda 3', 'mazda', ['mazda 3', 'mazda3']),
  _Modelo('mazda_6', 'Mazda 6', 'mazda', ['mazda 6', 'mazda6']),
  _Modelo('mazda_tribute', 'Tribute', 'mazda', ['tribute']),
  _Modelo('kia_picanto', 'Picanto', 'kia', ['picanto']),
  _Modelo('kia_rio', 'Rio', 'kia', ['rio']),
  _Modelo('kia_sportage', 'Sportage', 'kia', ['sportage']),
  _Modelo('kia_sorento', 'Sorento', 'kia', ['sorento']),
  _Modelo('kia_cerato', 'Cerato', 'kia', ['cerato']),
  _Modelo('kia_optima', 'Optima', 'kia', ['optima']),
  _Modelo('kia_soul', 'Soul', 'kia', ['soul']),
  _Modelo('kia_seltos', 'Seltos', 'kia', ['seltos']),
  _Modelo('kia_carens', 'Carens', 'kia', ['carens']),
  _Modelo('kia_bongo', 'Bongo / K2700', 'kia', ['bongo', 'k2700', 'k300', 'k2500']),
  _Modelo('hyundai_elantra', 'Elantra', 'hyundai', ['elantra']),
  _Modelo('hyundai_tucson', 'Tucson', 'hyundai', ['tucson']),
  _Modelo('hyundai_santafe', 'Santa Fe', 'hyundai', ['santa fe', 'santafe']),
  _Modelo('hyundai_accent', 'Accent', 'hyundai', ['accent']),
  _Modelo('hyundai_h100', 'H100', 'hyundai', ['h100', 'h 100']),
  _Modelo('hyundai_county', 'County', 'hyundai', ['county']),
  _Modelo('hyundai_creta', 'Creta', 'hyundai', ['creta']),
  _Modelo('hyundai_i10', 'i10', 'hyundai', ['i10', 'i 10']),
  _Modelo('hyundai_starex', 'Starex', 'hyundai', ['starex']),
  _Modelo('hyundai_sonata', 'Sonata', 'hyundai', ['sonata']),
  _Modelo('mitsubishi_l200', 'L200', 'mitsubishi', ['l200', 'l 200']),
  _Modelo('mitsubishi_montero', 'Montero', 'mitsubishi', ['montero']),
  _Modelo('mitsubishi_lancer', 'Lancer', 'mitsubishi', ['lancer']),
  _Modelo('mitsubishi_outlander', 'Outlander', 'mitsubishi', ['outlander']),
  _Modelo('mitsubishi_triton', 'Triton', 'mitsubishi', ['triton']),
  _Modelo('mitsubishi_mirage', 'Mirage', 'mitsubishi', ['mirage', 'mirago']),
  _Modelo('chevrolet_spark', 'Spark', 'chevrolet', ['spark']),
  _Modelo('chevrolet_aveo', 'Aveo', 'chevrolet', ['aveo']),
  _Modelo('chevrolet_optra', 'Optra', 'chevrolet', ['optra']),
  _Modelo('chevrolet_cruze', 'Cruze', 'chevrolet', ['cruze']),
  _Modelo('chevrolet_captiva', 'Captiva', 'chevrolet', ['captiva']),
  _Modelo('chevrolet_silverado', 'Silverado', 'chevrolet', ['silverado']),
  _Modelo('chevrolet_sail', 'Sail', 'chevrolet', ['sail']),
  _Modelo('chevrolet_n300', 'N300', 'chevrolet', ['n300']),
  _Modelo('chevrolet_luv', 'LUV', 'chevrolet', ['luv']),
  _Modelo('chevrolet_tracker', 'Tracker', 'chevrolet', ['tracker']),
  _Modelo('suzuki_swift', 'Swift', 'suzuki', ['swift']),
  _Modelo('suzuki_vitara', 'Vitara', 'suzuki', ['vitara', 'grand vitara']),
  _Modelo('suzuki_jimny', 'Jimny', 'suzuki', ['jimny']),
  _Modelo('suzuki_alto', 'Alto', 'suzuki', ['alto']),
  _Modelo('dodge_caravan', 'Caravan', 'dodge', ['caravan']),
  _Modelo('dodge_neon', 'Neon', 'dodge', ['neon']),
  _Modelo('dodge_ram', 'Ram', 'dodge', ['ram']),
  _Modelo('jeep_cherokee', 'Cherokee', 'jeep', ['cherokee']),
  _Modelo('jeep_wrangler', 'Wrangler', 'jeep', ['wrangler']),
  _Modelo('vw_amarok', 'Amarok', 'volkswagen', ['amarok']),
  _Modelo('vw_jetta', 'Jetta', 'volkswagen', ['jetta']),
  _Modelo('vw_golf', 'Golf', 'volkswagen', ['golf']),
  _Modelo('vw_tiguan', 'Tiguan', 'volkswagen', ['tiguan']),
];

class _Alias {
  final String texto;
  final String id;
  final bool esMarca;
  const _Alias(this.texto, this.id, this.esMarca);
}

final List<_Alias> _todosLosAlias = _construirAlias();

List<_Alias> _construirAlias() {
  final lista = <_Alias>[];
  for (final m in _marcas) {
    for (final a in m.alias) {
      lista.add(_Alias(_limpio(a), m.id, true));
    }
  }
  for (final m in _modelos) {
    for (final a in m.alias) {
      lista.add(_Alias(_limpio(a), m.id, false));
    }
  }
  lista.sort((a, b) => b.texto.length.compareTo(a.texto.length));
  return lista;
}

final Map<String, _Marca> _marcaPorId = {for (final m in _marcas) m.id: m};
final Map<String, _Modelo> _modeloPorId = {for (final m in _modelos) m.id: m};

String nombreMarcaVehiculo(String id) => _marcaPorId[id]?.nombre ?? id;
String nombreModeloVehiculo(String id) => _modeloPorId[id]?.nombre ?? id;
String marcaDeModelo(String id) => _modeloPorId[id]?.marcaId ?? '';

class VehiculoReconocido {
  final Set<String> marcas;
  final Set<String> modelos;
  const VehiculoReconocido(this.marcas, this.modelos);

  bool get hay => marcas.isNotEmpty || modelos.isNotEmpty;
}

VehiculoReconocido reconocerVehiculoEnTexto(String texto) {
  final t = ' ${_limpio(texto)} ';
  final marcas = <String>{};
  final modelos = <String>{};
  for (final a in _todosLosAlias) {
    if (a.texto.isEmpty || !t.contains(' ${a.texto} ')) continue;
    if (a.esMarca) {
      marcas.add(a.id);
    } else {
      modelos.add(a.id);
      marcas.add(_modeloPorId[a.id]!.marcaId);
    }
  }
  return VehiculoReconocido(marcas, modelos);
}

final Expando<VehiculoReconocido> _cacheReconocido = Expando<VehiculoReconocido>('vehiculoReconocido');

VehiculoReconocido vehiculoDeProducto(ProductoModel p) => _cacheReconocido[p] ??= reconocerVehiculoEnTexto(p.nombre);

class ConsultaVehiculo {
  final Set<String> marcas;
  final Set<String> modelos;
  final List<String> libres;
  const ConsultaVehiculo(this.marcas, this.modelos, this.libres);

  bool get vacia => marcas.isEmpty && modelos.isEmpty && libres.isEmpty;
}

ConsultaVehiculo analizarConsultaVehiculo(String texto) {
  var t = ' ${_limpio(texto)} ';
  final marcas = <String>{};
  final modelos = <String>{};
  for (final a in _todosLosAlias) {
    if (a.texto.isEmpty) continue;
    final clave = ' ${a.texto} ';
    if (!t.contains(clave)) continue;
    if (a.esMarca) {
      marcas.add(a.id);
    } else {
      modelos.add(a.id);
    }
    t = t.replaceAll(clave, ' ');
  }
  final libres = t.split(' ').where((x) => x.isNotEmpty).toList();
  return ConsultaVehiculo(marcas, modelos, libres);
}

bool productoCumpleConsultaVehiculo(ProductoModel p, ConsultaVehiculo q, String nombreNormalizado) {
  if (q.vacia) return true;
  final r = vehiculoDeProducto(p);
  for (final m in q.marcas) {
    if (!r.marcas.contains(m)) return false;
  }
  for (final m in q.modelos) {
    if (!r.modelos.contains(m)) return false;
  }
  for (final t in q.libres) {
    if (!nombreNormalizado.contains(t)) return false;
  }
  return true;
}

class SugerenciaVehiculo {
  final String etiqueta;
  final String consulta;
  final int cantidad;
  final bool esMarca;
  const SugerenciaVehiculo(this.etiqueta, this.consulta, this.cantidad, this.esMarca);
}

List<ProductoModel>? _ultimaListaSugerencias;
List<SugerenciaVehiculo> _ultimasSugerencias = const [];

List<SugerenciaVehiculo> sugerenciasVehiculoDe(List<ProductoModel> productos) {
  if (identical(productos, _ultimaListaSugerencias)) return _ultimasSugerencias;
  final porMarca = <String, int>{};
  final porModelo = <String, int>{};
  for (final p in productos) {
    if (!p.estado) continue;
    final r = vehiculoDeProducto(p);
    for (final m in r.marcas) {
      porMarca[m] = (porMarca[m] ?? 0) + 1;
    }
    for (final m in r.modelos) {
      porModelo[m] = (porModelo[m] ?? 0) + 1;
    }
  }
  final lista = <SugerenciaVehiculo>[
    for (final e in porMarca.entries) SugerenciaVehiculo(nombreMarcaVehiculo(e.key), nombreMarcaVehiculo(e.key), e.value, true),
    for (final e in porModelo.entries)
      SugerenciaVehiculo('${nombreMarcaVehiculo(marcaDeModelo(e.key))} ${nombreModeloVehiculo(e.key)}', '${nombreMarcaVehiculo(marcaDeModelo(e.key))} ${nombreModeloVehiculo(e.key)}', e.value, false),
  ];
  lista.sort((a, b) => b.cantidad.compareTo(a.cantidad));
  _ultimaListaSugerencias = productos;
  _ultimasSugerencias = lista;
  return lista;
}

List<SugerenciaVehiculo> filtrarSugerenciasVehiculo(List<SugerenciaVehiculo> todas, String texto, {int limite = 8}) {
  final limpio = _limpio(texto);
  if (limpio.isEmpty) return todas.where((s) => !s.esMarca).take(limite).toList();
  final consulta = analizarConsultaVehiculo(texto);
  final tokens = limpio.split(' ').where((t) => t.isNotEmpty).toList();
  final coincidencias = <SugerenciaVehiculo>[];
  for (final s in todas) {
    final etiqueta = _limpio(s.etiqueta);
    final porTexto = tokens.every((t) => etiqueta.contains(t));
    var porAlias = false;
    if (consulta.marcas.isNotEmpty || consulta.modelos.isNotEmpty) {
      final r = reconocerVehiculoEnTexto(s.etiqueta);
      porAlias = consulta.modelos.every(r.modelos.contains) && consulta.marcas.every(r.marcas.contains) && consulta.libres.isEmpty;
    }
    if (porTexto || porAlias) coincidencias.add(s);
    if (coincidencias.length >= limite) break;
  }
  return coincidencias;
}

class _Tipo {
  final String etiqueta;
  final List<String> palabras;
  const _Tipo(this.etiqueta, this.palabras);
}

const _tipos = <_Tipo>[
  _Tipo('Pastillas', ['pastilla', 'pastillas', 'balata', 'balatas']),
  _Tipo('Zapatas', ['zapata', 'zapatas']),
  _Tipo('Discos', ['disco', 'discos']),
  _Tipo('Tambores', ['tambor', 'tambores']),
  _Tipo('Bombas', ['bomba', 'bombas', 'boma', 'bamba']),
  _Tipo('Balineras', ['balinera', 'balineras', 'rodamiento', 'rodamientos']),
  _Tipo('Amortiguadores', ['amortiguador', 'amortiguadores']),
  _Tipo('Rótulas', ['rotula', 'rotulas']),
  _Tipo('Terminales', ['terminal', 'terminales']),
  _Tipo('Filtros', ['filtro', 'filtros']),
  _Tipo('Resortes', ['resorte', 'resortes']),
  _Tipo('Empaques', ['empaque', 'empaques', 'empaquito', 'empaquitos']),
  _Tipo('Retenedores', ['retenedor', 'retenedores']),
  _Tipo('Cables', ['cable', 'cables']),
  _Tipo('Barras', ['barra', 'barras']),
  _Tipo('Bujes', ['buje', 'bujes', 'hule', 'hules']),
  _Tipo('Tijeras', ['tijera', 'tijeras']),
  _Tipo('Flechas y puntas', ['flecha', 'flechas', 'punta', 'puntas']),
  _Tipo('Mangueras', ['manguera', 'mangueras']),
  _Tipo('Aceites y líquidos', ['aceite', 'aceites', 'coolant', 'liquido', 'liquidos']),
  _Tipo('Kits', ['kit', 'kits', 'juego', 'juegos']),
];

final Expando<String> _cacheTipo = Expando<String>('tipoRepuesto');

String? tipoRepuestoDe(ProductoModel p) {
  final cacheado = _cacheTipo[p];
  if (cacheado != null) return cacheado.isEmpty ? null : cacheado;
  final palabras = _limpio(p.nombre).split(' ').where((t) => t.isNotEmpty).toList();
  String? encontrado;
  for (final palabra in palabras.take(2)) {
    for (final t in _tipos) {
      if (t.palabras.contains(palabra)) {
        encontrado = t.etiqueta;
        break;
      }
    }
    if (encontrado != null) break;
  }
  _cacheTipo[p] = encontrado ?? '';
  return encontrado;
}

List<({String etiqueta, int cantidad})> tiposDisponibles(List<ProductoModel> productos) {
  final cuenta = <String, int>{};
  for (final p in productos) {
    if (!p.estado) continue;
    final t = tipoRepuestoDe(p);
    if (t != null) cuenta[t] = (cuenta[t] ?? 0) + 1;
  }
  final lista = [for (final e in cuenta.entries) (etiqueta: e.key, cantidad: e.value)];
  lista.sort((a, b) => b.cantidad.compareTo(a.cantidad));
  return lista;
}
