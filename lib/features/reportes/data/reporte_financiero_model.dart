/// Un producto dentro de un ranking (más vendido, más comprado o más
/// rentable). El campo `monto` cambia de significado según el ranking en el
/// que aparezca (ingreso, costo o ganancia) — lo interpreta quien arma la
/// lista, no el modelo.
class RankingProducto {
  final String idProducto;
  final String nombreProducto;
  final double cantidad;
  final double monto;

  RankingProducto({required this.idProducto, required this.nombreProducto, required this.cantidad, required this.monto});
}

class ProductoSinVenta {
  final String idProducto;
  final String nombreProducto;
  final double stock;
  final double valorInventario;

  ProductoSinVenta({required this.idProducto, required this.nombreProducto, required this.stock, required this.valorInventario});
}

/// Cuánto del negocio del periodo vino de servicios (cortes) vs. productos
/// físicos: separado porque son dos negocios con márgenes muy distintos (un
/// servicio normalmente no tiene costo de mercadería, o uno muy chico de
/// insumos) y mezclarlos en un solo margen bruto no dice mucho.
class ResumenServiciosProductos {
  final double ventasServicios;
  final double costoServicios;
  final double ventasProductos;
  final double costoProductos;

  ResumenServiciosProductos({
    required this.ventasServicios,
    required this.costoServicios,
    required this.ventasProductos,
    required this.costoProductos,
  });

  double get utilidadServicios => ventasServicios - costoServicios;
  double get utilidadProductos => ventasProductos - costoProductos;
}

class VentasPorUsuario {
  final String usuario;
  final double totalVentas;
  final int cantidadTransacciones;

  VentasPorUsuario({required this.usuario, required this.totalVentas, required this.cantidadTransacciones});
}

/// Ganancia de una venta individual: para responder "qué tan rentable fue
/// esta venta puntual", no solo el agregado del periodo.
class GananciaPorVenta {
  final String idVenta;
  final String numeroDocumento;
  final DateTime? fecha;
  final String cliente;
  final double ventas;
  final double costo;

  GananciaPorVenta({required this.idVenta, required this.numeroDocumento, required this.fecha, required this.cliente, required this.ventas, required this.costo});

  double get ganancia => ventas - costo;
  double get margenPorcentaje => ventas <= 0 ? 0 : (ganancia / ventas) * 100;
}

class AbonoPorProveedor {
  final String proveedor;
  final double total;

  AbonoPorProveedor({required this.proveedor, required this.total});
}

/// Un mes de la serie de comparación (últimos 6 meses, terminando en el
/// actual).
class PuntoMensual {
  final DateTime mes;
  final double totalVentas;
  final double totalCompras;

  PuntoMensual({required this.mes, required this.totalVentas, required this.totalCompras});
}

class FlujoEfectivo {
  final double ingresosEfectivo;
  final double ingresosTarjeta;
  final double ingresosTransferencia;
  final double egresosEfectivo;
  final double egresosTransferencia;

  FlujoEfectivo({
    required this.ingresosEfectivo,
    required this.ingresosTarjeta,
    required this.ingresosTransferencia,
    required this.egresosEfectivo,
    required this.egresosTransferencia,
  });

  double get totalIngresos => ingresosEfectivo + ingresosTarjeta + ingresosTransferencia;
  double get totalEgresos => egresosEfectivo + egresosTransferencia;
  double get neto => totalIngresos - totalEgresos;
}

/// Sugerencias de cuánto destinar a pagos a proveedores sin comprometer el
/// flujo del negocio. Son referencias, no reglas — ver notas en la pantalla.
class RecomendacionPago {
  final double efectivoEstimado;
  final double reservaGastosFijos;
  final double sugeridoPorCaja;
  final double ingresoEfectivoCobrado;
  final double sugeridoPorVentas;

  RecomendacionPago({
    required this.efectivoEstimado,
    required this.reservaGastosFijos,
    required this.sugeridoPorCaja,
    required this.ingresoEfectivoCobrado,
    required this.sugeridoPorVentas,
  });
}

/// Balance general simplificado: no reemplaza un balance contable formal (no
/// hay partida doble, activos fijos ni capital aportado en el sistema). El
/// patrimonio es el residuo Activos − Pasivos, no una cuenta llevada aparte.
class BalanceGeneral {
  final double inventarioACosto;
  final double cuentasPorCobrar;
  final double efectivoEstimado;
  final double cuentasPorPagar;

  BalanceGeneral({
    required this.inventarioACosto,
    required this.cuentasPorCobrar,
    required this.efectivoEstimado,
    required this.cuentasPorPagar,
  });

  double get totalActivos => inventarioACosto + cuentasPorCobrar + efectivoEstimado;
  double get totalPasivos => cuentasPorPagar;
  double get patrimonio => totalActivos - totalPasivos;
}

/// Resultado agregado completo del Reporte Financiero para un rango de
/// fechas. Se calcula una sola vez y lo consumen tanto la pantalla como el
/// PDF, para no recalcular ni arriesgar que muestren números distintos.
class ReporteFinancieroData {
  final DateTime inicio;
  final DateTime fin;

  final double ventasPeriodo;
  final double comprasPeriodo;
  final double costoVentas;
  final double utilidadBruta;
  final double gastosPeriodo;
  final double utilidadNeta;

  final FlujoEfectivo flujoEfectivo;
  final List<PuntoMensual> serieMensual;

  final List<RankingProducto> topVendidosPorCantidad;
  final List<RankingProducto> topCompradosPorCantidad;
  final List<RankingProducto> topGananciaPorProducto;
  final List<ProductoSinVenta> productosSinVenta;

  final List<GananciaPorVenta> gananciaPorVenta;
  final List<VentasPorUsuario> ventasPorUsuario;
  final ResumenServiciosProductos resumenServiciosProductos;

  final double totalAbonosComprasCredito;
  final List<AbonoPorProveedor> abonosPorProveedor;

  final RecomendacionPago recomendacionPago;
  final BalanceGeneral balanceGeneral;

  ReporteFinancieroData({
    required this.inicio,
    required this.fin,
    required this.ventasPeriodo,
    required this.comprasPeriodo,
    required this.costoVentas,
    required this.utilidadBruta,
    required this.gastosPeriodo,
    required this.utilidadNeta,
    required this.flujoEfectivo,
    required this.serieMensual,
    required this.gananciaPorVenta,
    required this.topVendidosPorCantidad,
    required this.topCompradosPorCantidad,
    required this.topGananciaPorProducto,
    required this.productosSinVenta,
    required this.ventasPorUsuario,
    required this.resumenServiciosProductos,
    required this.totalAbonosComprasCredito,
    required this.abonosPorProveedor,
    required this.recomendacionPago,
    required this.balanceGeneral,
  });

  double get margenBrutoPorcentaje => ventasPeriodo <= 0 ? 0 : (utilidadBruta / ventasPeriodo) * 100;
}
