/// Identifica de qué documento vino un movimiento de historial de stock, a
/// partir del texto del motivo (que arma cada repositorio, ej. "Venta 0001",
/// "Anulación de compra 0002", "Traslado TRAS-000123 a Sucursal 2"): así una
/// fila del historial (por producto o global) puede abrir el detalle real de
/// la venta/compra/traslado que la originó, en vez de quedarse solo con el
/// texto plano. Ajustes manuales u otros motivos que no matcheen ninguno de
/// estos patrones simplemente no son clicables.
class OrigenHistorial {
  final String tipo;
  final String numero;
  const OrigenHistorial(this.tipo, this.numero);
}

OrigenHistorial? origenDeMotivo(String motivo) {
  final texto = motivo.trim();
  final patrones = <RegExp, String>{
    // Motivos que arma la app (ver Venta/Compra/TrasladoRepository).
    RegExp(r'^Venta\s+(\S+)$', caseSensitive: false): 'venta',
    RegExp(r'^Anulaci[oó]n de venta\s+(\S+)$', caseSensitive: false): 'venta',
    RegExp(r'^Compra\s+(\S+)$', caseSensitive: false): 'compra',
    RegExp(r'^Anulaci[oó]n de compra\s+(\S+)$', caseSensitive: false): 'compra',
    // El traslado a destino es opcional en el patrón: la app siempre lo
    // incluye ("Traslado TRAS-000123 a Sucursal 2"), pero el motivo no
    // siempre lo trae -ver abajo, el HistorialStock migrado del sistema
    // viejo no lo tenía-.
    RegExp(r'^Traslado\s+(\S+)(\s+a\s+.+)?$', caseSensitive: false): 'traslado',
    RegExp(r'^Anulaci[oó]n de traslado\s+(\S+)$', caseSensitive: false): 'traslado',
    // Motivos tal cual quedaron migrados del HistorialStock del sistema
    // viejo (TipoMovimiento+NumeroDocumento, ej. "VENTA 0027",
    // "ANULACION_COMPRA 00122" -con guion bajo y sin acento, no "Anulación
    // de compra"-): sin este segundo juego de patrones, ningún movimiento
    // migrado antes de esta actualización quedaba clicable.
    RegExp(r'^Anulaci[oó]n_Venta\s+(\S+)$', caseSensitive: false): 'venta',
    RegExp(r'^Anulaci[oó]n_Compra\s+(\S+)$', caseSensitive: false): 'compra',
  };
  for (final entrada in patrones.entries) {
    final match = entrada.key.firstMatch(texto);
    if (match != null) return OrigenHistorial(entrada.value, match.group(1)!);
  }
  return null;
}
