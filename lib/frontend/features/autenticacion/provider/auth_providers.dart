import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/autenticacion/modelo/usuario.dart';
import '../../../../backend/features/autenticacion/repositorio/repositorio_auth.dart';
import '../../../../backend/features/autenticacion/repositorio/repositorio_auth_impl.dart';
import '../../../../backend/features/autenticacion/resultado/resultados_auth.dart';
import '../../../../backend/share/database/app_db_provider.dart';
import '../../../../backend/share/dominio/permiso.dart';
import '../../../../backend/share/dominio/sesion_actual.dart';
import '../../../../backend/share/servicios/servicio_correo.dart';
import '../../../../backend/share/servicios/servicio_verificacion.dart';

/// El repositorio de cuentas **sin firma**: el que atiende cuando todavía no
/// hay nadie dentro.
///
/// Lo usan el portal —para preguntar si existe alguna cuenta—, el login, el
/// alta del primer administrador y la lectura de permisos. Ninguna de esas
/// operaciones deja rastro en la bitácora, porque no hay a quién atribuirle
/// nada.
///
/// Existe aparte de [repositorioAuthProvider] por una razón concreta: aquél
/// depende de `sesionActualProvider`, y `sesionActualProvider` necesita leer
/// los permisos de la cuenta. Con un solo provider, eso sería un ciclo.
final repositorioAuthAnonimoProvider = Provider<RepositorioAuth>(
  name: 'repositorioAuthAnonimoProvider',
  (ref) => RepositorioAuthImpl(ref.watch(appDatabaseProvider)),
);

/// El repositorio de cuentas **firmado por quien tiene la sesión abierta**.
///
/// Es el que usa la pantalla de Usuarios: crear un cajero, activarlo o
/// cambiarle los permisos son cosas que la bitácora tiene que poder contar.
final repositorioAuthProvider = Provider<RepositorioAuth>(
  name: 'repositorioAuthProvider',
  (ref) => RepositorioAuthImpl(
    ref.watch(appDatabaseProvider),
    ref.watch(sesionActualProvider),
  ),
);

/// El servicio de correo de la app, armado con lo que traiga el `.env`.
///
/// Si el archivo no está, el servicio existe igual y responde
/// `CorreoNoConfigurado`: ninguna pantalla tiene que preguntar si hay correo
/// antes de intentar mandarlo.
final servicioCorreoProvider = Provider<ServicioCorreo>(
  name: 'servicioCorreoProvider',
  (ref) => ServicioCorreo.desdeEntorno(),
);

/// Los códigos de recuperación viven en memoria mientras la app corre, así que
/// el servicio tiene que ser el mismo para toda la sesión.
final servicioVerificacionProvider = Provider<ServicioVerificacion>(
  name: 'servicioVerificacionProvider',
  (ref) => ServicioVerificacion(),
);

/// ¿La base ya tiene alguna cuenta?
///
/// Es lo que decide si la app abre en el login o en «crear la cuenta del
/// administrador». Se invalida al crear la primera.
final hayUsuariosProvider = FutureProvider<bool>(
  name: 'hayUsuariosProvider',
  (ref) => ref.watch(repositorioAuthAnonimoProvider).hayUsuarios(),
);

/// Los permisos de quien tiene la sesión abierta, **en vivo**.
///
/// Se observan y no se leen una vez: quitarle un permiso a alguien tiene que
/// notarse sin obligarlo a volver a entrar. Sin sesión, el conjunto vacío.
final permisosSesionProvider = StreamProvider<Set<Permiso>>(
  name: 'permisosSesionProvider',
  (ref) {
    final usuario = ref.watch(usuarioEnSesionProvider);
    if (usuario == null) return Stream.value(const <Permiso>{});
    return ref.watch(repositorioAuthAnonimoProvider).observarPermisos(usuario.id);
  },
);

/// La sesión tal como la ve el backend: quién es y qué puede hacer.
///
/// **Es la dependencia que Riverpod le inyecta a cada repositorio** por el
/// constructor. Cuando cambia —alguien entra, sale o le cambian los
/// permisos—, los repositorios se reconstruyen con la firma nueva. Pasa dos o
/// tres veces por turno: no es un coste que se note.
final sesionActualProvider = Provider<SesionActual?>(
  name: 'sesionActualProvider',
  (ref) {
    final usuario = ref.watch(usuarioEnSesionProvider);
    if (usuario == null) return null;

    return SesionActual(
      usuarioId: usuario.id,
      rol: usuario.rol,
      permisos: ref.watch(permisosSesionProvider).value ?? const {},
    );
  },
);

/// ¿La sesión abierta puede hacer esto? Atajo para las vistas.
///
/// Es una `family`, así que dos pantallas que preguntan por el mismo permiso
/// comparten el cálculo y solo se reconstruyen cuando **ese** permiso cambia.
final puedeProvider = Provider.family<bool, Permiso>(
  name: 'puedeProvider',
  (ref, permiso) =>
      ref.watch(permisosSesionProvider).value?.contains(permiso) ?? false,
);

/// Quién está usando la app en este momento, o `null` si nadie.
///
/// **No se guarda en disco.** Cada arranque pide usuario y contraseña: es un
/// equipo de mostrador, a la vista de quien pase, y en cuanto cada movimiento
/// de inventario lleve su autor, una sesión heredada del turno anterior le
/// atribuiría las ventas a quien no las hizo.
final class SesionNotifier extends AsyncNotifier<Usuario?> {
  @override
  FutureOr<Usuario?> build() => null;

  /// Intenta entrar. Devuelve el resultado para que la vista decida el texto;
  /// el estado solo cambia cuando el acceso se concede.
  Future<ResultadoAcceso> entrar({
    required String identificador,
    required String password,
  }) async {
    // El estado no pasa por `AsyncLoading`: quien espera es el formulario, que
    // ya tiene su propia bandera. Ponerlo en carga aquí haría que el portal
    // viera «sin usuario» y repintara el login a mitad del intento.
    final resultado =
        await ref.read(repositorioAuthAnonimoProvider).autenticar(
          identificador: identificador,
          password: password,
        );

    state = AsyncData(resultado is AccesoConcedido ? resultado.usuario : null);
    return resultado;
  }

  /// Deja entrar sin volver a pedir credenciales. La usa la creación del
  /// primer administrador, que acaba de escribir su propia contraseña.
  void abrirSesionCon(Usuario usuario) => state = AsyncData(usuario);

  void salir() => state = const AsyncData(null);

  /// Vuelve a leer de la base al usuario en sesión.
  ///
  /// Hace falta cuando un administrador se cambia el nombre o el rol a sí
  /// mismo: sin esto, el encabezado seguiría mostrando lo anterior hasta el
  /// siguiente arranque.
  Future<void> refrescar() async {
    final actual = state.value;
    if (actual == null) return;
    state = AsyncData(
      await ref.read(repositorioAuthAnonimoProvider).obtenerPorId(actual.id),
    );
  }
}

final sesionProvider = AsyncNotifierProvider<SesionNotifier, Usuario?>(
  SesionNotifier.new,
  name: 'sesionProvider',
);

/// El usuario en sesión, o `null`. Atajo para las pantallas que solo quieren
/// leerlo sin manejar el `AsyncValue`.
final usuarioEnSesionProvider = Provider<Usuario?>(
  name: 'usuarioEnSesionProvider',
  (ref) => ref.watch(sesionProvider).value,
);
