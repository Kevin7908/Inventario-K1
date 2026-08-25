import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/autenticacion/modelo/usuario.dart';
import '../../../../backend/features/autenticacion/resultado/resultados_auth.dart';
import '../../../../backend/share/dominio/permiso.dart';
import '../../../../backend/share/dominio/rol_usuario.dart';
import '../../../../core/resultado.dart';
import 'auth_providers.dart';

/// Todas las cuentas, en vivo. Solo la mira la pantalla de administración.
final usuariosProvider = StreamProvider<List<Usuario>>(
  name: 'usuariosProvider',
  (ref) => ref.watch(repositorioAuthProvider).observarUsuarios(),
);

/// Los permisos guardados de una cuenta, en vivo.
///
/// `family` por id: la pantalla de permisos observa solo la cuenta que está
/// editando, no las demás.
final permisosDeProvider = StreamProvider.family<Set<Permiso>, int>(
  name: 'permisosDeProvider',
  (ref, usuarioId) =>
      ref.watch(repositorioAuthAnonimoProvider).observarPermisos(usuarioId),
);

/// Lo que un administrador puede hacerle a las cuentas.
///
/// El `adminId` no se pide por parámetro: sale de la sesión, que es la única
/// fuente fiable de quién está pidiendo el cambio. El repositorio lo vuelve a
/// comprobar contra la base, que es donde manda.
final class AccionesUsuariosNotifier extends Notifier<bool> {
  /// `true` mientras una operación está en curso: la tabla deshabilita sus
  /// controles para que no se disparen dos cambios sobre la misma fila.
  @override
  bool build() => false;

  Future<ResultadoCuenta> crear({
    required String nombre,
    required String usuario,
    required String email,
    required String password,
    required RolUsuario rol,
    String? documento,
  }) async {
    if (state) return const CuentaNoGuardada('Hay otra operación en curso.');
    state = true;

    final resultado = await ref.read(repositorioAuthProvider).crearCuenta(
          nombre: nombre,
          usuario: usuario,
          email: email,
          password: password,
          rol: rol,
          documento: documento,
        );

    // El correo se manda aparte y no se espera: que el servidor SMTP esté
    // lento no puede dejar el diálogo abierto, y la cuenta ya quedó creada.
    if (resultado case CuentaCreada(usuario: final creada)
        when creada.tieneCorreo) {
      unawaited(
        ref.read(servicioCorreoProvider).enviarBienvenida(
              email: creada.email,
              nombre: creada.nombre,
              usuario: creada.usuario,
              rol: creada.rol.etiqueta,
            ),
      );
    }

    state = false;
    return resultado;
  }

  Future<Resultado> cambiarEstado(Usuario cuenta, {required bool activa}) =>
      _conAdmin((adminId) async {
        final resultado = await ref.read(repositorioAuthProvider).cambiarEstado(
              adminId: adminId,
              usuarioId: cuenta.id,
              activo: activa,
            );

        if (resultado.exitoso && cuenta.tieneCorreo) {
          unawaited(
            ref.read(servicioCorreoProvider).enviarCambioDeEstado(
                  email: cuenta.email,
                  nombre: cuenta.nombre,
                  activa: activa,
                ),
          );
        }
        return resultado;
      });

  Future<Resultado> cambiarRol(Usuario cuenta, RolUsuario rol) =>
      _conAdmin((adminId) async {
        final resultado = await ref.read(repositorioAuthProvider).cambiarRol(
              adminId: adminId,
              usuarioId: cuenta.id,
              rol: rol,
            );

        // Un administrador puede cambiarse el rol a sí mismo; sin esto el
        // encabezado seguiría diciendo «Administrador».
        if (resultado.exitoso && cuenta.id == adminId) {
          await ref.read(sesionProvider.notifier).refrescar();
        }
        return resultado;
      });

  Future<Resultado> fijarPermisos(Usuario cuenta, Set<Permiso> permisos) =>
      _conAdmin((adminId) async {
        final resultado = await ref.read(repositorioAuthProvider).fijarPermisos(
              adminId: adminId,
              usuarioId: cuenta.id,
              permisos: permisos,
            );

        // Si el administrador se cambió los permisos a sí mismo —no puede,
        // pero la comprobación vive en el repositorio— la sesión tiene que
        // enterarse igual.
        if (resultado.exitoso && cuenta.id == adminId) {
          await ref.read(sesionProvider.notifier).refrescar();
        }
        return resultado;
      });

  Future<Resultado> _conAdmin(
    Future<Resultado> Function(int adminId) accion,
  ) async {
    final admin = ref.read(usuarioEnSesionProvider);
    if (admin == null) {
      return const Fallo(MotivoFallo.validacion, 'No hay sesión abierta.');
    }
    if (state) {
      return const Fallo(
        MotivoFallo.validacion,
        'Hay otra operación en curso.',
      );
    }

    state = true;
    try {
      return await accion(admin.id);
    } finally {
      state = false;
    }
  }
}

final accionesUsuariosProvider =
    NotifierProvider<AccionesUsuariosNotifier, bool>(
  AccionesUsuariosNotifier.new,
  name: 'accionesUsuariosProvider',
);
