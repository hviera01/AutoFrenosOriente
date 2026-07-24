import '../../reportes/data/reporte_repository.dart';
import '../../reportes/data/reporte_venta_model.dart';

const diasSemanaCortos = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
const _diasSemana = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];

class ClienteFrecuente {
  final String nombre;
  final int visitas;
  final DateTime? primeraVisita;
  final DateTime? ultimaVisita;

  ClienteFrecuente({required this.nombre, required this.visitas, required this.primeraVisita, required this.ultimaVisita});
}

class ClienteInactivo {
  final String nombre;
  final int visitasTotal;
  final DateTime ultimaVisita;
  final int diasSinVisitar;

  ClienteInactivo({required this.nombre, required this.visitasTotal, required this.ultimaVisita, required this.diasSinVisitar});
}

class PatronVisita {
  final String nombre;
  final String diaMasFrecuente;
  final int totalVisitas;

  PatronVisita({required this.nombre, required this.diaMasFrecuente, required this.totalVisitas});
}

class ClienteDashboardData {
  final List<ClienteFrecuente> frecuentes;
  final List<ClienteInactivo> inactivos;
  final List<PatronVisita> patrones;
  final List<String> recordatorios;
  // Visitas de TODO el negocio agrupadas por día de la semana (índice
  // 0=domingo..6=sábado, ver diasSemanaCortos): a diferencia de "patrones"
  // (el día favorito de cada cliente puntual), esto es la vista agregada de
  // qué días vienen más clientes en general — la que de verdad conviene
  // graficar.
  final List<int> visitasPorDiaSemana;
  final int totalClientesUnicos;
  final int totalVisitas;

  ClienteDashboardData({
    required this.frecuentes,
    required this.inactivos,
    required this.patrones,
    required this.recordatorios,
    required this.visitasPorDiaSemana,
    required this.totalClientesUnicos,
    required this.totalVisitas,
  });

  double get promedioVisitasPorCliente => totalClientesUnicos == 0 ? 0 : totalVisitas / totalClientesUnicos;
}

/// Réplica del "Dashboard BI" del sistema viejo (modal dentro de la pantalla
/// de Clientes, con clientes frecuentes/inactivos, patrón de día de visita
/// y recordatorios), armada acá en memoria a partir de las ventas del
/// periodo en vez de con stored procedures.
class ClienteDashboardRepository {
  final _reporteRepository = ReporteRepository();

  // La consulta base es un año completo de ventas, así que si el usuario
  // abre y cierra el panel varias veces (algo común mientras explora las
  // gráficas) no tiene sentido volver a pedirlo todo cada vez. Se cachea a
  // nivel de clase (estático) porque el diálogo crea una instancia nueva del
  // repositorio cada vez que se abre.
  static const _vigenciaCache = Duration(minutes: 5);
  static ClienteDashboardData? _cache;
  static DateTime? _cacheEn;

  bool _esClienteIdentificable(ReporteVentaModel v) {
    final nombre = v.nombreCliente.trim().toUpperCase();
    // "Consumidor final" (o vacío) no es un cliente real identificable: no
    // tiene sentido que aparezca en un ranking de "quién viene más" ni en
    // recordatorios personalizados.
    return nombre.isNotEmpty && nombre != 'CONSUMIDOR FINAL';
  }

  String _clave(ReporteVentaModel v) {
    final doc = v.documentoCliente.trim();
    final nombre = v.nombreCliente.trim();
    return '${doc.isEmpty ? 'NO-DOC' : doc}|$nombre';
  }

  Future<ClienteDashboardData> obtenerDashboard({
    int mesesHistorial = 12,
    int topFrecuentes = 10,
    int semanasSinVisitar = 6,
    int minVisitasInactivo = 1,
    int minVisitasPatron = 3,
    bool forzarRecarga = false,
  }) async {
    final cacheEn = _cacheEn;
    if (!forzarRecarga && _cache != null && cacheEn != null && DateTime.now().difference(cacheEn) < _vigenciaCache) {
      return _cache!;
    }
    final fin = DateTime.now();
    final inicio = DateTime(fin.year, fin.month - mesesHistorial, fin.day);
    final ventas = await _reporteRepository.obtenerReporteVentas(inicio, fin);
    final activas = ventas.where((v) => v.esActiva && !v.esCotizacion && v.fechaRegistro != null).toList();

    final visitasPorDiaSemana = List<int>.filled(7, 0);
    for (final v in activas) {
      visitasPorDiaSemana[v.fechaRegistro!.weekday % 7]++;
    }

    final identificables = activas.where(_esClienteIdentificable).toList();
    final porCliente = <String, List<ReporteVentaModel>>{};
    for (final v in identificables) {
      porCliente.putIfAbsent(_clave(v), () => []).add(v);
    }

    final frecuentes = porCliente.entries.map((e) {
      final ventasCliente = e.value;
      final fechas = ventasCliente.map((v) => v.fechaRegistro!).toList()..sort();
      return ClienteFrecuente(
        nombre: ventasCliente.first.nombreCliente.trim(),
        visitas: ventasCliente.length,
        primeraVisita: fechas.first,
        ultimaVisita: fechas.last,
      );
    }).toList()
      ..sort((a, b) => b.visitas.compareTo(a.visitas));

    final inactivos = porCliente.entries
        .map((e) {
          final ventasCliente = e.value;
          final ultimaVisita = ventasCliente.map((v) => v.fechaRegistro!).reduce((a, b) => a.isAfter(b) ? a : b);
          return ClienteInactivo(
            nombre: ventasCliente.first.nombreCliente.trim(),
            visitasTotal: ventasCliente.length,
            ultimaVisita: ultimaVisita,
            diasSinVisitar: DateTime.now().difference(ultimaVisita).inDays,
          );
        })
        .where((c) => c.visitasTotal >= minVisitasInactivo && c.diasSinVisitar >= semanasSinVisitar * 7)
        .toList()
      ..sort((a, b) => b.diasSinVisitar.compareTo(a.diasSinVisitar));

    final patrones = porCliente.entries
        .map((e) {
          final ventasCliente = e.value;
          if (ventasCliente.length < minVisitasPatron) return null;
          final porDia = <int, int>{};
          for (final v in ventasCliente) {
            final dia = v.fechaRegistro!.weekday % 7; // weekday: 1=lunes..7=domingo -> 0=domingo..6=sábado
            porDia[dia] = (porDia[dia] ?? 0) + 1;
          }
          final diaTop = porDia.entries.reduce((a, b) => a.value >= b.value ? a : b);
          return PatronVisita(nombre: ventasCliente.first.nombreCliente.trim(), diaMasFrecuente: _diasSemana[diaTop.key], totalVisitas: ventasCliente.length);
        })
        .whereType<PatronVisita>()
        .toList()
      ..sort((a, b) => b.totalVisitas.compareTo(a.totalVisitas));

    final recordatorios = <String>[
      ...patrones.take(10).map((p) => '${p.nombre} suele venir los ${p.diaMasFrecuente}.'),
      ...inactivos.take(10).map((c) => '${c.nombre} no visita desde hace ${c.diasSinVisitar} días.'),
    ];

    final resultado = ClienteDashboardData(
      frecuentes: frecuentes.take(topFrecuentes).toList(),
      inactivos: inactivos,
      patrones: patrones,
      recordatorios: recordatorios,
      visitasPorDiaSemana: visitasPorDiaSemana,
      totalClientesUnicos: porCliente.length,
      totalVisitas: identificables.length,
    );
    _cache = resultado;
    _cacheEn = DateTime.now();
    return resultado;
  }
}
