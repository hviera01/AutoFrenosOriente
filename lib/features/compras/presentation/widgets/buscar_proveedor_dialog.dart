import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../proveedores/data/proveedor_model.dart';
import '../../../proveedores/providers/proveedores_provider.dart';
import '../../../../core/utils/texto_utils.dart';
import '../../../../core/services/tipografia_service.dart';

/// Buscador de proveedores para Registrar Compra: con 30+ proveedores un
/// dropdown simple se vuelve incómodo de recorrer, igual que pasaba con
/// clientes/productos (ver BuscarClienteDialog/BuscarProductoDialog).
class BuscarProveedorDialog extends ConsumerStatefulWidget {
  const BuscarProveedorDialog({super.key});

  @override
  ConsumerState<BuscarProveedorDialog> createState() => _BuscarProveedorDialogState();
}

class _BuscarProveedorDialogState extends ConsumerState<BuscarProveedorDialog> {
  final _busquedaController = TextEditingController();
  String _busqueda = '';

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final proveedoresAsync = ref.watch(proveedoresStreamProvider);
    final tamano = MediaQuery.of(context).size;
    final esMovil = tamano.width < 560;
    final anchoDialog = esMovil ? tamano.width - 24 : 500.0;
    final altoDialog = tamano.height < 640 ? tamano.height - 40 : 560.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        width: anchoDialog,
        height: altoDialog,
        padding: EdgeInsets.all(esMovil ? 16 : 22),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Buscar Proveedor', style: appFont(fontSize: 16, fontWeight: FontWeight.w700))),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Elegí un proveedor registrado.', style: appFont(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: const Color(0xFFE8EAF0), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFB6BCC7))),
              child: Row(
                children: [
                  Icon(Icons.search, size: 20, color: Colors.grey.shade400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _busquedaController,
                      autofocus: true,
                      style: appFont(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Buscar por RTN o razón social...',
                        hintStyle: appFont(fontSize: 12.5, color: Colors.grey.shade400),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _busqueda = v.trim()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: proveedoresAsync.when(
                data: (proveedores) {
                  var lista = proveedores.where((p) => p.estado).toList();
                  if (_busqueda.isNotEmpty) {
                    lista = lista.where((p) => coincideFuzzy(p.textoBusqueda, _busqueda)).toList();
                  }
                  if (lista.isEmpty) {
                    return Center(child: Text('No se encontraron proveedores', style: appFont(color: Colors.grey.shade500)));
                  }
                  return ListView.separated(
                    itemCount: lista.length,
                    separatorBuilder: (context, i) => Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (context, i) {
                      final ProveedorModel p = lista[i];
                      return InkWell(
                        onTap: () => Navigator.pop(context, p),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.razonSocial, style: appFont(fontSize: 13.5, fontWeight: FontWeight.w600)),
                              if (p.rtn.isNotEmpty) Text('RTN: ${p.rtn}', style: appFont(fontSize: 11.5, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0D2B4E))),
                error: (e, st) => Center(child: Text('Error: $e', style: appFont(color: Colors.red))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
