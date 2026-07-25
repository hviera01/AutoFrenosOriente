String normalizarTexto(String texto) {
  final mapaAcentos = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ñ': 'n',
  };
  var resultado = texto.toLowerCase();
  mapaAcentos.forEach((k, v) {
    resultado = resultado.replaceAll(k, v);
  });
  return resultado.trim();
}

int distanciaLevenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  // DP de una sola fila (O(min(largo,corto)) de memoria) en vez de la
  // matriz completa O(a.length*b.length): con listas grandes (Inventario
  // con miles de productos) esta función se llama muchísimas veces por
  // búsqueda, y alocar una matriz nueva cada vez generaba presión de GC
  // notable. El resultado es idéntico, solo cambia cómo se calcula.
  final corta = a.length <= b.length ? a : b;
  final larga = a.length <= b.length ? b : a;
  final fila = List<int>.generate(corta.length + 1, (i) => i);
  for (var i = 1; i <= larga.length; i++) {
    var anteriorDiagonal = fila[0];
    fila[0] = i;
    for (var j = 1; j <= corta.length; j++) {
      final temp = fila[j];
      final costo = larga[i - 1] == corta[j - 1] ? 0 : 1;
      final borrar = fila[j] + 1;
      final insertar = fila[j - 1] + 1;
      final sustituir = anteriorDiagonal + costo;
      fila[j] = borrar < insertar ? (borrar < sustituir ? borrar : sustituir) : (insertar < sustituir ? insertar : sustituir);
      anteriorDiagonal = temp;
    }
  }
  return fila[corta.length];
}

bool coincideFuzzy(String textoCompleto, String consulta) {
  final textoNorm = normalizarTexto(textoCompleto);
  final consultaNorm = normalizarTexto(consulta);
  if (consultaNorm.isEmpty) return true;
  final palabrasTexto = textoNorm.split(RegExp(r'\s+'));
  final palabrasConsulta = consultaNorm.split(RegExp(r'\s+'));
  for (final palabraConsulta in palabrasConsulta) {
    if (palabraConsulta.isEmpty) continue;
    // Tolerancia a errores de tipeo: nada para palabras muy cortas (ahí
    // cualquier letra distinta ya es otra palabra), un poco más para
    // palabras largas.
    final tolerancia = palabraConsulta.length <= 4 ? 0 : (palabraConsulta.length <= 7 ? 1 : 2);
    final coincideAlguna = palabrasTexto.any((palabraTexto) {
      if (palabraTexto.isEmpty) return false;
      // Que la palabra buscada aparezca dentro de una palabra del producto
      // (permite escribir solo el principio o una parte). Antes también se
      // aceptaba al revés (palabra del producto dentro de la búsqueda), lo
      // que hacía que una palabra corta cualquiera del producto -"on", "rex",
      // etc.- calzara adentro de algo como "rexona" y trajera resultados sin
      // ninguna relación real.
      if (palabraTexto.contains(palabraConsulta)) return true;
      if (tolerancia == 0) return false;
      // Si la diferencia de longitud ya supera la tolerancia, la distancia
      // de Levenshtein no puede terminar por debajo de ella: se descarta sin
      // calcular nada (evita miles de cálculos por búsqueda en listas
      // grandes como el Inventario de Auto Frenos, con ~3400 productos).
      if ((palabraTexto.length - palabraConsulta.length).abs() > tolerancia) return false;
      return distanciaLevenshtein(palabraTexto, palabraConsulta) <= tolerancia;
    });
    if (!coincideAlguna) return false;
  }
  return true;
}