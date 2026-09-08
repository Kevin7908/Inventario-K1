import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/especializacion/modelo/especializacion.dart';
import '../../../../backend/features/tecnicos/modelo/tecnico.dart';
import '../../../share/share.dart';
import '../provider/especializacion_provider.dart';

/// Quiénes tienen esta especialidad.
///
/// La tarjeta de la rejilla ya decía «3 técnicos» y ese número no llevaba a
/// ninguna parte: para saber **cuáles** había que irse a la pantalla de
/// Técnicos y leer la columna de especialización fila por fila. Ahora la
/// tarjeta se toca y los enseña.
///
/// Es un diálogo y no una pantalla porque la respuesta son tres nombres: abrir
/// una vista entera para eso obligaría a volver, y la pregunta se hace de paso
/// mientras se mira el catálogo.
///
/// **Los inactivos se listan al final y se ven apagados**, no se esconden:
/// quien pregunta quién sabe de frenos también quiere saber que el que sabía
/// ya no está.
///
/// Parámetros:
/// - [especializacion]: la que se tocó, para el título y el filtro.
///
/// Ejemplo:
/// ```dart
/// await DialogoTecnicosEspecializacion.mostrar(context, especializacion: e);
/// ```
class DialogoTecnicosEspecializacion extends ConsumerWidget {
  const DialogoTecnicosEspecializacion({
    super.key,
    required this.especializacion,
  });

  final Especializacion especializacion;

  static Future<void> mostrar(
    BuildContext context, {
    required Especializacion especializacion,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) =>
          DialogoTecnicosEspecializacion(especializacion: especializacion),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tecnicos = ref.watch(tecnicosDeEspecializacionProvider(
      especializacion.id,
    ));

    return AtajosFormulario(
      alCancelar: () => Navigator.of(context).pop(),
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 460,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ColoresApp.bgCard,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: ColoresApp.shadowMedium,
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Titulo(nombre: especializacion.nombre),
              const SizedBox(height: 18),
              Flexible(
                child: switch (tecnicos) {
                  AsyncData(value: final lista) when lista.isEmpty =>
                    const _Hueco(),
                  AsyncData(value: final lista) => _Lista(tecnicos: lista),
                  AsyncError() => const _Hueco(
                      texto: 'No se pudo leer el equipo del taller',
                    ),
                  _ => const PanelSinDatos.cargando(),
                },
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: BotonSecundario(
                  etiqueta: 'Cerrar',
                  alPresionar: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo({required this.nombre});

  final String nombre;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: ColoresApp.greenChipBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.build_outlined,
            color: ColoresApp.castletonGreen,
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(nombre, style: TipografiaApp.heading3),
              const SizedBox(height: 2),
              const Text('Quiénes la tienen', style: TipografiaApp.caption),
            ],
          ),
        ),
      ],
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.tecnicos});

  final List<Tecnico> tecnicos;

  @override
  Widget build(BuildContext context) {
    // `builder` y no una columna concreta: un taller grande puede tener más
    // técnicos de los que caben, y el diálogo tiene alto acotado.
    return ListView.separated(
      shrinkWrap: true,
      itemCount: tecnicos.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _Fila(tecnico: tecnicos[i]),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.tecnico});

  final Tecnico tecnico;

  @override
  Widget build(BuildContext context) {
    final nombre = tecnico.datosPersona.nombreCompleto;
    final telefono = (tecnico.telefono ?? '').trim();

    return FichaResumen(
      titulo: nombre,
      subtitulo: [
        if (telefono.isNotEmpty) telefono,
        if (!tecnico.activo) 'Ya no trabaja aquí',
      ].join(' · '),
      inicial: inicialDe(nombre),
      tenue: !tecnico.activo,
    );
  }
}

class _Hueco extends StatelessWidget {
  const _Hueco({this.texto = 'Nadie tiene esta especialidad todavía'});

  final String texto;

  @override
  Widget build(BuildContext context) => PanelSinDatos(
        icono: Icons.person_search_outlined,
        texto: texto,
      );
}
