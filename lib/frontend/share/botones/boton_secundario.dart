import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Botón de acción alternativa: acompaña a [BotonPrimario] sin competir con él.
///
/// Tiene dos aspectos según [oscuro]:
/// - `false` (por defecto): fondo blanco con borde, para acciones neutras
///   como "Cancelar" o "Volver".
/// - `true`: fondo oscuro sólido, para una acción con peso propio que aun así
///   no es la principal de la pantalla (ej. "Editar producto" junto a
///   "Agregar a venta").
///
/// Parámetros:
/// - [etiqueta]: texto visible del botón.
/// - [alPresionar]: callback al hacer tap. Si es `null`, queda deshabilitado.
/// - [icono]: ícono opcional a la izquierda del texto.
/// - [oscuro]: usa la variante de fondo oscuro.
/// - [expandido]: ocupa todo el ancho disponible en lugar de ajustarse al texto.
///
/// Ejemplo:
/// ```dart
/// BotonSecundario(
///   etiqueta: 'Cancelar',
///   alPresionar: () => controlador.cancelar(),
/// )
///
/// BotonSecundario(
///   etiqueta: 'Editar producto',
///   icono: Icons.edit_outlined,
///   oscuro: true,
///   expandido: true,
///   alPresionar: () => controlador.editar(),
/// )
/// ```
class BotonSecundario extends StatelessWidget {
  const BotonSecundario({
    super.key,
    required this.etiqueta,
    required this.alPresionar,
    this.icono,
    this.oscuro = false,
    this.expandido = false,
  });

  final String etiqueta;
  final VoidCallback? alPresionar;
  final IconData? icono;
  final bool oscuro;
  final bool expandido;

  @override
  Widget build(BuildContext context) {
    final bool deshabilitado = alPresionar == null;

    final Color fondo = oscuro ? ColoresApp.blackChocolate : ColoresApp.bgCard;
    final Color contenido = oscuro
        ? ColoresApp.textOnPrimary
        : ColoresApp.textSecondary;

    final contenidoBoton = Row(
      mainAxisSize: expandido ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icono != null) ...[
          Icon(
            icono,
            size: 17,
            color: deshabilitado ? ColoresApp.textDisabled : contenido,
          ),
          const SizedBox(width: 8),
        ],
        Text(
          etiqueta,
          style: TipografiaApp.cuerpoMedium.copyWith(
            color: deshabilitado ? ColoresApp.textDisabled : contenido,
          ),
        ),
      ],
    );

    return Opacity(
      opacity: deshabilitado ? 0.6 : 1,
      child: Material(
        color: fondo,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: alPresionar,
          borderRadius: BorderRadius.circular(12),
          hoverColor: oscuro
              ? Colors.white.withValues(alpha: 0.08)
              : ColoresApp.bgCardHover,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: oscuro
                  ? null
                  : Border.all(color: ColoresApp.borderInput),
            ),
            child: contenidoBoton,
          ),
        ),
      ),
    );
  }
}
