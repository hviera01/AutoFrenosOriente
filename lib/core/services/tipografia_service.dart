import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tipografías que el usuario puede elegir para toda la interfaz (no afecta
/// los tickets/PDF impresos, esos usan su propia fuente fija en pdf_tema.dart).
/// La clave es el nombre exacto que espera GoogleFonts.getFont().
const Map<String, String> tipografiasDisponibles = {
  'Poppins': 'Poppins (predeterminada)',
  'Montserrat': 'Montserrat (más gruesa)',
  'Nunito': 'Nunito',
  'Roboto': 'Roboto',
  'Inter': 'Inter',
};

/// Valor sincrónico leído por [appFont] en cada Text de la app. Se inicializa
/// en main() antes de runApp (leyendo SharedPreferences) para que no haya
/// parpadeo entre la fuente por defecto y la guardada.
class TipografiaApp {
  static String actual = 'Poppins';
}

/// Notifier de Riverpod: solo lo observa el widget raíz (SistemaVentasApp)
/// para forzar la reconstrucción de todo el árbol cuando el usuario cambia
/// de fuente -no hace falta que cada pantalla lo escuche por separado-.
class TipografiaNotifier extends Notifier<String> {
  @override
  String build() => TipografiaApp.actual;

  Future<void> establecer(String fuente) async {
    TipografiaApp.actual = fuente;
    state = fuente;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fuente_app', fuente);
  }
}

final tipografiaProvider = NotifierProvider<TipografiaNotifier, String>(TipografiaNotifier.new);

/// Reemplazo de GoogleFonts.poppins(...) usado en toda la app: misma firma,
/// pero resuelve la familia según la preferencia guardada en vez de dejarla
/// fija en Poppins.
TextStyle appFont({
  TextStyle? textStyle,
  Color? color,
  Color? backgroundColor,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  double? letterSpacing,
  double? wordSpacing,
  TextBaseline? textBaseline,
  double? height,
  Locale? locale,
  Paint? foreground,
  Paint? background,
  List<ui.Shadow>? shadows,
  List<ui.FontFeature>? fontFeatures,
  TextDecoration? decoration,
  Color? decorationColor,
  TextDecorationStyle? decorationStyle,
  double? decorationThickness,
}) {
  return GoogleFonts.getFont(
    TipografiaApp.actual,
    textStyle: textStyle,
    color: color,
    backgroundColor: backgroundColor,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    letterSpacing: letterSpacing,
    wordSpacing: wordSpacing,
    textBaseline: textBaseline,
    height: height,
    locale: locale,
    foreground: foreground,
    background: background,
    shadows: shadows,
    fontFeatures: fontFeatures,
    decoration: decoration,
    decorationColor: decorationColor,
    decorationStyle: decorationStyle,
    decorationThickness: decorationThickness,
  );
}
