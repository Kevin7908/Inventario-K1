import 'package:flutter/material.dart';

import '../../backend/share/database/locator.dart';
import '../features/autenticacion/view_model/auth_view_model.dart';
import '../share2/share2.dart';

/// Encabezado de pantalla que agrega la sesión activa (notificaciones + cuenta)
/// como acciones de [EncabezadoPagina], leyendo el usuario logueado desde
/// [AuthViewModel]. Vive en `layout/` (no en `share2/`) porque conecta un
/// widget presentacional con el estado real de autenticación de la app.
class EncabezadoConCuenta extends StatelessWidget {
  const EncabezadoConCuenta({
    super.key,
    required this.titulo,
    this.subtitulo,
  });

  final String titulo;
  final String? subtitulo;

  /// Resuelto una vez, no en cada `build`: `locator` dentro de `build` es
  /// service location en caliente y esconde la dependencia.
  static final AuthViewModel _authViewModel = locator<AuthViewModel>();

  @override
  Widget build(BuildContext context) {
    final authViewModel = _authViewModel;

    return ListenableBuilder(
      listenable: authViewModel,
      builder: (context, _) {
        final usuario = authViewModel.usuarioActual;
        final nombre = usuario?.nombre ?? 'Invitado';
        final rol = (usuario?.esAdmin ?? false) ? 'Administrador' : 'Usuario';

        return EncabezadoPagina(
          titulo: titulo,
          subtitulo: subtitulo,
          acciones: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconoNotificaciones(tieneNotificaciones: true, alPresionar: () {}),
              const SizedBox(width: 16),
              CuentaUsuarioWidget(
                nombre: nombre,
                rol: rol,
                iniciales: _iniciales(nombre),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _iniciales(String nombre) {
    final partes = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();

    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return (partes.first.substring(0, 1) + partes.last.substring(0, 1))
        .toUpperCase();
  }
}
