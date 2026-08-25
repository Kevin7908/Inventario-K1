import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/share/dominio/permiso.dart';
import '../provider/auth_providers.dart';

/// Muestra [child] solo si la sesión abierta tiene [permiso].
///
/// Existe para que poner una compuerta cueste una línea. Sin esto, cada botón
/// que hay que esconder se vuelve un `Consumer` con su `if`, y la mitad se
/// quedan sin poner.
///
/// **No es seguridad, es orden.** El `.sqlite` está en el disco del taller y
/// quien tenga el equipo puede abrirlo con cualquier visor: lo que esto evita
/// es la equivocación —que el cajero borre un producto sin querer—, no a
/// alguien decidido a saltárselo. Lo que sí es una barrera de verdad son las
/// comprobaciones del repositorio, que miran la base y no la pantalla.
///
/// Parámetros:
/// - [permiso]: el que hace falta.
/// - [child]: qué mostrar si lo tiene.
/// - [alternativa]: qué mostrar si no. Por defecto, nada.
///
/// Ejemplo:
/// ```dart
/// SiPuede(
///   permiso: Permiso.productosEliminar,
///   child: BotonDestructivo(etiqueta: 'Eliminar', alPresionar: _borrar),
/// )
/// ```
class SiPuede extends ConsumerWidget {
  const SiPuede({
    super.key,
    required this.permiso,
    required this.child,
    this.alternativa,
  });

  final Permiso permiso;
  final Widget child;
  final Widget? alternativa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `puedeProvider` es una `family`: esta compuerta solo se reconstruye
    // cuando cambia **este** permiso, no cuando cambia cualquiera de los 41.
    return ref.watch(puedeProvider(permiso))
        ? child
        : (alternativa ?? const SizedBox.shrink());
  }
}

/// Igual que [SiPuede] pero deja el widget a la vista y **apagado**.
///
/// Se usa cuando esconder la acción confundiría más que mostrarla gris: en un
/// documento cerrado, un botón que desaparece hace pensar que la pantalla se
/// rompió.
///
/// [constructor] recibe `true` si la sesión tiene el permiso.
class SegunPermiso extends ConsumerWidget {
  const SegunPermiso({
    super.key,
    required this.permiso,
    required this.constructor,
  });

  final Permiso permiso;
  final Widget Function(BuildContext context, bool puede) constructor;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      constructor(context, ref.watch(puedeProvider(permiso)));
}
