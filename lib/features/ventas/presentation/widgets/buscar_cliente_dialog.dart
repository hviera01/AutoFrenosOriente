import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../clientes/providers/clientes_provider.dart';
import '../../../../core/utils/texto_utils.dart';

class BuscarClienteDialog extends ConsumerStatefulWidget {
  const BuscarClienteDialog({super.key});

  @override
  ConsumerState<BuscarClienteDialog> createState() => _BuscarClienteDialogState();
}

class _BuscarClienteDialogState extends ConsumerState<BuscarClienteDialog> {
  final _busquedaController = TextEditingController();
  String _busqueda = '';
  bool _creando = false;

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  // Igual que en el sistema viejo (agenda de citas, y también acá en
  // ventas): si el cliente no existe todavía, se registra rápido con lo que
  // ya se escribió en el buscador (solo nombre, sin tener que salir de esta
  // pantalla a ir al módulo de Clientes).
  Future<void> _crearClienteRapido() async {
    final nombre = _busqueda.trim();
    if (nombre.isEmpty) return;
    setState(() => _creando = true);
    try {
      final creado = await ref.read(clienteRepositoryProvider).crearRapido(nombreCompleto: nombre);
      if (mounted) Navigator.pop(context, creado);
    } catch (e) {
      if (mounted) {
        setState(() => _creando = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo crear el cliente: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientesAsync = ref.watch(clientesStreamProvider);
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
                Expanded(child: Text('Buscar Cliente', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700))),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Elegí un cliente registrado o cerrá esto y escribí los datos a mano.', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
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
                      style: GoogleFonts.poppins(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Buscar por DNI o nombre...',
                        hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade400),
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
              child: clientesAsync.when(
                data: (clientes) {
                  var lista = clientes.where((c) => c.estado).toList();
                  if (_busqueda.isNotEmpty) {
                    lista = lista.where((c) => coincideFuzzy(c.textoBusqueda, _busqueda)).toList();
                  }
                  if (lista.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('No se encontraron clientes', style: GoogleFonts.poppins(color: Colors.grey.shade500)),
                          if (_busqueda.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _botonCrearRapido(),
                          ],
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: lista.length + (_busqueda.isNotEmpty ? 1 : 0),
                    separatorBuilder: (context, i) => Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (context, i) {
                      if (i == lista.length) {
                        // Igual que en el sistema viejo: aunque haya
                        // coincidencias parecidas, siempre queda a mano crear
                        // uno nuevo si en realidad es otra persona.
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: _botonCrearRapido(),
                        );
                      }
                      final c = lista[i];
                      return InkWell(
                        onTap: () => Navigator.pop(context, c),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.nombreCompleto, style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600)),
                              if (c.dni.isNotEmpty) Text('DNI: ${c.dni}', style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0D2B4E))),
                error: (e, st) => Center(child: Text('Error: $e', style: GoogleFonts.poppins(color: Colors.red))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botonCrearRapido() {
    return OutlinedButton.icon(
      onPressed: _creando ? null : _crearClienteRapido,
      icon: _creando
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.person_add_alt_1_outlined, size: 18),
      label: Text('Crear cliente "$_busqueda"', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF0D2B4E),
        side: const BorderSide(color: Color(0xFF0D2B4E)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
