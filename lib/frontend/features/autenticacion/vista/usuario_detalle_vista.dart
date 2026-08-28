import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/autenticacion/modelo/usuario.dart';
import '../../../../core/formato.dart';
import '../../../share/share.dart';
import '../provider/usuarios_provider.dart';
import '../widgets/panel_permisos.dart';

/// La ficha de una cuenta: quién es y qué puede hacer.
///
/// Sustituye al diálogo de permisos. Una lista de cuarenta interruptores
/// agrupados por módulo no es un cuadro de confirmación: es una pantalla, y
/// como tal se abre —tocando la fila en el listado— y se cierra con «Volver a
/// las cuentas» o con Esc.
///
/// Recibe el **id** y no la cuenta: así el encabezado refleja al momento un
/// cambio de rol o de estado hecho desde otro sitio, en vez de quedarse con la
/// copia que había cuando se abrió.
///
/// Parámetros:
/// - [usuarioId]: la cuenta que se abre.
/// - [alCerrar]: vuelve al listado.
class UsuarioDetalleVista extends ConsumerWidget {
  const UsuarioDetalleVista({
    super.key,
    required this.usuarioId,
    required this.alCerrar,
  });

  final int usuarioId;
  final VoidCallback alCerrar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cuenta = ref.watch(cuentaProvider(usuarioId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BotonVolver(etiqueta: 'Volver a las cuentas', alPresionar: alCerrar),
        const SizedBox(height: 16),
        if (cuenta == null)
          const AvisoEnLinea(
            tono: TonoAviso.alerta,
            titulo: 'Esa cuenta ya no está',
            mensaje: 'Se borró o se dejó de listar mientras la mirabas.',
          )
        else ...[
          _Encabezado(cuenta: cuenta),
          const SizedBox(height: 20),
          Expanded(child: _Permisos(cuenta: cuenta, alCerrar: alCerrar)),
        ],
      ],
    );
  }
}

/// Los permisos, o la razón por la que no hay nada que tocar.
class _Permisos extends StatelessWidget {
  const _Permisos({required this.cuenta, required this.alCerrar});

  final Usuario cuenta;
  final VoidCallback alCerrar;

  @override
  Widget build(BuildContext context) {
    // A un administrador no se le quitan permisos: los tiene todos, y quitarle
    // alguno dejaría la app sin nadie capaz de devolvérselos.
    if (cuenta.esAdmin) {
      return const Align(
        alignment: Alignment.topCenter,
        child: AvisoEnLinea(
          tono: TonoAviso.informacion,
          titulo: 'Un administrador puede todo',
          mensaje: 'Sus permisos no se editan. Para acotar lo que hace esta '
              'persona, cámbiale el rol primero.',
        ),
      );
    }

    return PanelPermisos(
      cuenta: cuenta,
      alCerrar: alCerrar,
      alGuardado: () => MensajeApp.exito(context, 'Permisos actualizados.'),
    );
  }
}

/// Avatar, nombre, con qué entra y en qué estado está.
class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.cuenta});

  final Usuario cuenta;

  @override
  Widget build(BuildContext context) {
    return PanelSeccion(
      titulo: 'La cuenta',
      child: Row(
        children: [
          AvatarUsuario(iniciales: cuenta.iniciales, tamano: 52),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(cuenta.nombre, style: TipografiaApp.heading3),
                const SizedBox(height: 4),
                Text(
                  cuenta.tieneCorreo ? cuenta.email : 'Sin correo registrado',
                  style: cuenta.tieneCorreo
                      ? TipografiaApp.caption
                      : TipografiaApp.caption.copyWith(
                          color: ColoresApp.statusWarning,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Flexible + Wrap: en una ventana angosta los datos bajan de línea
          // en vez de desbordar la fila.
          Flexible(child: _Datos(cuenta: cuenta)),
        ],
      ),
    );
  }
}

class _Datos extends StatelessWidget {
  const _Datos({required this.cuenta});

  final Usuario cuenta;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Text(
          cuenta.usuario,
          style: TipografiaApp.monoespaciada(TipografiaApp.cuerpo)
              .copyWith(color: ColoresApp.textMuted),
        ),
        IndicadorEstado(
          etiqueta: cuenta.rol.etiqueta,
          color: cuenta.esAdmin
              ? ColoresApp.statusInfo
              : ColoresApp.statusNeutral,
          colorFondo: cuenta.esAdmin
              ? ColoresApp.statusInfoBg
              : ColoresApp.statusNeutralBg,
        ),
        IndicadorEstado(
          etiqueta: cuenta.estaActivo ? 'Activa' : 'Desactivada',
          color: cuenta.estaActivo
              ? ColoresApp.statusSuccess
              : ColoresApp.statusNeutral,
          colorFondo: cuenta.estaActivo
              ? ColoresApp.statusSuccessBg
              : ColoresApp.statusNeutralBg,
          conPunto: true,
        ),
        Text(
          'Desde ${formatearFecha(cuenta.creadoEn)}',
          style: TipografiaApp.caption.copyWith(color: ColoresApp.textMuted),
        ),
      ],
    );
  }
}
