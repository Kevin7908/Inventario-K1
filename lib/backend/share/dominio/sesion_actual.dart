import 'permiso.dart';
import 'rol_usuario.dart';

/// Quién está usando la app, tal como lo ve el backend.
///
/// **Es una dependencia del repositorio, no un registro global.** Se la pasa
/// Riverpod por el constructor —`RepositorioX(db, ref.watch(sesionActualProvider))`—,
/// así que mirar el constructor basta para saber que ese repositorio firma lo
/// que escribe, y un test le pasa la sesión que quiera sin montar nada global.
///
/// Ese es justo el punto que `CLAUDE.md` §3 marca contra el service location:
/// lo que estaba prohibido no era *tener* una sesión, era que las clases
/// fueran a buscarla a un registro y escondieran la dependencia.
///
/// No lleva el nombre del usuario: para mostrarlo está el `JOIN` con
/// `usuarios`, y guardar aquí una copia sería un dato repetido.
final class SesionActual {
  const SesionActual({
    required this.usuarioId,
    required this.rol,
    required this.permisos,
  });

  final int usuarioId;
  final RolUsuario rol;

  /// Lo que esta cuenta puede hacer, ya resuelto: para un administrador son
  /// todos, para los demás su fila de `usuario_permisos`.
  final Set<Permiso> permisos;

  bool puede(Permiso permiso) => permisos.contains(permiso);
}

/// Le da a un repositorio la firma de quien escribe.
///
/// Existe para no repetir seis veces el mismo getter con el mismo comentario.
/// El repositorio declara `final SesionActual? sesion` y obtiene [autorId].
mixin FirmaDeSesion {
  /// Quién tiene la sesión abierta. `null` solo antes del login.
  SesionActual? get sesion;

  /// El id que firma la escritura.
  ///
  /// Lanza si no hay sesión, y eso es lo correcto: **no es un error del
  /// usuario, es un error de programación**. Toda la app vive detrás del
  /// portal de sesión, así que ninguna pantalla capaz de escribir existe
  /// mientras esto sea `null`. Devolver un `Fallo` obligaría a cada vista a
  /// explicar un caso que no puede pasar; reventar aquí lo deja a la vista en
  /// el primer test que lo intente.
  int get autorId {
    final abierta = sesion;
    if (abierta == null) {
      throw StateError(
        'Se intentó escribir sin sesión abierta. El repositorio se construyó '
        'antes del login, o alguien lo instanció a mano sin pasar la sesión.',
      );
    }
    return abierta.usuarioId;
  }

  /// ¿La sesión abierta puede hacer esto?
  ///
  /// Sin sesión, no. Es la misma regla de [autorId] pero sin reventar, para
  /// las comprobaciones que devuelven un fallo en vez de escribir.
  bool puede(Permiso permiso) => sesion?.puede(permiso) ?? false;

  /// Corta la operación si la sesión no tiene [permiso].
  ///
  /// **Esta es la compuerta que vale.** La pantalla esconde los botones, pero
  /// eso es orden, no control: quien llegue por otro camino —un atajo de
  /// teclado, una pantalla a la que se le olvidó la compuerta— se topa igual
  /// con esto. Y como el conjunto de permisos viene de la base y no de la
  /// vista, no hay forma de mentirle desde arriba.
  ///
  /// **Lanza síncronamente.** Va como primera línea del método, así que en los
  /// de cuerpo síncrono —los que hacen `return _db.transaction(...)`— la
  /// excepción sale antes de que exista el `Future`. Quien llame con `await`
  /// dentro de un `try` la atrapa igual; quien encadene un `.catchError` sobre
  /// el `Future`, no.
  void exigir(Permiso permiso) {
    if (!puede(permiso)) throw PermisoDenegado(permiso);
  }
}

/// La sesión abierta intentó algo que su cuenta no tiene permitido.
///
/// Es una excepción y no un `Fallo` porque casi todos los métodos afectados
/// devuelven `Future<void>` o la entidad creada, y cambiarles la firma a
/// `Resultado` sería el churn que esta arquitectura evitó a propósito. La
/// vista la traduce a un mensaje; los métodos que **sí** devuelven `Resultado`
/// no la lanzan, devuelven `Fallo(MotivoFallo.validacion, ...)`.
final class PermisoDenegado implements Exception {
  const PermisoDenegado(this.permiso);

  final Permiso permiso;

  /// Ya redactado para la vista: nombra la acción que faltó, no el código.
  String get mensaje =>
      'Tu cuenta no tiene permiso para ${permiso.etiqueta.toLowerCase()}. '
      'Pídeselo a un administrador del taller.';

  @override
  String toString() => mensaje;
}
