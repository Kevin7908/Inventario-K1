import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/resultado.dart';
import '../../../share/share.dart';
import '../../../../backend/share/dominio/permiso.dart';
import '../provider/auth_providers.dart';
import '../provider/usuarios_provider.dart';
import '../widgets/dialogo_nueva_cuenta.dart';
import '../widgets/tabla_usuarios.dart';
import 'usuario_detalle_vista.dart';

/// Las cuentas del taller: quién puede entrar, con qué rol y desde cuándo.
///
/// Es la pestaña «Usuarios» de Configuración y **solo la ve un
/// administrador**: quien no lo sea encuentra un aviso en vez de la tabla. La
/// pestaña tampoco se le dibuja, pero eso es cortesía de la vista de
/// Configuración; la comprobación de verdad la hace el repositorio en cada
/// escritura.
class UsuariosVista extends ConsumerStatefulWidget {
  const UsuariosVista({super.key});

  @override
  ConsumerState<UsuariosVista> createState() => _UsuariosVistaState();
}

class _UsuariosVistaState extends ConsumerState<UsuariosVista> {
  /// Qué cuenta está abierta en su ficha. `null` = se ve el listado. Es el
  /// mismo patrón del listado de deudas: una pestaña más dentro de la pantalla,
  /// no una ruta nueva.
  int? _abierta;

  void _abrir(int id) => setState(() => _abierta = id);
  void _volverALista() => setState(() => _abierta = null);

  @override
  Widget build(BuildContext context) {
    final esAdmin = ref.watch(puedeProvider(Permiso.usuariosAdministrar));

    if (!esAdmin) {
      return const Align(
        alignment: Alignment.topCenter,
        child: AvisoEnLinea(
          tono: TonoAviso.alerta,
          titulo: 'Solo para administradores',
          mensaje: 'Pídele a un administrador del taller que cree o cambie '
              'las cuentas.',
        ),
      );
    }

    final abierta = _abierta;
    if (abierta != null) {
      return UsuarioDetalleVista(
        usuarioId: abierta,
        alCerrar: _volverALista,
      );
    }

    return _PanelUsuarios(alAbrir: _abrir);
  }
}

class _PanelUsuarios extends ConsumerWidget {
  const _PanelUsuarios({required this.alAbrir});

  final void Function(int usuarioId) alAbrir;

  Future<void> _crear(BuildContext context) async {
    final creada = await DialogoNuevaCuenta.mostrar(context);
    if (creada == true && context.mounted) {
      MensajeApp.exito(context, 'Cuenta creada.');
    }
  }

  /// Un solo sitio para contarle a la vista cómo salió una acción del
  /// repositorio: la tabla no sabe de `Resultado`.
  static Future<void> _reportar(
    BuildContext context,
    Future<Resultado> operacion,
    String textoExito,
  ) async {
    final resultado = await operacion;
    if (!context.mounted) return;

    switch (resultado) {
      case Exito():
        MensajeApp.exito(context, textoExito);
      case Fallo(:final mensaje):
        MensajeApp.error(context, mensaje);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuarios = ref.watch(usuariosProvider);
    final acciones = ref.read(accionesUsuariosProvider.notifier);
    final enSesion = ref.watch(usuarioEnSesionProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Quién puede entrar a la app y con qué rol.',
                style: TipografiaApp.subtituloPagina,
              ),
            ),
            BotonPrimario(
              etiqueta: 'Nueva cuenta',
              icono: Icons.person_add_alt_1_rounded,
              alPresionar: () => _crear(context),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: usuarios.when(
            data: (lista) => TablaUsuarios(
              usuarios: lista,
              idEnSesion: enSesion?.id,
              alCambiarEstado: (cuenta, activa) => _reportar(
                context,
                acciones.cambiarEstado(cuenta, activa: activa),
                activa ? 'Cuenta activada.' : 'Cuenta desactivada.',
              ),
              alCambiarRol: (cuenta, rol) => _reportar(
                context,
                acciones.cambiarRol(cuenta, rol),
                'Rol actualizado.',
              ),
              alAbrir: (cuenta) => alAbrir(cuenta.id),
            ),
            loading: () => const Center(
              child: CircularProgressIndicator(color: ColoresApp.goGreen),
            ),
            error: (e, _) => AvisoEnLinea(mensaje: e.toString()),
          ),
        ),
      ],
    );
  }
}
