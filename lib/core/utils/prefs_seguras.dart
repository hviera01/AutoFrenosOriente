import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Abre SharedPreferences sin dejar que un archivo local dañado tumbe la app
/// ni el login. En Windows las preferencias viven en un shared_preferences.json
/// que, tras un apagón o un cierre a la fuerza en pleno guardado, puede quedar
/// lleno de bytes nulos: la librería lo lee con json.decode y lanza
/// FormatException, y como pasa con cualquier usuario y clave, esa PC queda sin
/// poder entrar hasta que alguien borre el archivo a mano. Acá, si la lectura
/// falla, se borra el archivo dañado (solo guarda la tipografía y ajustes
/// locales, nada que no se pueda volver a elegir) y se reintenta. Si aun así
/// falla, devuelve null y quien llama sigue con los valores por defecto.
Future<SharedPreferences?> abrirPrefsSeguras() async {
  try {
    return await SharedPreferences.getInstance();
  } catch (_) {
    if (kIsWeb) return null;
    try {
      final carpeta = await getApplicationSupportDirectory();
      final archivo = File('${carpeta.path}${Platform.pathSeparator}shared_preferences.json');
      if (archivo.existsSync()) archivo.deleteSync();
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }
}
