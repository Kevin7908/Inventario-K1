import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/autenticacion/modelo/usuario.dart';
import '../../../../backend/share/dominio/permiso.dart';
import '../../../../core/resultado.dart';
import '../../../share2/share2.dart';
import '../provider/usuarios_provider.dart';

/// Los permisos de **una cuenta**, agrupados por módulo, para prenderlos y
/// apagarlos uno por uno.
///
/// Es el cuerpo de la ficha de la cuenta, no un diálogo: repasar cuarenta
/// interruptores dentro de un modal obligaba a hacer scroll en un cuadro que
/// tapaba la tabla de detrás, y encima escondía a quién se le estaban
/// cambiando.
///
/// Los cambios no se guardan solos: se acumulan aquí y salen todos juntos con
/// «Guardar», que es lo que espera quien está repasando una lista larga.
///
/// Un administrador no llega hasta aquí: sus permisos son todos y no se
/// editan. De eso se encarga la ficha.
///
/// Parámetros:
/// - [cuenta]: de quién son los permisos.
/// - [alGuardado]: se llama cuando el repositorio confirmó el cambio.
/// - [alCerrar]: qué hace Esc. Normalmente, volver al listado.
class PanelPermisos extends ConsumerStatefulWidget {
  const PanelPermisos({
    super.key,
    required this.cuenta,
    this.alGuardado,
    this.alCerrar,
  });

  final Usuario cuenta;
  final VoidCallback? alGuardado;
  final VoidCallback? alCerrar;

  @override
  ConsumerState<PanelPermisos> createState() => _PanelPermisosState();
}

class _PanelPermisosState extends ConsumerState<PanelPermisos> {
  /// Lo que está marcado ahora mismo en la pantalla. Arranca en `null` hasta
  /// que llegan los permisos guardados: sin eso, el primer fotograma pintaría
  /// todo apagado y parecería que la cuenta no tiene ninguno.
  Set<Permiso>? _marcados;

  bool _guardando = false;
  String? _error;

  /// Cambiar de cuenta sin cambiar de widget dejaría los interruptores de la
  /// anterior encendidos sobre la nueva.
  @override
  void didUpdateWidget(PanelPermisos anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.cuenta.id != widget.cuenta.id) {
      _marcados = null;
      _error = null;
    }
  }

  void _alternar(Permiso permiso, bool activo) {
    setState(() {
      final actuales = {...?_marcados};
      activo ? actuales.add(permiso) : actuales.remove(permiso);
      _marcados = actuales;
    });
  }

  void _alternarModulo(ModuloPermiso modulo, bool activo) {
    setState(() {
      final actuales = {...?_marcados};
      final delModulo = Permiso.delModulo(modulo);
      activo ? actuales.addAll(delModulo) : actuales.removeAll(delModulo);
      _marcados = actuales;
    });
  }

  Future<void> _guardar() async {
    final marcados = _marcados;
    if (marcados == null || _guardando) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    final resultado = await ref
        .read(accionesUsuariosProvider.notifier)
        .fijarPermisos(widget.cuenta, marcados);

    if (!mounted) return;

    switch (resultado) {
      case Exito():
        setState(() => _guardando = false);
        widget.alGuardado?.call();
      case Fallo(:final mensaje):
        setState(() {
          _guardando = false;
          _error = mensaje;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final guardados = ref.watch(permisosDeProvider(widget.cuenta.id));

    return AtajosFormulario(
      alGuardar: _guardando ? null : _guardar,
      alCancelar: widget.alCerrar,
      child: guardados.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: ColoresApp.goGreen),
        ),
        error: (e, _) => AvisoEnLinea(mensaje: e.toString()),
        data: (permisos) {
          // Solo la primera vez: después manda lo que el usuario tocó, o cada
          // reemisión del stream le borraría los cambios.
          _marcados ??= permisos;
          return _Contenido(
            marcados: _marcados!,
            guardando: _guardando,
            error: _error,
            alAlternar: _alternar,
            alAlternarModulo: _alternarModulo,
            alGuardar: _guardar,
          );
        },
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.marcados,
    required this.guardando,
    required this.error,
    required this.alAlternar,
    required this.alAlternarModulo,
    required this.alGuardar,
  });

  final Set<Permiso> marcados;
  final bool guardando;
  final String? error;
  final void Function(Permiso, bool) alAlternar;
  final void Function(ModuloPermiso, bool) alAlternarModulo;
  final VoidCallback alGuardar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Qué puede hacer en cada módulo · '
                '${marcados.length} de ${Permiso.values.length} activos',
                style: TipografiaApp.subtituloPagina,
              ),
            ),
            BotonPrimario(
              etiqueta: guardando ? 'Guardando…' : 'Guardar permisos',
              icono: Icons.check,
              alPresionar: guardando ? null : alGuardar,
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          AvisoEnLinea(mensaje: error!),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: ModuloPermiso.values.length,
            itemBuilder: (_, indice) {
              final modulo = ModuloPermiso.values[indice];
              return _BloqueModulo(
                modulo: modulo,
                marcados: marcados,
                alAlternar: alAlternar,
                alAlternarModulo: alAlternarModulo,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Un módulo con sus acciones y un interruptor que las enciende todas.
class _BloqueModulo extends StatelessWidget {
  const _BloqueModulo({
    required this.modulo,
    required this.marcados,
    required this.alAlternar,
    required this.alAlternarModulo,
  });

  final ModuloPermiso modulo;
  final Set<Permiso> marcados;
  final void Function(Permiso, bool) alAlternar;
  final void Function(ModuloPermiso, bool) alAlternarModulo;

  @override
  Widget build(BuildContext context) {
    final permisos = Permiso.delModulo(modulo);
    final activos = permisos.where(marcados.contains).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PanelSeccion(
        titulo: '${modulo.etiqueta}  ·  $activos/${permisos.length}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () =>
                    alAlternarModulo(modulo, activos != permisos.length),
                child: Text(
                  activos == permisos.length ? 'Quitar todos' : 'Dar todos',
                  style: TipografiaApp.enlace(TipografiaApp.caption),
                ),
              ),
            ),
            for (final permiso in permisos)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InterruptorCampo(
                  etiqueta: permiso.etiqueta,
                  detalle: permiso.descripcion,
                  detalleEnUnaLinea: false,
                  valor: marcados.contains(permiso),
                  alCambiar: (activo) => alAlternar(permiso, activo),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
