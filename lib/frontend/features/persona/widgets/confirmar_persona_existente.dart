import 'package:flutter/material.dart';

import '../../../../backend/features/persona/repositorio/repositorio_persona.dart';
import '../../../share2/share2.dart';

/// Pregunta si hay que reutilizar a alguien que ya está en `personas`.
///
/// La tabla `personas` hace que un mismo señor registrado como técnico y como
/// cliente sea una sola fila. Eso es lo que se quiere, pero no puede pasar en
/// silencio: al guardar, sus datos de contacto se sobrescriben con los que se
/// acaban de teclear. Este diálogo lo dice antes de que ocurra.
///
/// Devuelve `true` cuando se puede seguir guardando. Eso incluye los dos casos
/// en que no hay nada que preguntar:
/// - [existente] es `null` —nadie tiene ese documento—;
/// - la persona ya cumple [rolNuevo], porque entonces el duplicado lo rechaza
///   la validación del módulo con su propio mensaje y avisar dos veces sobra.
///
/// Ejemplo:
/// ```dart
/// final existente = await repo.buscarPorDocumento(documento);
/// if (!context.mounted) return;
/// if (!await confirmarPersonaExistente(
///   context,
///   existente: existente,
///   rolNuevo: RolPersona.cliente,
/// )) return;
/// ```
Future<bool> confirmarPersonaExistente(
  BuildContext context, {
  required PersonaConRoles? existente,
  required RolPersona rolNuevo,
}) async {
  if (existente == null) return true;
  if (existente.tieneRol(rolNuevo)) return true;

  final confirmado = await DialogoConfirmacion.mostrar(
    context,
    titulo: 'Esa cédula ya está registrada',
    mensaje:
        '${existente.persona.nombreCompleto} ya figura como '
        '${existente.rolesEnTexto}. Se usará ese mismo registro, así que los '
        'datos de contacto que acabas de escribir reemplazarán a los que '
        'tenía.',
    textoConfirmar: 'Registrar también como ${rolNuevo.etiqueta}',
    destructivo: false,
  );

  return confirmado == true;
}
