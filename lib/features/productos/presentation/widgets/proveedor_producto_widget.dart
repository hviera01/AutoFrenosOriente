import 'package:flutter/material.dart';
import '../../data/producto_model.dart';
import 'historial_movimientos_dialog.dart';
import '../../../../core/services/tipografia_service.dart';

/// Muestra el último proveedor al que se le compró un producto: el nombre
/// completo, sin cortar (pasa a la siguiente línea si no entra en el ancho
/// de la columna). Si hay más de un proveedor distinto en el historial de
/// compras, agrega debajo una etiqueta bien visible ("N proveedores · ver
/// todos") que abre el historial completo (mismo diálogo que usa Inventario
/// en "Historial de compras") con fecha, factura y proveedor de cada compra.
class ProveedorProductoCelda extends StatelessWidget {
  final ProductoModel producto;
  final double fontSize;
  final Color color;
  final int maxLines;

  const ProveedorProductoCelda({
    super.key,
    required this.producto,
    this.fontSize = 12.5,
    this.color = const Color(0xFF3F434A),
    this.maxLines = 4,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = producto.ultimoProveedorNombre;
    if (nombre.isEmpty) {
      return Text('-', style: appFont(fontSize: fontSize, color: color));
    }
    final cantidadProveedores = producto.proveedoresHistorial.length;
    final hayVarios = cantidadProveedores > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(nombre, maxLines: maxLines, softWrap: true, overflow: TextOverflow.ellipsis, style: appFont(fontSize: fontSize, color: color)),
        if (hayVarios) ...[
          const SizedBox(height: 3),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => showDialog(context: context, builder: (context) => HistorialMovimientosDialog(producto: producto, tipo: 'compras')),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF0D2B4E).withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.unfold_more, size: 12, color: Color(0xFF0D2B4E)),
                  const SizedBox(width: 3),
                  Text('$cantidadProveedores proveedores · ver todos', style: appFont(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF0D2B4E))),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
