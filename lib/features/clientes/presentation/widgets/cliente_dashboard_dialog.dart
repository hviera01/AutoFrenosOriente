import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/cliente_dashboard_repository.dart';
import '../../../../core/services/tipografia_service.dart';

const _colorPrincipal = Color(0xFF0D2B4E);
const _colorAcento = Color(0xFF14B8A6);
const _colorAlerta = Color(0xFFDC2626);
const _colorFondo = Color(0xFFF2F3F7);

/// Réplica (mejorada: a pantalla completa y con gráficas) del "Dashboard"
/// que el sistema viejo mostraba desde dentro de la pantalla de Clientes:
/// clientes frecuentes, inactivos, patrón de visita y recordatorios,
/// calculado sobre el último año de ventas. "Consumidor final" (ventas sin
/// cliente identificado) queda afuera de los rankings a propósito.
class ClienteDashboardDialog extends StatefulWidget {
  const ClienteDashboardDialog({super.key});

  @override
  State<ClienteDashboardDialog> createState() => _ClienteDashboardDialogState();
}

class _ClienteDashboardDialogState extends State<ClienteDashboardDialog> {
  late Future<ClienteDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = ClienteDashboardRepository().obtenerDashboard();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: _colorFondo,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(color: _colorPrincipal),
              child: Row(
                children: [
                  const Icon(Icons.insights_outlined, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Panel de Clientes', style: appFont(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                        Text('Último año de ventas activas · sin "Consumidor final"', style: appFont(fontSize: 11.5, color: Colors.white.withOpacity(0.75))),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualizar',
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: () => setState(() => _future = ClienteDashboardRepository().obtenerDashboard(forzarRecarga: true)),
                  ),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<ClienteDashboardData>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator(color: _colorPrincipal));
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}', style: appFont(color: Colors.red)));
                  }
                  final data = snap.data!;
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final esMovil = constraints.maxWidth < 900;
                      return SingleChildScrollView(
                        padding: EdgeInsets.all(esMovil ? 14 : 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _filaEstadisticas(data, esMovil),
                            const SizedBox(height: 18),
                            esMovil
                                ? Column(
                                    children: [
                                      _tarjetaGraficaFrecuentes(data),
                                      const SizedBox(height: 14),
                                      _tarjetaGraficaDias(data),
                                    ],
                                  )
                                : IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(flex: 3, child: _tarjetaGraficaFrecuentes(data)),
                                        const SizedBox(width: 14),
                                        Expanded(flex: 2, child: _tarjetaGraficaDias(data)),
                                      ],
                                    ),
                                  ),
                            const SizedBox(height: 14),
                            esMovil
                                ? Column(
                                    children: [
                                      _tarjetaInactivos(data),
                                      const SizedBox(height: 14),
                                      _tarjetaRecordatorios(data),
                                    ],
                                  )
                                : IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(child: _tarjetaInactivos(data)),
                                        const SizedBox(width: 14),
                                        Expanded(child: _tarjetaRecordatorios(data)),
                                      ],
                                    ),
                                  ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjeta({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0E2E8))),
      child: child,
    );
  }

  Widget _stat(String titulo, String valor, IconData icono, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0E2E8))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(child: Text(titulo, style: appFont(fontSize: 11, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 8),
            Text(valor, style: appFont(fontSize: 22, fontWeight: FontWeight.w800, color: _colorPrincipal)),
          ],
        ),
      ),
    );
  }

  Widget _filaEstadisticas(ClienteDashboardData data, bool esMovil) {
    final stats = [
      _stat('Clientes identificados', '${data.totalClientesUnicos}', Icons.groups_outlined, _colorPrincipal),
      _stat('Visitas totales', '${data.totalVisitas}', Icons.storefront_outlined, _colorAcento),
      _stat('Promedio por cliente', data.promedioVisitasPorCliente.toStringAsFixed(1), Icons.trending_up_outlined, const Color(0xFFF59E0B)),
      _stat('Clientes inactivos', '${data.inactivos.length}', Icons.person_off_outlined, _colorAlerta),
    ];
    if (esMovil) {
      return Column(
        children: [
          Row(children: [stats[0], const SizedBox(width: 10), stats[1]]),
          const SizedBox(height: 10),
          Row(children: [stats[2], const SizedBox(width: 10), stats[3]]),
        ],
      );
    }
    return Row(children: [stats[0], const SizedBox(width: 14), stats[1], const SizedBox(width: 14), stats[2], const SizedBox(width: 14), stats[3]]);
  }

  Widget _tarjetaGraficaFrecuentes(ClienteDashboardData data) {
    final lista = data.frecuentes;
    return _tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_outline, size: 18, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Text('Clientes más frecuentes', style: appFont(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
            ],
          ),
          const SizedBox(height: 16),
          if (lista.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 30), child: Center(child: Text('Sin datos suficientes todavía', style: appFont(fontSize: 12, color: Colors.grey.shade500))))
          else
            SizedBox(
              height: 240,
              child: BarChart(
                BarChartData(
                  maxY: (lista.first.visitas * 1.2).ceilToDouble(),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final c = lista[group.x];
                        return BarTooltipItem('${c.nombre}\n${rod.toY.toInt()} visitas', appFont(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600));
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, meta) => v == v.roundToDouble() ? Text(v.toInt().toString(), style: appFont(fontSize: 10, color: Colors.grey.shade500)) : const SizedBox())),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= lista.length) return const SizedBox();
                          final nombre = lista[i].nombre;
                          final corto = nombre.length > 8 ? '${nombre.substring(0, 7)}…' : nombre;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Transform.rotate(
                              angle: -0.5,
                              child: Text(corto, style: appFont(fontSize: 9.5, color: Colors.grey.shade700)),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (var i = 0; i < lista.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(toY: lista[i].visitas.toDouble(), color: _colorPrincipal, width: 16, borderRadius: BorderRadius.circular(4)),
                      ]),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tarjetaGraficaDias(ClienteDashboardData data) {
    final visitas = data.visitasPorDiaSemana;
    final maximo = visitas.isEmpty ? 0 : visitas.reduce((a, b) => a > b ? a : b);
    return _tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined, size: 18, color: _colorAcento),
              const SizedBox(width: 8),
              Expanded(child: Text('Visitas por día de la semana', style: appFont(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)))),
            ],
          ),
          const SizedBox(height: 4),
          Text('Todo el negocio, no solo clientes identificados', style: appFont(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: BarChart(
              BarChartData(
                maxY: maximo <= 0 ? 10 : maximo * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem('${diasSemanaCortos[group.x]}\n${rod.toY.toInt()} visitas', appFont(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, meta) => v == v.roundToDouble() ? Text(v.toInt().toString(), style: appFont(fontSize: 10, color: Colors.grey.shade500)) : const SizedBox())),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= 7) return const SizedBox();
                        return Padding(padding: const EdgeInsets.only(top: 8), child: Text(diasSemanaCortos[i], style: appFont(fontSize: 10.5, color: Colors.grey.shade600)));
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  for (var i = 0; i < 7; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(toY: visitas[i].toDouble(), color: _colorAcento, width: 20, borderRadius: BorderRadius.circular(4)),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaInactivos(ClienteDashboardData data) {
    return _tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_off_outlined, size: 18, color: _colorAlerta),
              const SizedBox(width: 8),
              Text('Clientes inactivos', style: appFont(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
            ],
          ),
          const SizedBox(height: 12),
          if (data.inactivos.isEmpty)
            Text('No hay clientes que dejaron de venir', style: appFont(fontSize: 12, color: Colors.grey.shade500))
          else
            ...data.inactivos.take(15).map((c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(child: Text(c.nombre, style: appFont(fontSize: 12.5), overflow: TextOverflow.ellipsis)),
                      Text('${c.diasSinVisitar} días', style: appFont(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _tarjetaRecordatorios(ClienteDashboardData data) {
    return _tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_outlined, size: 18, color: _colorAcento),
              const SizedBox(width: 8),
              Text('Recordatorios', style: appFont(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
            ],
          ),
          const SizedBox(height: 12),
          if (data.recordatorios.isEmpty)
            Text('Sin recordatorios por ahora', style: appFont(fontSize: 12, color: Colors.grey.shade500))
          else
            ...data.recordatorios.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('• $r', style: appFont(fontSize: 12.5)),
                )),
        ],
      ),
    );
  }
}
