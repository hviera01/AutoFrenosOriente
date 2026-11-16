import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/productos/data/producto_model.dart';
import '../../features/productos/providers/productos_provider.dart';
import '../services/tipografia_service.dart';
import '../utils/busqueda_producto.dart';
import '../utils/vehiculo_diccionario.dart';

// Los campos no filtran en vivo: el dueño (la pantalla) lee los
// controllers cuando se ejecuta la búsqueda (Enter o botón buscar) y arma el
// filtro con filtroDesdeCampos, así vehículo/año/tipo se aplican junto con el
// texto. Al elegir una sugerencia de vehículo o un tipo de repuesto sí se
// busca al toque.
FiltroVehiculo filtroDesdeCampos(TextEditingController vehiculo, TextEditingController anio, {String? tipo}) =>
    FiltroVehiculo(texto: vehiculo.text, anio: parsearAnio(anio.text), tipo: tipo);

class FiltroVehiculoCampos extends ConsumerStatefulWidget {
  final TextEditingController vehiculoCtrl;
  final TextEditingController anioCtrl;
  final ValueNotifier<String?> tipoNotifier;
  final VoidCallback onBuscar;
  final bool compacto;

  const FiltroVehiculoCampos({
    super.key,
    required this.vehiculoCtrl,
    required this.anioCtrl,
    required this.tipoNotifier,
    required this.onBuscar,
    this.compacto = false,
  });

  @override
  ConsumerState<FiltroVehiculoCampos> createState() => _FiltroVehiculoCamposState();
}

class _FiltroVehiculoCamposState extends ConsumerState<FiltroVehiculoCampos> {
  final _focoVehiculo = FocusNode();

  @override
  void dispose() {
    _focoVehiculo.dispose();
    super.dispose();
  }

  double get _alto => widget.compacto ? 46 : 50;

  BoxDecoration get _decoracion => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB6BCC7)),
      );

  Widget _campoTexto({
    required TextEditingController ctrl,
    required String hint,
    required IconData icono,
    required double ancho,
    FocusNode? foco,
    List<TextInputFormatter>? formatters,
    TextInputType? teclado,
  }) {
    return Container(
      width: ancho,
      height: _alto,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: _decoracion,
      child: Row(
        children: [
          Icon(icono, size: 18, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: ctrl,
              focusNode: foco,
              style: appFont(fontSize: 13),
              inputFormatters: formatters,
              keyboardType: teclado,
              decoration: InputDecoration(hintText: hint, hintStyle: appFont(fontSize: 12.5, color: Colors.grey.shade400), border: InputBorder.none, isDense: true),
              onSubmitted: (_) => widget.onBuscar(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campoVehiculo(List<SugerenciaVehiculo> todas) {
    return RawAutocomplete<SugerenciaVehiculo>(
      textEditingController: widget.vehiculoCtrl,
      focusNode: _focoVehiculo,
      displayStringForOption: (s) => s.consulta,
      optionsBuilder: (valor) => filtrarSugerenciasVehiculo(todas, valor.text),
      onSelected: (_) => widget.onBuscar(),
      fieldViewBuilder: (context, ctrl, foco, onSubmit) => _campoTexto(
        ctrl: ctrl,
        foco: foco,
        hint: 'Vehículo (ej. hilux, ford ranger)',
        icono: Icons.directions_car_outlined,
        ancho: 250,
      ),
      optionsViewBuilder: (context, onSelected, opciones) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300, maxWidth: 300),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: opciones.length,
                itemBuilder: (context, i) {
                  final s = opciones.elementAt(i);
                  return InkWell(
                    onTap: () => onSelected(s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Icon(s.esMarca ? Icons.business_outlined : Icons.directions_car_outlined, size: 16, color: Colors.grey.shade500),
                          const SizedBox(width: 10),
                          Expanded(child: Text(s.etiqueta, style: appFont(fontSize: 13, fontWeight: s.esMarca ? FontWeight.w700 : FontWeight.w500))),
                          Text('${s.cantidad}', style: appFont(fontSize: 11.5, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _campoTipo(List<({String etiqueta, int cantidad})> tipos) {
    return ValueListenableBuilder<String?>(
      valueListenable: widget.tipoNotifier,
      builder: (context, elegido, _) {
        return PopupMenuButton<String>(
          tooltip: 'Tipo de repuesto',
          position: PopupMenuPosition.under,
          constraints: const BoxConstraints(maxHeight: 420),
          onSelected: (v) {
            widget.tipoNotifier.value = v == '__todos__' ? null : v;
            widget.onBuscar();
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: '__todos__', child: Text('Todos los repuestos', style: appFont(fontSize: 13, fontWeight: elegido == null ? FontWeight.w700 : FontWeight.w400))),
            for (final t in tipos)
              PopupMenuItem(
                value: t.etiqueta,
                child: Row(
                  children: [
                    Expanded(child: Text(t.etiqueta, style: appFont(fontSize: 13, fontWeight: elegido == t.etiqueta ? FontWeight.w700 : FontWeight.w400))),
                    Text('${t.cantidad}', style: appFont(fontSize: 11.5, color: Colors.grey.shade500)),
                  ],
                ),
              ),
          ],
          child: Container(
            height: _alto,
            width: 190,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: _decoracion.copyWith(color: elegido == null ? Colors.white : const Color(0xFFE6EEF8), border: Border.all(color: elegido == null ? const Color(0xFFB6BCC7) : const Color(0xFF0D2B4E))),
            child: Row(
              children: [
                Icon(Icons.build_outlined, size: 18, color: elegido == null ? Colors.grey.shade400 : const Color(0xFF0D2B4E)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    elegido ?? 'Tipo de repuesto',
                    overflow: TextOverflow.ellipsis,
                    style: appFont(fontSize: elegido == null ? 12.5 : 13, color: elegido == null ? Colors.grey.shade400 : const Color(0xFF0D2B4E), fontWeight: elegido == null ? FontWeight.w400 : FontWeight.w600),
                  ),
                ),
                Icon(Icons.arrow_drop_down, size: 20, color: Colors.grey.shade500),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final productos = ref.watch(productosStreamProvider).value ?? const <ProductoModel>[];
    final sugerencias = sugerenciasVehiculoDe(productos);
    final tipos = tiposDisponibles(productos);
    return ListenableBuilder(
      listenable: Listenable.merge([widget.vehiculoCtrl, widget.anioCtrl, widget.tipoNotifier]),
      builder: (context, _) {
        final hayAlgo = widget.vehiculoCtrl.text.isNotEmpty || widget.anioCtrl.text.isNotEmpty || widget.tipoNotifier.value != null;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _campoVehiculo(sugerencias),
            _campoTexto(
              ctrl: widget.anioCtrl,
              hint: 'Año',
              icono: Icons.event_outlined,
              ancho: 100,
              teclado: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            ),
            _campoTipo(tipos),
            if (hayAlgo)
              IconButton(
                tooltip: 'Quitar vehículo, año y tipo',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  widget.vehiculoCtrl.clear();
                  widget.anioCtrl.clear();
                  widget.tipoNotifier.value = null;
                  widget.onBuscar();
                },
              ),
          ],
        );
      },
    );
  }
}
