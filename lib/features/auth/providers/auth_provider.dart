import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/auth_repository.dart';
import '../data/usuario_model.dart';
import '../../../core/providers/tabs_provider.dart';
import '../../../core/constants/roles.dart';
import '../../../core/services/ip_publica_service.dart';
import '../../negocio/providers/negocio_provider.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository());

class AuthState {
  final UsuarioModel? usuario;
  final bool cargando;
  final String? error;
  // true cuando Roles.inventarioLectura intentó entrar fuera del horario
  // permitido: LoginScreen reacciona pidiendo la clave especial para
  // autorizar ese login puntual (ver AuthNotifier._dentroDeHorarioPermitido).
  final bool requiereAutorizacionHorario;

  AuthState({this.usuario, this.cargando = false, this.error, this.requiereAutorizacionHorario = false});
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    return AuthState();
  }

  // Lunes a sábado, 6:30am a 6:00pm -pedido explícito del dueño para el rol
  // Roles.inventarioLectura-. Hardcodeado a propósito (no hay pantalla para
  // configurarlo); si en algún momento hace falta ajustarlo se cambia acá.
  static const _horarioInicioMin = 6 * 60 + 30;
  static const _horarioFinMin = 18 * 60;

  bool _dentroDeHorarioPermitido() {
    final ahora = DateTime.now();
    if (ahora.weekday == DateTime.sunday) return false;
    final minutos = ahora.hour * 60 + ahora.minute;
    return minutos >= _horarioInicioMin && minutos <= _horarioFinMin;
  }

  /// [autorizacionEspecial] en true salta el chequeo de horario (no el de
  /// plataforma ni el de red): lo pasa LoginScreen después de que el admin
  /// confirma la clave especial para un login puntual fuera de horario.
  Future<void> login(String documento, String clave, {bool autorizacionEspecial = false}) async {
    state = AuthState(cargando: true);
    try {
      final usuario = await ref.read(authRepositoryProvider).login(documento, clave);

      // El rol de solo-lectura a Inventario existe justamente para dar
      // acceso a alguien sin que pueda entrar "desde donde quiera" -pedido
      // explícito del dueño, después de que se filtró el link web móvil-:
      if (usuario.rol == Roles.inventarioLectura) {
        // 1) Solo la app de Windows del negocio: bloquea el APK de Android
        // y CUALQUIER acceso web (de PC o de celular) sin excepción -es
        // justo el link web el que se filtró, así que no hay forma de
        // autorizar esto con la clave especial, a diferencia del horario-.
        if (kIsWeb || !Platform.isWindows) {
          throw Exception('Este usuario solo puede acceder desde la PC del negocio, no desde el celular ni la web.');
        }
        // 2) Horario: lunes a sábado, 6:30am-6:00pm. Fuera de ese horario no
        // se bloquea directo: se le pide a LoginScreen mostrar el diálogo de
        // clave especial para que el admin autorice el login puntual.
        if (!autorizacionEspecial && !_dentroDeHorarioPermitido()) {
          state = AuthState(requiereAutorizacionHorario: true);
          return;
        }
        // 3) Red (opcional, solo si el negocio configuró IPs permitidas):
        // con el candado de plataforma de arriba esto ya es una capa extra,
        // útil sobre todo si la PC del negocio fuera una laptop que se
        // pudiera sacar del local.
        final negocio = await ref.read(negocioRepositoryProvider).obtenerNegocioActual();
        final permitidas = negocio.ipsPermitidasInventarioLectura.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
        if (permitidas.isNotEmpty) {
          final ipActual = await IpPublicaService.obtener();
          if (ipActual == null || !permitidas.contains(ipActual)) {
            throw Exception('Este usuario solo puede acceder desde la red del negocio.');
          }
        }
      }

      state = AuthState(usuario: usuario);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('usuario_id', usuario.id);

      // Precarga (sin esperar) la configuración del negocio para que, una
      // vez adentro, acciones como pedir la clave especial o abrir el
      // código de barras no tengan que esperar la primera ida y vuelta a
      // Firestore: ya quedó resuelta durante el login.
      unawaited(ref.read(negocioRepositoryProvider).obtenerNegocioActual());
    } catch (e) {
      state = AuthState(error: e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// El admin canceló o puso mal la clave especial en el diálogo de
  /// autorización fuera de horario (ver LoginScreen._pedirAutorizacionHorario).
  void cancelarAutorizacionHorario() {
    state = AuthState(error: 'Acceso fuera del horario permitido. Pedile al administrador que te autorice con la clave especial.');
  }

 Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('usuario_id');
    state = AuthState();
    ref.invalidate(tabsProvider);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);