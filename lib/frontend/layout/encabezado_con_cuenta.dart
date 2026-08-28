import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/autenticacion/provider/auth_providers.dart';
import '../share2/share2.dart';

/// Encabezado de pantalla que agrega la sesión activa (notificaciones y
/// cuenta) como acciones de [EncabezadoPagina].
///
/// Vive en `layout/` y no en `share2/` porque conecta un widget presentacional
/// con el estado real de la sesión. Es un [ConsumerWidget] y no la raíz de la
/// pantalla: lo único que se reconstruye cuando cambia el usuario es esta
/// fila (`CLAUDE.md` §3).
///
/// Antes leía `locator<AuthViewModel>()`, un `ChangeNotifier` resuelto por
/// `get_it`. Hoy observa `usuarioEnSesionProvider`.
class EncabezadoConCuenta extends ConsumerWidget {
  const EncabezadoConCuenta({
    super.key,
    required this.titulo,
    this.subtitulo,
  });

  final String titulo;
  final String? subtitulo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(usuarioEnSesionProvider);

    return EncabezadoPagina(
      titulo: titulo,
      subtitulo: subtitulo,
      acciones: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconoNotificaciones(tieneNotificaciones: true, alPresionar: () {}),
          const SizedBox(width: 16),
          CuentaUsuarioWidget(
            nombre: usuario?.nombre ?? 'Invitado',
            rol: usuario?.rol.etiqueta ?? 'Sin sesión',
            iniciales: usuario?.iniciales ?? '?',
          ),
        ],
      ),
    );
  }
}
