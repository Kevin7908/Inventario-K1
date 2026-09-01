import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/autenticacion/modelo/usuario.dart';
import '../../../share/share.dart';
import '../provider/usuarios_provider.dart';

/// «¿Quién?»: el desplegable de cuentas del taller, con «Cualquiera» arriba.
///
/// Vive en el módulo de autenticación —el dueño del dato— y no en `share`,
/// porque observa `usuariosProvider` y conoce `Usuario`. Lo importan la
/// bitácora y el kardex, que hacen la misma pregunta sobre tablas distintas:
/// quién anotó el renglón, quién movió el stock.
///
/// **Una cuenta borrada sigue apareciendo en sus renglones viejos**, así que
/// [usuarioId] puede no estar en la lista. Entonces se agrega como una opción
/// más, rotulada «Cuenta #7»: `DropdownButton` **revienta** —con un assert—
/// si su valor no corresponde a exactamente un ítem, así que enseñar el
/// número no es solo cortesía, es lo que evita que la pantalla se caiga.
///
/// Parámetros:
/// - [usuarioId]: la cuenta elegida, o `null` para «Cualquiera».
/// - [alCambiar]: recibe el id elegido, o `null` al volver a «Cualquiera».
/// - [etiqueta]: el rótulo del campo. Por defecto, «Quién».
///
/// Ejemplo:
/// ```dart
/// SelectorCuenta(
///   usuarioId: estado.usuarioId,
///   alCambiar: notifier.filtrarPorUsuario,
/// )
/// ```
class SelectorCuenta extends ConsumerWidget {
  const SelectorCuenta({
    super.key,
    required this.usuarioId,
    required this.alCambiar,
    this.etiqueta = 'Quién',
  });

  /// El valor que representa «cualquiera». `null` no sirve: `SelectorWidget`
  /// lo usaría como «sin elegir» y no lo pintaría.
  static const _todos = 'TODOS';

  final int? usuarioId;
  final ValueChanged<int?> alCambiar;
  final String etiqueta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cuentas = ref.watch(usuariosProvider).value ?? const <Usuario>[];

    final opciones = [_todos, for (final c in cuentas) c.id.toString()];

    // La elegida entra aunque ya no esté en la lista. Ver el docstring: sin
    // esto el desplegable no encuentra su valor y lanza.
    final elegida = usuarioId?.toString();
    if (elegida != null && !opciones.contains(elegida)) opciones.add(elegida);

    return SelectorWidget<String>(
      etiqueta: etiqueta,
      valor: elegida ?? _todos,
      opciones: opciones,
      constructorEtiqueta: (valor) =>
          valor == _todos ? 'Cualquiera' : _nombreDe(cuentas, int.parse(valor)),
      alCambiar: (valor) => alCambiar(valor == _todos ? null : int.parse(valor)),
    );
  }

  static String _nombreDe(List<Usuario> cuentas, int id) {
    for (final cuenta in cuentas) {
      if (cuenta.id == id) return cuenta.nombre;
    }
    return 'Cuenta #$id';
  }
}
