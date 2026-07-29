class Roles {
  static const administrador = 'Administrador';
  static const empleado = 'Empleado';
  // Acceso restringido a Inventario: ve todo pero sin precios de costo ni
  // totales de valor de inventario/compra, no puede ajustar stock ni tocar
  // precio/categoría/estado de un producto existente -solo puede editarle
  // código, nombre y ubicación libremente, y crear productos nuevos sin
  // restricción-. También ve (sin poder modificar) historial de ventas e
  // historial de existencia. Pensado para el empleado encargado de
  // acomodar/recibir mercadería sin exponerle info sensible del negocio
  // (ver InventarioScreen, ProductoFormDialog y SideMenu).
  static const inventarioLectura = 'InventarioLectura';

  static const etiquetas = {
    administrador: 'Administrador',
    empleado: 'Empleado',
    inventarioLectura: 'Empleado encargado',
  };
}