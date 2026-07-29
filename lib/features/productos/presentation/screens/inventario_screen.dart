import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/producto_model.dart';
import '../../data/producto_export_service.dart';
import '../../providers/productos_provider.dart';
import '../../../categorias/providers/categorias_provider.dart';
import '../../../../core/utils/texto_utils.dart';
import '../../../../core/utils/formato_moneda.dart';
import '../../../../core/utils/exportador.dart';
import '../widgets/producto_form_dialog.dart';
import '../widgets/importar_inventario_dialog.dart';
import '../widgets/ajuste_stock_dialog.dart';
import '../widgets/historial_stock_dialog.dart';
import '../widgets/historial_movimientos_dialog.dart';
import '../../../../core/widgets/pdf_preview_dialog.dart';
import '../widgets/ticket_opciones_dialog.dart';
import 'package:printing/printing.dart';
import '../../../negocio/data/negocio_model.dart';
import '../../../negocio/providers/negocio_provider.dart';
import '../../../negocio/presentation/widgets/acceso_especial.dart';
import '../../../../core/widgets/barcode_scanner_screen.dart';
import '../../../../core/utils/codigo_barras_utils.dart';
import '../../../../core/constants/roles.dart';
import '../../../auth/providers/auth_provider.dart';

class InventarioScreen extends ConsumerStatefulWidget {
  const InventarioScreen({super.key});

  @override
  ConsumerState<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends ConsumerState<InventarioScreen> {
  final _busquedaController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final _servicioExport = ProductoExportService();
  String? _filaSeleccionada;
  String? _columnaOrden;
  bool _ordenAscendente = false;
  bool _precioConIsv = true;
  // Cuando la búsqueda viene de escanear un código de barras se filtra por
  // coincidencia exacta de código, no con el buscador difuso (que con
  // códigos largos puede "acercarse" a varios productos distintos).
  bool _busquedaPorCodigoBarras = false;
  List<ProductoModel> _listaActual = [];
  double _anchoColumnaNombreActual = 0;

  // --- Memoización del filtrado/orden -------------------------------------
  // El bloque que arma `lista` (filtrar por vista/búsqueda + ordenar) se
  // ejecutaba antes en CADA build de la pantalla, incluyendo los que no
  // tienen nada que ver con los datos: seleccionar una fila, moverse con las
  // flechas o cambiar el toggle de ISV disparan setState() y eso volvía a
  // filtrar/ordenar hasta 3400+ productos solo para repintar el resaltado de
  // una fila. Acá se cachea el resultado y solo se recalcula si cambió algo
  // que realmente afecta la lista mostrada.
  List<ProductoModel>? _cacheProductos;
  String? _cacheVista;
  String? _cacheBusqueda;
  bool? _cacheBusquedaPorCodigo;
  String? _cacheColumnaOrden;
  bool? _cacheOrdenAscendente;
  List<ProductoModel> _cacheResultado = const [];

  List<ProductoModel> _listaFiltrada(List<ProductoModel> productos, String vista, String busqueda) {
    if (identical(productos, _cacheProductos) &&
        vista == _cacheVista &&
        busqueda == _cacheBusqueda &&
        _busquedaPorCodigoBarras == _cacheBusquedaPorCodigo &&
        _columnaOrden == _cacheColumnaOrden &&
        _ordenAscendente == _cacheOrdenAscendente) {
      return _cacheResultado;
    }
    var lista = productos;
    if (vista == 'bajo') {
      lista = lista.where((p) => p.stock < 3).toList();
    }
    if (busqueda.isNotEmpty) {
      lista = _busquedaPorCodigoBarras
          ? lista.where((p) => p.codigoBarras.trim() == busqueda || p.codigo.trim() == busqueda).toList()
          : lista.where((p) => coincideFuzzy(p.textoBusqueda, busqueda)).toList();
    } else if (vista == 'filtrados') {
      lista = [];
    }
    lista = _ordenarLista(lista);

    _cacheProductos = productos;
    _cacheVista = vista;
    _cacheBusqueda = busqueda;
    _cacheBusquedaPorCodigo = _busquedaPorCodigoBarras;
    _cacheColumnaOrden = _columnaOrden;
    _cacheOrdenAscendente = _ordenAscendente;
    _cacheResultado = lista;
    return lista;
  }

  // --- Alturas de fila variables (solo la que lo necesita) ----------------
  // Casi todos los nombres entran en una línea; cuando uno no entra, en vez
  // de recortarlo con "..." se mide con TextPainter (el mismo estilo/ancho
  // real de la columna NOMBRE) y esa fila puntual crece lo justo para
  // mostrarlo completo. El resultado se cachea por "nombre@ancho" porque la
  // medición es la única parte no trivial de este cálculo y los nombres se
  // repiten mucho entre pantallazos (scroll, reordenar, etc.).
  static const double _altoFilaBase = 65; // 64 de contenido + 1 de borde inferior
  static const double _altoLinea = 18;
  final Map<String, double> _alturaFilaCache = {};

  double _alturaFila(String nombre, double anchoColumnaNombre) {
    if (anchoColumnaNombre <= 0 || nombre.isEmpty) return _altoFilaBase;
    final clave = '$nombre@${anchoColumnaNombre.round()}';
    final cacheado = _alturaFilaCache[clave];
    if (cacheado != null) return cacheado;

    final tp = TextPainter(
      text: TextSpan(text: nombre, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
      maxLines: 6,
    )..layout(maxWidth: anchoColumnaNombre);
    final lineas = tp.computeLineMetrics().length.clamp(1, 6);
    final altura = lineas <= 2 ? _altoFilaBase : (28 + lineas * _altoLinea + 1);
    _alturaFilaCache[clave] = altura;
    return altura;
  }

  /// Precio de venta a mostrar según la vista elegida (con o sin ISV). El
  /// precio guardado en el producto siempre incluye ISV.
  double _precioMostrado(ProductoModel p) => _precioConIsv ? p.precioVenta : redondearMoneda(p.precioVenta / 1.15);

  // Igual que _listaFiltrada: sin esto, los badges de "valor compra/venta"
  // recorrían los 3400+ productos en CADA build (por ejemplo, cada vez que
  // se selecciona una fila) solo para mostrar el mismo número de antes.
  List<ProductoModel>? _cacheResumenProductos;
  bool? _cacheResumenConIsv;
  (double, double) _cacheResumenValores = (0, 0);

  (double, double) _resumenValores(List<ProductoModel> productos) {
    if (identical(productos, _cacheResumenProductos) && _precioConIsv == _cacheResumenConIsv) {
      return _cacheResumenValores;
    }
    double valorCompra = 0, valorVenta = 0;
    for (final p in productos) {
      valorCompra += p.stock * p.precioCompra;
      valorVenta += p.stock * _precioMostrado(p);
    }
    _cacheResumenProductos = productos;
    _cacheResumenConIsv = _precioConIsv;
    _cacheResumenValores = (valorCompra, valorVenta);
    return _cacheResumenValores;
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _buscar() {
    setState(() => _busquedaPorCodigoBarras = false);
    ref.read(inventarioBusquedaProvider.notifier).actualizar(_busquedaController.text.trim());
  }

  bool _coincideExacto(ProductoModel p, String texto) => p.codigoBarras.trim() == texto || p.codigo.trim() == texto;

  Future<void> _escanear() async {
    final codigo = await escanearCodigoBarras(context);
    if (codigo == null || codigo.isEmpty || !mounted) return;
    var texto = codigo.trim();
    final productos = ref.read(productosStreamProvider).value ?? [];
    // Si el código escaneado no matchea a nada, se prueban otras variantes
    // válidas del mismo código (ver variantesCodigoBarras): corrige tanto
    // el código leído al revés (algunos celulares) como el "0" que iPhone
    // agrega al principio de los códigos UPC-A (Android no lo agrega).
    if (!productos.any((p) => _coincideExacto(p, texto))) {
      for (final variante in variantesCodigoBarras(texto)) {
        if (productos.any((p) => _coincideExacto(p, variante))) {
          texto = variante;
          break;
        }
      }
    }
    _busquedaController.text = texto;
    setState(() => _busquedaPorCodigoBarras = true);
    ref.read(inventarioBusquedaProvider.notifier).actualizar(texto);
  }

  void _limpiarBusqueda() {
    _busquedaController.clear();
    ref.read(inventarioBusquedaProvider.notifier).actualizar('');
    setState(() {
      _filaSeleccionada = null;
      _busquedaPorCodigoBarras = false;
    });
  }

  Future<void> _abrirFormulario([ProductoModel? producto, bool soloLectura = false]) async {
    // El rol Roles.inventarioLectura tiene permiso libre (sin clave especial)
    // para editar código/nombre/ubicación de un producto existente -el
    // formulario mismo (edicionLimitada) le bloquea el resto de los campos-.
    if (producto != null && !soloLectura) {
      final autorizado = await verificarAccesoEspecial(context, ref, PermisosEspeciales.inventarioEditarProducto);
      if (!autorizado || !mounted) return;
    }
    if (!mounted) return;
    showDialog(context: context, builder: (context) => ProductoFormDialog(producto: producto, edicionLimitada: soloLectura && producto != null));
  }

  Future<void> _abrirAjusteStock(ProductoModel producto) async {
    final autorizado = await verificarAccesoEspecial(context, ref, PermisosEspeciales.inventarioAjustarStock);
    if (!autorizado || !mounted) return;
    showDialog(context: context, builder: (context) => AjusteStockDialog(producto: producto));
  }

  void _abrirHistorial(ProductoModel producto) {
    showDialog(context: context, builder: (context) => HistorialStockDialog(producto: producto));
  }

  void _abrirHistorialMovimientos(ProductoModel producto, String tipo) {
    showDialog(context: context, builder: (context) => HistorialMovimientosDialog(producto: producto, tipo: tipo));
  }

  void _abrirImportar() {
    showDialog(context: context, builder: (context) => const ImportarInventarioDialog());
  }

  Future<void> _exportarExcel(Map<String, String> mapaCategorias) async {
    if (_listaActual.isEmpty) return;
    final bytes = _servicioExport.generarExcel(_listaActual, mapaCategorias);
    await guardarOCompartirArchivo(bytes, 'inventario.xlsx');
  }

  void _exportarPdf(Map<String, String> mapaCategorias) {
    if (_listaActual.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => PdfPreviewDialog(
        titulo: 'Vista previa · Inventario',
        nombreArchivo: 'inventario.pdf',
        generarPdf: () => _servicioExport.generarPdfInventario(_listaActual, mapaCategorias),
      ),
    );
  }

  Future<void> _imprimirTicketGrid(Map<String, String> mapaCategorias) async {
    if (_listaActual.isEmpty) return;
    final campos = await showDialog<Set<String>>(context: context, builder: (context) => const TicketOpcionesDialog());
    if (campos == null || !mounted) return;
    final negocio = await ref.read(negocioRepositoryProvider).obtenerNegocioActual();
    if (!mounted) return;
    final impresora = negocio.impresoraTermicaUrl.isEmpty ? null : Printer(url: negocio.impresoraTermicaUrl, name: negocio.impresoraTermicaNombre);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => PdfPreviewDialog(
        titulo: 'Vista previa · Ticket',
        nombreArchivo: 'ticket_inventario.pdf',
        generarPdf: () => _servicioExport.generarPdfTicket(_listaActual, mapaCategorias, campos),
        impresora: impresora,
      ),
    );
  }

  Future<void> _abrirCodigoBarras(ProductoModel producto) async {
    final negocio = await ref.read(negocioRepositoryProvider).obtenerNegocioActual();
    if (!mounted) return;
    final impresora = negocio.impresoraEtiquetasUrl.isEmpty ? null : Printer(url: negocio.impresoraEtiquetasUrl, name: negocio.impresoraEtiquetasNombre);
    showDialog(
      context: context,
      builder: (context) => PdfPreviewDialog(
        titulo: 'Código de barras · ${producto.nombre}',
        nombreArchivo: 'codigo_${producto.codigo}.pdf',
        generarPdf: () => _servicioExport.generarPdfCodigoBarras(producto),
        impresora: impresora,
      ),
    );
  }

  void _alternarOrden(String columna) {
    setState(() {
      if (_columnaOrden == columna) {
        _ordenAscendente = !_ordenAscendente;
      } else {
        _columnaOrden = columna;
        _ordenAscendente = false;
      }
    });
  }

  List<ProductoModel> _ordenarLista(List<ProductoModel> lista) {
    if (_columnaOrden == null) return lista;
    final copia = [...lista];
    copia.sort((a, b) {
      int comparacion;
      switch (_columnaOrden) {
        case 'codigo':
          comparacion = a.codigo.compareTo(b.codigo);
          break;
        case 'nombre':
          comparacion = a.nombre.compareTo(b.nombre);
          break;
        case 'existencia':
          comparacion = a.stock.compareTo(b.stock);
          break;
        case 'precioVenta':
          comparacion = a.precioVenta.compareTo(b.precioVenta);
          break;
        case 'precioCompra':
          comparacion = a.precioCompra.compareTo(b.precioCompra);
          break;
        default:
          comparacion = 0;
      }
      return _ordenAscendente ? comparacion : -comparacion;
    });
    return copia;
  }

  void _moverSeleccion(int delta) {
    if (_listaActual.isEmpty) return;
    final indiceActual = _filaSeleccionada == null ? -1 : _listaActual.indexWhere((p) => p.id == _filaSeleccionada);
    var nuevoIndice = indiceActual + delta;
    if (nuevoIndice < 0) nuevoIndice = 0;
    if (nuevoIndice >= _listaActual.length) nuevoIndice = _listaActual.length - 1;
    setState(() => _filaSeleccionada = _listaActual[nuevoIndice].id);
    _desplazarHaciaFila(nuevoIndice);
  }

  /// Mueve el scroll de la tabla lo mínimo necesario para que la fila
  /// [indice] quede visible (arriba o abajo, según hacia dónde se navegó con
  /// las flechas) — sin esto, seleccionar con teclado podía "salirse" de la
  /// vista sin que el scroll acompañara.
  void _desplazarHaciaFila(int indice) {
    if (!_scrollController.hasClients || indice < 0 || indice >= _listaActual.length) return;
    var offsetInicio = 0.0;
    for (var i = 0; i < indice; i++) {
      offsetInicio += _alturaFila(_listaActual[i].nombre, _anchoColumnaNombreActual);
    }
    final offsetFin = offsetInicio + _alturaFila(_listaActual[indice].nombre, _anchoColumnaNombreActual);
    final posicion = _scrollController.position;
    final inicioVisible = posicion.pixels;
    final finVisible = posicion.pixels + posicion.viewportDimension;

    double? destino;
    if (offsetInicio < inicioVisible) {
      destino = offsetInicio;
    } else if (offsetFin > finVisible) {
      destino = offsetFin - posicion.viewportDimension;
    }
    if (destino == null) return;
    destino = destino.clamp(posicion.minScrollExtent, posicion.maxScrollExtent);
    _scrollController.animateTo(destino, duration: const Duration(milliseconds: 90), curve: Curves.easeOut);
  }

  KeyEventResult _manejarTeclado(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _moverSeleccion(1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _moverSeleccion(-1);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _tomarFoco() {
    if (!_focusNode.hasFocus) _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosStreamProvider);
    final categoriasAsync = ref.watch(categoriasStreamProvider);
    final busqueda = ref.watch(inventarioBusquedaProvider);
    final vista = ref.watch(inventarioVistaProvider);
    // Rol de acceso restringido a Inventario: solo ver, sin precios de costo,
    // sin totales de valor, sin editar/ajustar nada (ver Roles.inventarioLectura).
    final soloLectura = ref.watch(authProvider).usuario?.rol == Roles.inventarioLectura;
    final categoriasLista = categoriasAsync.value ?? <dynamic>[];
    final Map<String, String> mapaCategorias = {
      for (final c in categoriasLista) c.id as String: c.descripcion as String,
    };

    return Container(
      color: const Color(0xFFF2F3F7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final esMovil = constraints.maxWidth < 720;
          return Padding(
            padding: EdgeInsets.all(esMovil ? 14 : 26),
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      Text('Inventario', style: GoogleFonts.poppins(fontSize: esMovil ? 19 : 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                      productosAsync.when(
                        data: (productos) {
                          if (soloLectura) return _badgeInfo('${productos.length} productos', const Color(0xFF0D2B4E));
                          final (valorCompra, valorVenta) = _resumenValores(productos);
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _badgeInfo('${productos.length} productos', const Color(0xFF0D2B4E)),
                              _badgeInfo('Valor compra ${formatearMoneda(valorCompra)}', const Color(0xFF3B82F6)),
                              _badgeInfo('Valor venta (${_precioConIsv ? 'con' : 'sin'} ISV) ${formatearMoneda(valorVenta)}', const Color(0xFF16A34A)),
                            ],
                          );
                        },
                        loading: () => const SizedBox(),
                        error: (e, st) => const SizedBox(),
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(child: const SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(width: esMovil ? constraints.maxWidth : 220, child: _selectorVista(vista)),
                      _selectorPrecioIsv(),
                      SizedBox(width: esMovil ? constraints.maxWidth : 340, child: _buscador(busqueda)),
                      OutlinedButton.icon(
                        onPressed: () => ref.invalidate(productosStreamProvider),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text('Refrescar', style: GoogleFonts.poppins(fontSize: 13)),
                        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1A1A1A), side: const BorderSide(color: Color(0xFFB6BCC7)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                      if (!soloLectura) ...[
                        OutlinedButton.icon(
                          onPressed: _abrirImportar,
                          icon: const Icon(Icons.upload_file_outlined, size: 18),
                          label: Text('Importar', style: GoogleFonts.poppins(fontSize: 13)),
                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1A1A1A), side: const BorderSide(color: Color(0xFFB6BCC7)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _exportarExcel(mapaCategorias),
                          icon: const Icon(Icons.grid_on_outlined, size: 18),
                          label: Text('Excel', style: GoogleFonts.poppins(fontSize: 13)),
                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1A1A1A), side: const BorderSide(color: Color(0xFFB6BCC7)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _exportarPdf(mapaCategorias),
                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                          label: Text('PDF', style: GoogleFonts.poppins(fontSize: 13)),
                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1A1A1A), side: const BorderSide(color: Color(0xFFB6BCC7)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _imprimirTicketGrid(mapaCategorias),
                          icon: const Icon(Icons.receipt_long_outlined, size: 18),
                          label: Text('Ticket', style: GoogleFonts.poppins(fontSize: 13)),
                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1A1A1A), side: const BorderSide(color: Color(0xFFB6BCC7)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ],
                      // Crear productos nuevos queda con el formulario completo
                      // incluso para el rol de acceso limitado (pedido del
                      // dueño); lo único restringido es EDITAR un producto ya
                      // existente (ver ProductoFormDialog.edicionLimitada).
                      FilledButton.icon(
                        onPressed: () => _abrirFormulario(),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text('Nuevo Producto', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D2B4E), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(child: const SizedBox(height: 18)),
              ],
              body: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFAEB4C0), width: 1.3),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 26, offset: const Offset(0, 12))],
                ),
                child: productosAsync.when(
                      data: (productos) {
                        final lista = _listaFiltrada(productos, vista, busqueda);
                        _listaActual = lista;

                        if (lista.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(
                                  vista == 'filtrados' && busqueda.isEmpty ? 'Escribí algo y presioná buscar' : 'No hay productos encontrados',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          );
                        }

                        return Focus(
                          focusNode: _focusNode,
                          onKeyEvent: _manejarTeclado,
                          child: esMovil ? _tarjetas(lista, mapaCategorias, soloLectura) : _tabla(lista, mapaCategorias, soloLectura),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0D2B4E))),
                      error: (e, st) => Center(child: Text('Error: $e', style: GoogleFonts.poppins(color: Colors.red))),
                    ),
                  ),
            ),
          );
        },
      ),
    );
  }

  Widget _badgeInfo(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(texto, style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _tabla(List<ProductoModel> lista, Map<String, String> mapaCategorias, bool soloLectura) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final mostrarDescripcion = ancho >= 1050;
        final mostrarCategoria = ancho >= 850;

        // Ancho real (en píxeles) de la columna NOMBRE con este layout, para
        // saber cuántas líneas necesita cada nombre (ver _alturaFila). 76 es
        // el ancho fijo de la columna de acciones; 24 es el padding
        // horizontal de la celda (12 a cada lado).
        final totalFlex = 12 + 24 + (mostrarDescripcion ? 20 : 0) + (mostrarCategoria ? 17 : 0) + 12 + 14 + (soloLectura ? 0 : 14) + 11;
        final anchoContenido = (ancho - 76).clamp(0, double.infinity);
        final anchoColumnaNombre = (anchoContenido * (24 / totalFlex) - 24).clamp(0, double.infinity).toDouble();
        _anchoColumnaNombreActual = anchoColumnaNombre;

        return Column(
          children: [
            Container(
              height: 48,
              decoration: BoxDecoration(color: const Color(0xFFECEEF3), borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
              child: Row(
                children: [
                  _celdaHeader(texto: 'CÓDIGO', flex: 12, columnaOrdenKey: 'codigo'),
                  _celdaHeader(texto: 'NOMBRE', flex: 24, columnaOrdenKey: 'nombre'),
                  if (mostrarDescripcion) _celdaHeader(texto: 'UBICACIÓN', flex: 20),
                  if (mostrarCategoria) _celdaHeader(texto: 'CATEGORÍA', flex: 17),
                  _celdaHeader(texto: 'EXISTENCIA', flex: 12, columnaOrdenKey: 'existencia'),
                  _celdaHeader(texto: _precioConIsv ? 'P. VENTA (C/ISV)' : 'P. VENTA (S/ISV)', flex: 14, columnaOrdenKey: 'precioVenta'),
                  if (!soloLectura) _celdaHeader(texto: 'P. COMPRA', flex: 14, columnaOrdenKey: 'precioCompra'),
                  _celdaHeader(texto: 'ESTADO', flex: 11),
                  _celdaHeaderAcciones(),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                // itemExtentBuilder (en vez de un itemExtent fijo o de
                // ListView.separated) le da a Flutter el alto exacto de cada
                // fila SIN tener que medir/pintar las filas anteriores para
                // saber a qué offset corresponde cada posición de scroll —
                // eso es lo que hace fluido el scroll incluso con miles de
                // productos ("Mostrar todos") o al arrastrar la scrollbar.
                // Casi todas las filas miden lo mismo (_altoFilaBase); solo
                // las que tienen un nombre largo son más altas, y solo esa
                // fila puntual — no se agranda la tabla entera por eso.
                itemExtentBuilder: (index, dimensions) => _alturaFila(lista[index].nombre, anchoColumnaNombre),
                itemCount: lista.length,
                itemBuilder: (context, index) {
                  final producto = lista[index];
                  final bajoStock = producto.stock < 3;
                  final seleccionada = _filaSeleccionada == producto.id;
                  final altoFila = _alturaFila(producto.nombre, anchoColumnaNombre) - 1;

                  return InkWell(
                    onTap: () {
                      _tomarFoco();
                      setState(() => _filaSeleccionada = seleccionada ? null : producto.id);
                    },
                    child: Container(
                      // Alto fijo (calculado en _alturaFila) en vez de
                      // IntrinsicHeight: con alto fijo, Flutter no necesita un
                      // segundo pase de layout por fila para saber cuánto
                      // "estirar" cada celda, así que desplazarse por listas
                      // largas queda mucho más fluido.
                      height: altoFila,
                      decoration: BoxDecoration(
                        color: seleccionada ? const Color(0xFFE6E9F2) : Colors.white,
                        border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _celdaTabla(flex: 12, child: Text(producto.codigo, maxLines: 6, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF3F434A)))),
                          // El nombre prácticamente nunca se recorta: la altura
                          // de la fila ya se calculó (_alturaFila) midiendo
                          // cuántas líneas necesita (mismo tope de 6 líneas acá
                          // como red de seguridad si el ancho cambiara justo
                          // entre la medición y el pintado, ej. al redimensionar
                          // la ventana).
                          _celdaTabla(flex: 24, child: Text(producto.nombre, maxLines: 6, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A)))),
                          if (mostrarDescripcion)
                            _celdaTabla(flex: 20, child: Text(producto.descripcion.isEmpty ? '-' : producto.descripcion, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600))),
                          if (mostrarCategoria)
                            _celdaTabla(flex: 17, child: Text(mapaCategorias[producto.idCategoria] ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF3F434A)))),
                          _celdaTabla(
                            flex: 12,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: bajoStock ? const Color(0xFFFCE4E4) : const Color(0xFFEFF4FF), borderRadius: BorderRadius.circular(8)),
                                child: Text(producto.stock.toString(), style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700, color: bajoStock ? const Color(0xFF0D2B4E) : const Color(0xFF3B82F6))),
                              ),
                            ),
                          ),
                          _celdaTabla(flex: 14, child: Text(formatearMoneda(_precioMostrado(producto)), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF3F434A)))),
                          if (!soloLectura)
                            _celdaTabla(flex: 14, child: Text(formatearMoneda(producto.precioCompra), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF3F434A)))),
                          _celdaTabla(
                            flex: 11,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(color: producto.estado ? const Color(0xFFE8F8EE) : Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                                child: Text(producto.estado ? 'Activo' : 'Inactivo', maxLines: 1, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: producto.estado ? const Color(0xFF16A34A) : Colors.grey.shade600)),
                              ),
                            ),
                          ),
                          _celdaAcciones(producto, soloLectura),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tarjetas(List<ProductoModel> lista, Map<String, String> mapaCategorias, bool soloLectura) {
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: lista.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final p = lista[index];
        final bajoStock = p.stock < 3;
        final seleccionada = _filaSeleccionada == p.id;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            _tomarFoco();
            setState(() => _filaSeleccionada = seleccionada ? null : p.id);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: seleccionada ? const Color(0xFFE6E9F2) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: seleccionada ? const Color(0xFF0D2B4E) : const Color(0xFFC7CBD3))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(p.nombre, style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)))),
                    _celdaAccionesMovil(p, soloLectura),
                  ],
                ),
                if (p.descripcion.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(p.descripcion, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chipInfo('Código', p.codigo),
                    _chipInfo('Categoría', mapaCategorias[p.idCategoria] ?? '-'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: bajoStock ? const Color(0xFFFCE4E4) : const Color(0xFFEFF4FF), borderRadius: BorderRadius.circular(8)),
                      child: Text('Existencia: ${p.stock}', style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w700, color: bajoStock ? const Color(0xFF0D2B4E) : const Color(0xFF3B82F6))),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: p.estado ? const Color(0xFFE8F8EE) : Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                      child: Text(p.estado ? 'Activo' : 'Inactivo', style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: p.estado ? const Color(0xFF16A34A) : Colors.grey.shade600)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    Text('Venta (${_precioConIsv ? 'c/ISV' : 's/ISV'}): ${formatearMoneda(_precioMostrado(p))}', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    if (!soloLectura)
                      Text('Compra: ${formatearMoneda(p.precioCompra)}', style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chipInfo(String label, String valor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFE8EAF0), borderRadius: BorderRadius.circular(8)),
      child: Text('$label: $valor', style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF3F434A))),
    );
  }

  Widget _celdaHeader({required String texto, required int flex, String? columnaOrdenKey}) {
    final activa = columnaOrdenKey != null && _columnaOrden == columnaOrdenKey;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: columnaOrdenKey == null ? null : () => _alternarOrden(columnaOrdenKey),
        child: Container(
          height: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFD6D9E0), width: 1))),
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(texto, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w700, color: activa ? const Color(0xFF0D2B4E) : const Color(0xFF666A72), letterSpacing: 0.35)),
              ),
              if (columnaOrdenKey != null) ...[
                const SizedBox(width: 4),
                Icon(activa ? (_ordenAscendente ? Icons.arrow_upward : Icons.arrow_downward) : Icons.unfold_more, size: 13, color: activa ? const Color(0xFF0D2B4E) : Colors.grey.shade400),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _celdaHeaderAcciones() {
    return Container(width: 76, height: double.infinity, alignment: Alignment.center, child: Text('ACCIONES', maxLines: 1, style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w700, color: const Color(0xFF666A72), letterSpacing: 0.25)));
  }

  Widget _celdaTabla({required int flex, required Widget child}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFC7CBD3), width: 1))),
        alignment: Alignment.centerLeft,
        child: child,
      ),
    );
  }

  Widget _celdaAcciones(ProductoModel producto, bool soloLectura) {
    return Container(
      width: 76,
      height: double.infinity,
      alignment: Alignment.center,
      child: PopupMenuButton<String>(
        tooltip: 'Más acciones',
        padding: EdgeInsets.zero,
        icon: Container(width: 34, height: 34, decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(9), border: Border.all(color: const Color(0xFFDFE1E6))), child: const Icon(Icons.more_vert, size: 21, color: Color(0xFF454950))),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 8,
        position: PopupMenuPosition.under,
        onSelected: (valor) => _manejarAccion(valor, producto, soloLectura),
        itemBuilder: (context) => _opcionesMenu(soloLectura),
      ),
    );
  }

  Widget _celdaAccionesMovil(ProductoModel producto, bool soloLectura) {
    return PopupMenuButton<String>(
      tooltip: 'Más acciones',
      padding: EdgeInsets.zero,
      icon: Container(width: 32, height: 32, decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(9), border: Border.all(color: const Color(0xFFDFE1E6))), child: const Icon(Icons.more_vert, size: 19, color: Color(0xFF454950))),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      position: PopupMenuPosition.under,
      onSelected: (valor) => _manejarAccion(valor, producto, soloLectura),
      itemBuilder: (context) => _opcionesMenu(soloLectura),
    );
  }

  void _manejarAccion(String valor, ProductoModel producto, bool soloLectura) {
    switch (valor) {
      case 'editar':
        _abrirFormulario(producto, soloLectura);
        break;
      case 'ajustar':
        _abrirAjusteStock(producto);
        break;
      case 'historial_stock':
        _abrirHistorial(producto);
        break;
      case 'historial_ventas':
        _abrirHistorialMovimientos(producto, 'ventas');
        break;
      case 'historial_compras':
        _abrirHistorialMovimientos(producto, 'compras');
        break;
      case 'historial_traslados':
        _abrirHistorialMovimientos(producto, 'traslados');
        break;
      case 'codigo_barras':
        _abrirCodigoBarras(producto);
        break;
    }
  }

  List<PopupMenuEntry<String>> _opcionesMenu(bool soloLectura) {
    if (soloLectura) {
      return [
        _opcionMenu(valor: 'editar', icono: Icons.edit_outlined, texto: 'Editar código/nombre/ubicación'),
        const PopupMenuDivider(),
        _opcionMenu(valor: 'historial_stock', icono: Icons.history, texto: 'Historial de existencia'),
        _opcionMenu(valor: 'historial_ventas', icono: Icons.point_of_sale_outlined, texto: 'Historial de ventas'),
      ];
    }
    return [
      _opcionMenu(valor: 'editar', icono: Icons.edit_outlined, texto: 'Editar producto'),
      _opcionMenu(valor: 'ajustar', icono: Icons.tune, texto: 'Ajustar existencia'),
      const PopupMenuDivider(),
      _opcionMenu(valor: 'historial_stock', icono: Icons.history, texto: 'Historial de existencia'),
      _opcionMenu(valor: 'historial_ventas', icono: Icons.point_of_sale_outlined, texto: 'Historial de ventas'),
      _opcionMenu(valor: 'historial_compras', icono: Icons.shopping_cart_outlined, texto: 'Historial de compras'),
      _opcionMenu(valor: 'historial_traslados', icono: Icons.sync_alt, texto: 'Historial de traslados'),
      const PopupMenuDivider(),
      _opcionMenu(valor: 'codigo_barras', icono: Icons.qr_code_2_outlined, texto: 'Código de barras'),
    ];
  }

  PopupMenuItem<String> _opcionMenu({required String valor, required IconData icono, required String texto}) {
    return PopupMenuItem<String>(
      value: valor,
      height: 44,
      child: Row(children: [Icon(icono, size: 19, color: const Color(0xFF4B4F58)), const SizedBox(width: 12), Text(texto, style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF25272B)))]),
    );
  }

  Widget _selectorVista(String vista) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFB6BCC7))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: vista,
          isExpanded: true,
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF1A1A1A)),
          items: const [
            DropdownMenuItem(value: 'filtrados', child: Text('Productos filtrados')),
            DropdownMenuItem(value: 'todos', child: Text('Mostrar todos')),
            DropdownMenuItem(value: 'bajo', child: Text('Bajo existencia')),
          ],
          onChanged: (v) {
            if (v == null) return;
            ref.read(inventarioVistaProvider.notifier).actualizar(v);
          },
        ),
      ),
    );
  }

  Widget _selectorPrecioIsv() {
    Widget opcion(String texto, bool valor) {
      final activo = _precioConIsv == valor;
      return InkWell(
        onTap: () => setState(() => _precioConIsv = valor),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: activo ? const Color(0xFF0D2B4E) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            texto,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: activo ? Colors.white : const Color(0xFF666A72)),
          ),
        ),
      );
    }

    return Container(
      height: 46,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFB6BCC7))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          opcion('Con ISV', true),
          opcion('Sin ISV', false),
        ],
      ),
    );
  }

  Widget _buscador(String busqueda) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFB6BCC7))),
      child: Row(
        children: [
          Icon(Icons.search, size: 20, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _busquedaController,
              autofocus: true,
              style: GoogleFonts.poppins(fontSize: 13),
              decoration: InputDecoration(hintText: 'Buscar o escanear código de barras...', hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade400), border: InputBorder.none, isDense: true),
              onSubmitted: (_) => _buscar(),
            ),
          ),
          if (busqueda.isNotEmpty) IconButton(tooltip: 'Limpiar', icon: const Icon(Icons.close, size: 18), onPressed: _limpiarBusqueda),
          IconButton(tooltip: 'Escanear código de barras', icon: const Icon(Icons.qr_code_scanner, size: 20), onPressed: _escanear),
          IconButton(tooltip: 'Buscar', icon: const Icon(Icons.arrow_forward, size: 18), onPressed: _buscar),
        ],
      ),
    );
  }
}