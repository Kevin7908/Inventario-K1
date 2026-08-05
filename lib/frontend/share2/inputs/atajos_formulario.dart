import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Atajos de teclado para un formulario o diálogo.
///
/// Es una aplicación de escritorio de uso intensivo: se trabaja con teclado.
///
/// - **Esc** cancela y cierra.
/// - **Ctrl/Cmd + Enter** guarda.
///
/// Se usa `Ctrl+Enter` y no `Enter` a secas porque los formularios tienen
/// campos de varias líneas —descripciones— donde `Enter` debe seguir haciendo
/// un salto de línea. En los campos de una sola línea, `Enter` ya envía por su
/// cuenta a través de `onFieldSubmitted`.
///
/// Parámetros:
/// - [alGuardar]: acción de guardado. Si es `null`, el atajo no hace nada
///   (útil mientras la operación está en curso).
/// - [alCancelar]: acción de cierre.
/// - [child]: contenido del formulario.
///
/// Ejemplo:
/// ```dart
/// AtajosFormulario(
///   alGuardar: _guardando ? null : _guardar,
///   alCancelar: () => Navigator.of(context).pop(),
///   child: Form(key: _formKey, child: ...),
/// )
/// ```
class AtajosFormulario extends StatelessWidget {
  const AtajosFormulario({
    super.key,
    required this.child,
    this.alGuardar,
    this.alCancelar,
  });

  final Widget child;
  final VoidCallback? alGuardar;
  final VoidCallback? alCancelar;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            alCancelar?.call(),
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () =>
            alGuardar?.call(),
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): () =>
            alGuardar?.call(),
      },
      // `autofocus` para que los atajos funcionen apenas se abre el diálogo,
      // sin obligar al usuario a hacer clic dentro primero.
      child: Focus(autofocus: true, child: child),
    );
  }
}
