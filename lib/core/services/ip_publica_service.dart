import 'dart:convert';
import 'package:http/http.dart' as http;

/// Consulta la IP pública actual del dispositivo (la que ve internet, no la
/// IP local de la red WiFi). Se usa para el acceso restringido por red del
/// rol [Roles.inventarioLectura] (ver AuthNotifier.login): al no haber
/// backend propio, esta es la única forma de saber "desde dónde" se está
/// conectando alguien sin depender de un servidor intermedio.
class IpPublicaService {
  static Future<String?> obtener() async {
    try {
      final respuesta = await http.get(Uri.parse('https://api.ipify.org?format=json')).timeout(const Duration(seconds: 8));
      if (respuesta.statusCode != 200) return null;
      final datos = jsonDecode(respuesta.body) as Map<String, dynamic>;
      final ip = datos['ip'] as String?;
      return (ip == null || ip.isEmpty) ? null : ip;
    } catch (_) {
      return null;
    }
  }
}
