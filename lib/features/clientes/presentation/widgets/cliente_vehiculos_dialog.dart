import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/cliente_model.dart';
import '../../../vehiculos/data/vehiculo_model.dart';
import '../../../vehiculos/providers/vehiculos_provider.dart';
import '../../../vehiculos/presentation/widgets/vehiculo_form_dialog.dart';
import '../../../../core/services/tipografia_service.dart';

/// Vehículos de un cliente puntual — igual que "Registrar Vehículo" en el
/// sistema viejo (frmRegistrarVehiculo): requiere un cliente ya elegido,
/// lista solo sus autos y permite agregar/editar/eliminar sin salir de acá.
/// El listado GLOBAL de todos los vehículos de todos los clientes sigue
/// siendo la pantalla aparte "Vehículos" del menú (frmVehiculosRegistrados).
class ClienteVehiculosDialog extends ConsumerStatefulWidget {
  final ClienteModel cliente;

  const ClienteVehiculosDialog({super.key, required this.cliente});

  @override
  ConsumerState<ClienteVehiculosDialog> createState() => _ClienteVehiculosDialogState();
}

class _ClienteVehiculosDialogState extends ConsumerState<ClienteVehiculosDialog> {
  List<VehiculoModel>? _vehiculos;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _vehiculos = null;
      _error = null;
    });
    try {
      final lista = await ref.read(vehiculoRepositoryProvider).obtenerPorCliente(widget.cliente.id);
      if (mounted) setState(() => _vehiculos = lista);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudieron cargar los vehículos');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tamano = MediaQuery.of(context).size;
    final esMovil = tamano.width < 480;
    final anchoDialog = esMovil ? tamano.width - 32 : 460.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: anchoDialog,
        constraints: BoxConstraints(maxHeight: tamano.height - 100),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Vehículos de ${widget.cliente.nombreCompleto}',
                      style: appFont(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: _error != null
                  ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: appFont(color: Colors.red)))
                  : _vehiculos == null
                      ? const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: Color(0xFF0D2B4E))))
                      : _vehiculos!.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 30),
                              child: Center(child: Text('Este cliente no tiene vehículos registrados', style: appFont(fontSize: 13, color: Colors.grey.shade500))),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _vehiculos!.length,
                              separatorBuilder: (context, i) => Divider(height: 1, color: Colors.grey.shade200),
                              itemBuilder: (context, i) {
                                final v = _vehiculos![i];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.directions_car_filled_outlined, color: Color(0xFF0D2B4E)),
                                  title: Text('${v.marca} ${v.modelo}'.trim(), style: appFont(fontSize: 13.5, fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                    [if (v.anio.isNotEmpty) v.anio, if (v.placa.isNotEmpty) 'Placa ${v.placa}'].join(' · '),
                                    style: appFont(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                  trailing: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF9AA0AC)),
                                  onTap: () async {
                                    await showDialog(context: context, builder: (context) => VehiculoFormDialog(vehiculo: v));
                                    _cargar();
                                  },
                                );
                              },
                            ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 22),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    await showDialog(context: context, builder: (context) => VehiculoFormDialog(clientePreseleccionado: widget.cliente));
                    _cargar();
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: Text('Registrar Vehículo', style: appFont(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D2B4E), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
