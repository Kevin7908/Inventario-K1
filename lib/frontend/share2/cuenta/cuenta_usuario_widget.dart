import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';
import 'avatar_usuario.dart';

/// Bloque con el avatar, nombre y rol del usuario logueado en ese momento.
///
/// Se usa como [EncabezadoPagina.acciones] para mostrar la sesión activa
/// en la misma fila que el título de la pantalla.
///
/// Parámetros:
/// - [nombre]: nombre completo del usuario.
/// - [rol]: rol o cargo mostrado debajo del nombre (ej. "Administrador").
/// - [iniciales]: texto para [AvatarUsuario].
/// - [alPresionar]: callback opcional al tocar el bloque (ej. abrir menú de cuenta).
///
/// Ejemplo:
/// ```dart
/// CuentaUsuarioWidget(
///   nombre: 'Zaim Maulana',
///   rol: 'Administrador',
///   iniciales: 'ZM',
/// )
/// ```
class CuentaUsuarioWidget extends StatelessWidget {
  const CuentaUsuarioWidget({
    super.key,
    required this.nombre,
    required this.rol,
    required this.iniciales,
    this.alPresionar,
  });

  final String nombre;
  final String rol;
  final String iniciales;
  final VoidCallback? alPresionar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: alPresionar,
        borderRadius: BorderRadius.circular(8),
        hoverColor: ColoresApp.bgCardHover,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AvatarUsuario(iniciales: iniciales),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre, style: TipografiaApp.cuerpoMedium),
                  Text(
                    rol,
                    style: TipografiaApp.caption,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
