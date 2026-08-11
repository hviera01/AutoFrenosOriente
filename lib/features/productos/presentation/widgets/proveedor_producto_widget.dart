import 'package:flutter/material.dart';
import '../../data/producto_model.dart';
import 'historial_movimientos_dialog.dart';
import '../../../../core/services/tipografia_service.dart';

/// Muestra el último proveedor al que se le compró un producto. Si hay más
/// de un proveedor distinto en el historial de compras, agrega un ícono que
/// abre el historial completo (mismo diálogo que usa Inventario en "Historial
/// de compras") para verlos todos con fecha y factura.
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
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = producto.ultimoProveedorNombre;
    if (nombre.isEmpty) {
      return Text('-', style: appFont(fontSize: fontSize, color: color));
    }
    final hayVarios = producto.proveedoresHistorial.length > 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(nombre, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: appFont(fontSize: fontSize, color: color))),
        if (hayVarios)
          Tooltip(
            message: '${producto.proveedoresHistorial.length} proveedores distintos · ver historial',
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => showDialog(context: context, builder: (context) => HistorialMovimientosDialog(producto: producto, tipo: 'compras')),
              child: const Padding(
                padding: EdgeInsets.only(left: 3),
                child: Icon(Icons.expand_more, size: 16, color: Color(0xFF0D2B4E)),
              ),
            ),
          ),
      ],
    );
  }
}
