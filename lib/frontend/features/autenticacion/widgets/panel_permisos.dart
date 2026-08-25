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
/// Se abre desde la fila de esa cuenta en Configuración → Usuarios. Los
/// cambios no se guardan solos: se acumulan aquí y salen todos juntos con
/// «Guardar», que es lo que espera quien está repasando una lista de cuarenta
/// interruptores.
///
/// Un administrador no aparece nunca: sus permisos son todos y no se editan.
class PanelPermisos extends ConsumerStatefulWidget {
  const PanelPermisos({super.key, required this.cuenta});

  final Usuario cuenta;

  /// Devuelve `true` si se guardaron cambios.
  static Future<bool?> mostrar(BuildContext context, Usuario cuenta) =>
      showDialog<bool>(
        context: context,
        builder: (_) => PanelPermisos(cuenta: cuenta),
      );

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
        Navigator.of(context).pop(true);
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
      alCancelar: () => Navigator.of(context).pop(false),
      child: Dialog(
        backgroundColor: ColoresApp.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 700),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: guardados.when(
              loading: () => const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(color: ColoresApp.goGreen),
                ),
              ),
              error: (e, _) => AvisoEnLinea(mensaje: e.toString()),
              data: (permisos) {
                // Solo la primera vez: después manda lo que el usuario tocó,
                // o cada reemisión del stream le borraría los cambios.
                _marcados ??= permisos;
                return _Contenido(
                  cuenta: widget.cuenta,
                  marcados: _marcados!,
                  guardando: _guardando,
                  error: _error,
                  alAlternar: _alternar,
                  alAlternarModulo: _alternarModulo,
                  alGuardar: _guardar,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.cuenta,
    required this.marcados,
    required this.guardando,
    required this.error,
    required this.alAlternar,
    required this.alAlternarModulo,
    required this.alGuardar,
  });

  final Usuario cuenta;
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Permisos de ${cuenta.nombre}', style: TipografiaApp.heading3),
        const SizedBox(height: 4),
        Text(
          '${marcados.length} de ${Permiso.values.length} activos · '
          '${cuenta.rol.etiqueta}',
          style: TipografiaApp.subtituloPagina,
        ),
        const SizedBox(height: 18),
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
        if (error != null) ...[
          const SizedBox(height: 14),
          AvisoEnLinea(mensaje: error!),
        ],
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            BotonSecundario(
              etiqueta: 'Cancelar',
              alPresionar:
                  guardando ? null : () => Navigator.of(context).pop(false),
            ),
            const SizedBox(width: 10),
            BotonPrimario(
              etiqueta: guardando ? 'Guardando…' : 'Guardar permisos',
              alPresionar: guardando ? null : alGuardar,
            ),
          ],
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
