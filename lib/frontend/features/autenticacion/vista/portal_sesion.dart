import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../layout/layout_principal.dart';
import '../../../share/share.dart';
import '../provider/auth_providers.dart';
import 'login_vista.dart';
import 'primer_admin_vista.dart';

/// La raíz de la app: decide qué se ve antes de que haya sesión.
///
/// Tres estados y en este orden:
/// 1. hay sesión abierta → la app;
/// 2. la base no tiene ninguna cuenta → crear la del administrador;
/// 3. lo normal → el login.
///
/// La sesión no se guarda en disco, así que el paso 1 solo es cierto dentro
/// del mismo arranque.
class PortalSesion extends ConsumerWidget {
  const PortalSesion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(usuarioEnSesionProvider);

    if (usuario != null) {
      // Se espera a que los permisos estén cargados antes de dejar entrar.
      // Sin esto, la app se pintaría un instante con todo escondido y luego
      // aparecerían los botones, que se ve como un parpadeo raro.
      return ref.watch(permisosSesionProvider).when(
            data: (_) => const LayoutPrincipal(),
            loading: () => const _Cargando(),
            error: (e, _) => _ErrorArranque(detalle: e.toString()),
          );
    }

    return ref.watch(hayUsuariosProvider).when(
          data: (hay) => hay ? const LoginVista() : const PrimerAdminVista(),
          loading: () => const _Cargando(),
          error: (e, _) => _ErrorArranque(detalle: e.toString()),
        );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: ColoresApp.bgApp,
      body: Center(
        child: CircularProgressIndicator(color: ColoresApp.goGreen),
      ),
    );
  }
}

/// Si la base no abre no hay nada que hacer desde la app, pero decirlo en
/// pantalla es mucho mejor que quedarse en el indicador de carga para siempre.
class _ErrorArranque extends StatelessWidget {
  const _ErrorArranque({required this.detalle});

  final String detalle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.bgApp,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: AvisoEnLinea(
              titulo: 'No se pudo abrir la base de datos',
              mensaje: detalle,
            ),
          ),
        ),
      ),
    );
  }
}
