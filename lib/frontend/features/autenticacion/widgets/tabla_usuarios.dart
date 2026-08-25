import 'package:flutter/material.dart';

import '../../../../backend/features/autenticacion/modelo/usuario.dart';
import '../../../../backend/share/dominio/rol_usuario.dart';
import '../../../../core/formato.dart';
import '../../../share2/share2.dart';

/// La tabla de cuentas de Configuración → Usuarios.
///
/// No decide nada: recibe la lista ya resuelta y avisa por callbacks. Quién
/// puede hacer cada cambio lo comprueba el repositorio.
///
/// Parámetros:
/// - [usuarios]: las cuentas a pintar.
/// - [idEnSesion]: la cuenta de quien está mirando, para marcarla como «tú» y
///   no ofrecerle desactivarse a sí mismo.
/// - [alCambiarEstado]: activar o desactivar una cuenta.
/// - [alCambiarRol]: cambiar el rol de una cuenta.
/// - [alEditarPermisos]: abrir la lista de permisos de esa cuenta.
class TablaUsuarios extends StatelessWidget {
  const TablaUsuarios({
    super.key,
    required this.usuarios,
    required this.idEnSesion,
    required this.alCambiarEstado,
    required this.alCambiarRol,
    required this.alEditarPermisos,
  });

  final List<Usuario> usuarios;
  final int? idEnSesion;
  final void Function(Usuario cuenta, bool activa) alCambiarEstado;
  final void Function(Usuario cuenta, RolUsuario rol) alCambiarRol;
  final void Function(Usuario cuenta) alEditarPermisos;

  bool _esUnoMismo(Usuario cuenta) => cuenta.id == idEnSesion;

  @override
  Widget build(BuildContext context) {
    return TablaGenerica<Usuario>(
      items: usuarios,
      mensajeVacio: 'Todavía no hay cuentas',
      columnas: [
        ColumnaTabla<Usuario>(
          titulo: 'Persona',
          flex: 3,
          constructor: (u) => _Identidad(
            usuario: u,
            esUnoMismo: _esUnoMismo(u),
          ),
        ),
        ColumnaTabla<Usuario>(
          titulo: 'Correo',
          flex: 3,
          constructor: (u) => Text(
            u.tieneCorreo ? u.email : 'Sin correo',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: u.tieneCorreo
                ? TipografiaApp.cuerpo
                : TipografiaApp.caption.copyWith(
                    color: ColoresApp.statusWarning,
                  ),
          ),
        ),
        ColumnaTabla<Usuario>(
          titulo: 'Rol',
          flex: 2,
          constructor: (u) => _SelectorRol(
            usuario: u,
            alCambiar: (rol) => alCambiarRol(u, rol),
          ),
        ),
        ColumnaTabla<Usuario>(
          titulo: 'Estado',
          flex: 2,
          constructor: (u) => IndicadorEstado(
            etiqueta: u.estaActivo ? 'Activa' : 'Desactivada',
            color: u.estaActivo
                ? ColoresApp.statusSuccess
                : ColoresApp.statusNeutral,
            colorFondo: u.estaActivo
                ? ColoresApp.statusSuccessBg
                : ColoresApp.statusNeutralBg,
            conPunto: true,
          ),
        ),
        ColumnaTabla<Usuario>(
          titulo: 'Desde',
          flex: 2,
          constructor: (u) => Text(
            formatearFecha(u.creadoEn),
            style: TipografiaApp.caption,
          ),
        ),
        ColumnaTabla<Usuario>(
          titulo: '',
          ancho: 104,
          alineacion: Alignment.centerRight,
          constructor: (u) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BotonIcono(
                icono: Icons.tune_rounded,
                tooltip: u.esAdmin
                    ? 'Un administrador tiene todos los permisos'
                    : 'Permisos de esta cuenta',
                // Los de un administrador no se editan: son todos, y quitarle
                // alguno dejaría la app sin quien pueda devolvérselo.
                alPresionar: u.esAdmin ? null : () => alEditarPermisos(u),
              ),
              _BotonEstado(
                usuario: u,
                esUnoMismo: _esUnoMismo(u),
                alCambiarEstado: alCambiarEstado,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// El botón que activa o desactiva una cuenta.
class _BotonEstado extends StatelessWidget {
  const _BotonEstado({
    required this.usuario,
    required this.esUnoMismo,
    required this.alCambiarEstado,
  });

  final Usuario usuario;
  final bool esUnoMismo;
  final void Function(Usuario cuenta, bool activa) alCambiarEstado;

  @override
  Widget build(BuildContext context) {
    final u = usuario;
    return BotonIcono(
      icono: u.estaActivo
          ? Icons.block_outlined
          : Icons.check_circle_outline_rounded,
      tooltip: esUnoMismo
          ? 'No puedes desactivar tu propia cuenta'
          : (u.estaActivo ? 'Desactivar cuenta' : 'Activar cuenta'),
      color:
          u.estaActivo ? ColoresApp.statusDanger : ColoresApp.statusSuccess,
      // Desactivarse a uno mismo deja la sesión abierta con una cuenta que ya
      // no puede volver a entrar. No hay motivo para permitirlo.
      alPresionar: esUnoMismo ? null : () => alCambiarEstado(u, !u.estaActivo),
    );
  }
}

/// Avatar, nombre y el usuario con el que entra.
class _Identidad extends StatelessWidget {
  const _Identidad({required this.usuario, required this.esUnoMismo});

  final Usuario usuario;
  final bool esUnoMismo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AvatarUsuario(iniciales: usuario.iniciales, tamano: 32),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      usuario.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TipografiaApp.cuerpoMedium,
                    ),
                  ),
                  if (esUnoMismo) ...[
                    const SizedBox(width: 6),
                    Text(
                      '(tú)',
                      style: TipografiaApp.caption.copyWith(
                        color: ColoresApp.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                usuario.usuario,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TipografiaApp.monoespaciada(
                  TipografiaApp.caption,
                ).copyWith(color: ColoresApp.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// El rol como una pastilla que se despliega.
///
/// Un `SelectorWidget` aquí no cabe: siempre pinta su etiqueta arriba, y en
/// una celda de tabla la columna ya la tiene.
class _SelectorRol extends StatelessWidget {
  const _SelectorRol({required this.usuario, required this.alCambiar});

  final Usuario usuario;
  final ValueChanged<RolUsuario> alCambiar;

  @override
  Widget build(BuildContext context) {
    final esAdmin = usuario.esAdmin;

    return PopupMenuButton<RolUsuario>(
      tooltip: 'Cambiar rol',
      position: PopupMenuPosition.under,
      onSelected: alCambiar,
      itemBuilder: (_) => [
        for (final rol in RolUsuario.values)
          PopupMenuItem<RolUsuario>(
            value: rol,
            child: Text(rol.etiqueta, style: TipografiaApp.cuerpo),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IndicadorEstado(
            etiqueta: usuario.rol.etiqueta,
            color: esAdmin ? ColoresApp.statusInfo : ColoresApp.statusNeutral,
            colorFondo:
                esAdmin ? ColoresApp.statusInfoBg : ColoresApp.statusNeutralBg,
          ),
          const Icon(
            Icons.expand_more_rounded,
            size: 16,
            color: ColoresApp.textMuted,
          ),
        ],
      ),
    );
  }
}
