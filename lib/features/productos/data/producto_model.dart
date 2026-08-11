class ProductoModel {
  final String id;
  final String codigo;
  final String codigoBarras;
  final String nombre;
  final String descripcion;
  final String idCategoria;
  final double stock;
  final double precioCompra;
  final double precioVenta;
  final double precioVenta2;
  final double precioVenta3;
  final bool estado;
  // Un servicio (ej. corte de cabello) no lleva control de stock y, al
  // venderse, exige elegir qué barbero lo atendió (ver carrito y
  // registrar_venta_screen). A diferencia del sistema viejo, que inferría
  // "es servicio" de una categoría mágica (IdCategoria == 50), acá es un
  // campo explícito del producto.
  final bool esServicio;
  final String imagenUrl;
  // Se actualizan en CompraRepository.registrarCompra: el último proveedor
  // al que se le compró este producto, y la lista de proveedores distintos
  // (para saber si hay más de uno y mostrar el historial completo). No se
  // revierten al anular una compra, igual que precioCompra.
  final String ultimoProveedorNombre;
  final List<String> proveedoresHistorial;

  ProductoModel({
    required this.id,
    required this.codigo,
    required this.codigoBarras,
    required this.nombre,
    required this.descripcion,
    required this.idCategoria,
    required this.stock,
    required this.precioCompra,
    required this.precioVenta,
    required this.precioVenta2,
    required this.precioVenta3,
    required this.estado,
    this.esServicio = false,
    this.imagenUrl = '',
    this.ultimoProveedorNombre = '',
    this.proveedoresHistorial = const [],
  });

  factory ProductoModel.fromMap(String id, Map<String, dynamic> data) {
    return ProductoModel(
      id: id,
      codigo: data['codigo'] ?? '',
      codigoBarras: data['codigoBarras'] ?? '',
      nombre: data['nombre'] ?? '',
      descripcion: data['descripcion'] ?? '',
      idCategoria: data['idCategoria'] ?? '',
      stock: (data['stock'] ?? 0).toDouble(),
      precioCompra: (data['precioCompra'] ?? 0).toDouble(),
      precioVenta: (data['precioVenta'] ?? 0).toDouble(),
      precioVenta2: (data['precioVenta2'] ?? 0).toDouble(),
      precioVenta3: (data['precioVenta3'] ?? 0).toDouble(),
      estado: data['estado'] ?? true,
      esServicio: data['esServicio'] ?? false,
      imagenUrl: data['imagenUrl'] ?? '',
      ultimoProveedorNombre: data['ultimoProveedorNombre'] ?? '',
      proveedoresHistorial: (data['proveedoresHistorial'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  String get textoBusqueda => '$codigo $codigoBarras $nombre $descripcion';
}