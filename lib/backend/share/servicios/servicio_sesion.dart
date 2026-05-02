import 'package:shared_preferences/shared_preferences.dart';

/// Modelo liviano de sesión persistida localmente.
/// No contiene el hash de contraseña, solo datos de presentación.
class DatosSesion {
  final int userId;
  final String nombre;
  final String email;
  final bool esAdmin;

  const DatosSesion({
    required this.userId,
    required this.nombre,
    required this.email,
    required this.esAdmin,
  });
}

/// Persiste y restaura la sesión activa usando SharedPreferences.
///
/// Claves usadas (todas con prefijo _k para evitar colisiones):
///   _kUserId, _kNombre, _kEmail, _kEsAdmin
///
/// Nota: No almacena tokens ni contraseñas. Solo metadatos para
/// restaurar la UI sin forzar un nuevo login cuando la app se reinicia.
class ServicioSesion {
  static const _kUserId  = 'sesion_user_id';
  static const _kNombre  = 'sesion_nombre';
  static const _kEmail   = 'sesion_email';
  static const _kEsAdmin = 'sesion_es_admin';

  // ─── Guardar ───────────────────────────────────────────────────────────────

  Future<void> guardarSesion({
    required int userId,
    required String nombre,
    required String email,
    required bool esAdmin,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setInt(_kUserId, userId),
      prefs.setString(_kNombre, nombre),
      prefs.setString(_kEmail, email),
      prefs.setBool(_kEsAdmin, esAdmin),
    ]);
  }

  // ─── Leer ──────────────────────────────────────────────────────────────────

  /// Retorna [DatosSesion] si hay sesión guardada, o null si no existe.
  Future<DatosSesion?> leerSesion() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_kUserId);
    if (userId == null) return null;

    return DatosSesion(
      userId: userId,
      nombre: prefs.getString(_kNombre) ?? '',
      email:  prefs.getString(_kEmail)  ?? '',
      esAdmin: prefs.getBool(_kEsAdmin) ?? false,
    );
  }

  // ─── Cerrar ────────────────────────────────────────────────────────────────

  /// Elimina todos los datos de sesión guardados localmente.
  Future<void> cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_kUserId),
      prefs.remove(_kNombre),
      prefs.remove(_kEmail),
      prefs.remove(_kEsAdmin),
    ]);
  }
}