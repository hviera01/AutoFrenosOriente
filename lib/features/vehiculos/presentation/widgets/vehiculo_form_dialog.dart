import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/vehiculo_model.dart';
import '../../providers/vehiculos_provider.dart';
import '../../../clientes/data/cliente_model.dart';
import '../../../ventas/presentation/widgets/buscar_cliente_dialog.dart';
import '../../../../core/services/tipografia_service.dart';

class VehiculoFormDialog extends ConsumerStatefulWidget {
  final VehiculoModel? vehiculo;
  final ClienteModel? clientePreseleccionado;

  const VehiculoFormDialog({super.key, this.vehiculo, this.clientePreseleccionado});

  @override
  ConsumerState<VehiculoFormDialog> createState() => _VehiculoFormDialogState();
}

class _VehiculoFormDialogState extends ConsumerState<VehiculoFormDialog> {
  final _marcaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _anioController = TextEditingController();
  final _placaController = TextEditingController();
  String _idCliente = '';
  String _nombreCliente = '';
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final v = widget.vehiculo;
    if (v != null) {
      _idCliente = v.idCliente;
      _nombreCliente = v.nombreCliente;
      _marcaController.text = v.marca;
      _modeloController.text = v.modelo;
      _anioController.text = v.anio;
      _placaController.text = v.placa;
    } else if (widget.clientePreseleccionado != null) {
      _idCliente = widget.clientePreseleccionado!.id;
      _nombreCliente = widget.clientePreseleccionado!.nombreCompleto;
    }
  }

  @override
  void dispose() {
    _marcaController.dispose();
    _modeloController.dispose();
    _anioController.dispose();
    _placaController.dispose();
    super.dispose();
  }

  Future<void> _elegirCliente() async {
    final elegido = await showDialog<ClienteModel>(context: context, builder: (context) => const BuscarClienteDialog());
    if (elegido == null) return;
    setState(() {
      _idCliente = elegido.id;
      _nombreCliente = elegido.nombreCompleto;
    });
  }

  Future<void> _guardar() async {
    if (_idCliente.isEmpty) {
      setState(() => _error = 'Elegí el cliente dueño del vehículo');
      return;
    }
    final marca = _marcaController.text.trim();
    if (marca.isEmpty) {
      setState(() => _error = 'La marca es obligatoria');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final repo = ref.read(vehiculoRepositoryProvider);
      if (widget.vehiculo == null) {
        await repo.crear(idCliente: _idCliente, nombreCliente: _nombreCliente, marca: marca, modelo: _modeloController.text.trim(), anio: _anioController.text.trim(), placa: _placaController.text.trim());
      } else {
        await repo.actualizar(id: widget.vehiculo!.id, idCliente: _idCliente, nombreCliente: _nombreCliente, marca: marca, modelo: _modeloController.text.trim(), anio: _anioController.text.trim(), placa: _placaController.text.trim());
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _guardando = false;
      });
    }
  }

  Future<void> _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar vehículo', style: appFont(fontWeight: FontWeight.w700)),
        content: Text('¿Seguro que querés eliminar este vehículo?', style: appFont(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancelar', style: appFont())),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D2B4E)),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: appFont()),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    setState(() => _guardando = true);
    try {
      await ref.read(vehiculoRepositoryProvider).eliminar(widget.vehiculo!.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _guardando = false;
      });
    }
  }

  InputDecoration _decoracion(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: appFont(fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFE8EAF0),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.vehiculo != null;
    final tamano = MediaQuery.of(context).size;
    final esMovil = tamano.width < 480;
    final anchoDialog = esMovil ? tamano.width - 48 : 440.0;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: anchoDialog,
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: const Color(0xFF0D2B4E).withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.directions_car_filled_outlined, color: Color(0xFF0D2B4E)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      editando ? 'Editar Vehículo' : 'Nuevo Vehículo',
                      style: appFont(fontSize: 17, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: _elegirCliente,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(color: const Color(0xFFE8EAF0), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Icon(Icons.person_outline, size: 18, color: Colors.grey.shade600),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _nombreCliente.isEmpty ? 'Elegí el cliente' : _nombreCliente,
                                style: appFont(fontSize: 14, fontWeight: FontWeight.w600, color: _nombreCliente.isEmpty ? Colors.grey.shade500 : const Color(0xFF1A1A1A)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.edit_outlined, size: 16, color: Colors.grey.shade500),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(controller: _marcaController, autofocus: true, style: appFont(fontSize: 14), decoration: _decoracion('Marca')),
                    const SizedBox(height: 14),
                    TextField(controller: _modeloController, style: appFont(fontSize: 14), decoration: _decoracion('Modelo (opcional)')),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _anioController, keyboardType: TextInputType.number, style: appFont(fontSize: 14), decoration: _decoracion('Año (opcional)'))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: _placaController, style: appFont(fontSize: 14), decoration: _decoracion('Placa (opcional)'))),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)),
                        child: Text(_error!, style: appFont(color: Colors.red.shade700, fontSize: 12)),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
              child: Row(
                children: [
                  if (editando)
                    IconButton(
                      onPressed: _guardando ? null : _eliminar,
                      icon: const Icon(Icons.delete_outline, color: Color(0xFF0D2B4E)),
                      style: IconButton.styleFrom(backgroundColor: const Color(0xFF0D2B4E).withOpacity(0.08), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  const Spacer(),
                  TextButton(onPressed: _guardando ? null : () => Navigator.pop(context), child: Text('Cancelar', style: appFont(color: Colors.grey.shade700))),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _guardando ? null : _guardar,
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D2B4E), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _guardando
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
                        : Text('Guardar', style: appFont(fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
