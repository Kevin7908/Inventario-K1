import '../modelo/persona.dart';

/// Papel que una persona cumple en el taller.
///
/// Cada valor es una tabla distinta que apunta a `personas`. Una persona puede
/// tener varios a la vez: el mecánico que además le compra repuestos al taller
/// es técnico y cliente con un solo teléfono y un solo correo.
enum RolPersona {
  cliente('Cliente'),
  tecnico('Técnico'),
  proveedor('Proveedor'),
  usuario('Usuario');

  const RolPersona(this.etiqueta);

  final String etiqueta;
}

/// Una persona ya registrada junto a los roles que hoy tiene.
///
/// Es lo que necesita el formulario para decidir entre «esta cédula ya está
/// registrada como cliente» (error) y «ya está registrada como técnico;
/// se reutilizarán sus datos» (aviso).
final class PersonaConRoles {
  const PersonaConRoles({required this.persona, required this.roles});

  final DatosPersona persona;
  final Set<RolPersona> roles;

  bool tieneRol(RolPersona rol) => roles.contains(rol);

  /// «Técnico y Proveedor», listo para el mensaje de la vista.
  String get rolesEnTexto {
    final nombres = roles.map((r) => r.etiqueta).toList();
    if (nombres.isEmpty) return '';
    if (nombres.length == 1) return nombres.single;
    return '${nombres.take(nombres.length - 1).join(', ')} y ${nombres.last}';
  }
}

abstract class RepositorioPersona {
  /// Busca a alguien por su documento, ya normalizado internamente.
  ///
  /// Devuelve `null` si nadie lo tiene. Es la consulta que dispara el flujo de
  /// reutilización: antes de crear un cliente, el formulario pregunta aquí.
  Future<PersonaConRoles?> buscarPorDocumento(String documento);

  Future<DatosPersona?> obtenerPorId(int id);

  /// Cómo se llama quien ya tiene ese teléfono, o `null` si está libre.
  ///
  /// El teléfono es único en `personas`, así que el choque puede ser con
  /// cualquier rol: el número que se teclea para un cliente puede ser el del
  /// proveedor de al lado. Devolver el nombre —y no un `bool`— es lo que
  /// permite que el mensaje diga de quién es en vez de solo que está ocupado.
  ///
  /// [excluirPersonaId] deja fuera a la propia ficha al editarla; sin eso,
  /// guardar sin tocar el teléfono se rechazaría a sí mismo.
  Future<String?> duenoDeTelefono(String telefono, {int? excluirPersonaId});

  /// Crea la persona, o actualiza la que ya tenga ese documento.
  ///
  /// Devuelve el id de la fila en `personas`. Es la pieza que reutilizan los
  /// repositorios de rol: la llaman **dentro** de su propia transacción, y
  /// Drift la propaga por zona mientras se use la misma instancia de `AppDb`.
  ///
  /// Reglas, en orden:
  /// 1. Si [datos] trae `personaId`, actualiza esa fila.
  /// 2. Si no, y trae documento, busca por documento: si existe la actualiza
  ///    con los datos nuevos —son los que el usuario acaba de teclear— y
  ///    devuelve su id.
  /// 3. Si no hay documento, inserta una persona nueva. Sin documento no hay
  ///    forma de saber que dos registros son la misma persona.
  Future<int> guardar(DatosPersona datos);

  /// Borra la persona si ya no le queda ningún rol.
  ///
  /// La llaman los repositorios de rol al eliminar: sin esto, dar de baja al
  /// único cliente dejaría una fila huérfana en `personas` que volvería a
  /// aparecer al teclear su cédula.
  Future<void> borrarSiQuedoSinRoles(int personaId);
}
