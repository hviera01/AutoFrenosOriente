/// Versión sin operación para plataformas donde `dart:ffi`/`package:win32`
/// no existen (Web, la que importa esto en tiempo de compilación). Nunca se
/// llega a invocar de verdad: todos los que llaman a
/// ImpresoraUsbWindowsService ya lo hacen detrás de un chequeo
/// `!kIsWeb && Platform.isWindows`. Ver impresora_usb_windows_service.dart.
class ImpresoraUsbWindowsService {
  bool imprimir({required String nombreImpresora, required List<int> bytes}) => false;
}
