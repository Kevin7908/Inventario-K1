import 'package:flutter/material.dart';

import '../../../../backend/features/motos/modelo/moto.dart';
import '../../../share/share.dart';

/// Tarjeta de una moto en la grilla del catálogo.
///
/// Sigue la estructura de `TarjetaCliente` —marcador, título, franja gris con
/// el dato que más se consulta y una fila de cierre— porque es la forma que el
/// usuario ya reconoce del resto de catálogos. Lo que cambia es qué va en cada
/// hueco: la placa como subtítulo, el dueño en la franja y la ficha técnica
/// abajo.
///
/// Vive en el módulo y no en share porque traduce una [Moto] —un modelo de
/// dominio— a la [TarjetaCatalogo] compartida.
///
/// Parámetros:
/// - [moto]: moto a pintar, con `nombreCliente` ya resuelto por el JOIN.
/// - [alEditar] / [alEliminar]: acciones de la esquina superior derecha.
class TarjetaMoto extends StatelessWidget {
  const TarjetaMoto({
    super.key,
    required this.moto,
    required this.alEditar,
    required this.alEliminar,
  });

  final Moto moto;
  final VoidCallback alEditar;
  final VoidCallback alEliminar;

  @override
  Widget build(BuildContext context) {
    final placa = moto.placa?.trim() ?? '';

    return TarjetaCatalogo(
      marcador: MarcadorIdentidad(
        icono: Icons.two_wheeler_outlined,
        color: moto.activo ? ColoresApp.goGreen : ColoresApp.textDisabled,
        lado: 48,
        radio: 14,
      ),
      titulo: '${moto.marca} ${moto.modelo}',
      // La placa es lo que se teclea para buscar una moto, así que va donde
      // más se ve. Sin ella se dice, en vez de dejar el hueco mudo.
      subtitulo: placa.isEmpty ? 'Sin placa' : placa,
      acciones: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BotonIcono(
            icono: Icons.edit_outlined,
            tooltip: 'Editar moto',
            alPresionar: alEditar,
          ),
          BotonIcono(
            icono: Icons.delete_outline_rounded,
            tooltip: 'Eliminar moto',
            color: ColoresApp.statusDanger,
            alPresionar: alEliminar,
          ),
        ],
      ),
      pie: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FranjaDuenoMoto(nombre: moto.nombreCliente),
          const SizedBox(height: 10),
          FilaFichaMoto(moto: moto),
        ],
      ),
    );
  }
}

/// Franja gris con el dueño de la moto.
///
/// Se muestra siempre, incluso sin dueño resuelto: el hueco en blanco
/// descuadraría la grilla, y una moto huérfana es justo lo que hay que ver.
class FranjaDuenoMoto extends StatelessWidget {
  const FranjaDuenoMoto({super.key, required this.nombre});

  final String? nombre;

  @override
  Widget build(BuildContext context) {
    final dueno = nombre?.trim() ?? '';
    final vacio = dueno.isEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: ColoresApp.bgInput,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person_outline_rounded,
            size: 18,
            color: vacio ? ColoresApp.textDisabled : ColoresApp.textSecondary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              vacio ? 'Sin dueño registrado' : dueno,
              style: TipografiaApp.cuerpoMedium.copyWith(
                fontSize: 12.5,
                color: vacio ? ColoresApp.textDisabled : ColoresApp.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pie de la tarjeta: ficha técnica a la izquierda y el estado a la derecha.
///
/// Solo se marca la moto dada de baja: que una moto siga en servicio es lo
/// normal y no necesita badge, igual que en la tarjeta de cliente.
class FilaFichaMoto extends StatelessWidget {
  const FilaFichaMoto({super.key, required this.moto});

  final Moto moto;

  @override
  Widget build(BuildContext context) {
    final ficha = <String>[
      if (moto.anio != null) '${moto.anio}',
      if (moto.cilindraje != null) '${moto.cilindraje} cc',
      if ((moto.color ?? '').trim().isNotEmpty) moto.color!.trim(),
    ].join(' · ');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            ficha.isEmpty ? 'Sin ficha técnica' : ficha,
            style: TipografiaApp.caption.copyWith(
              fontSize: 12,
              color: ficha.isEmpty
                  ? ColoresApp.textDisabled
                  : ColoresApp.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (!moto.activo) ...[
          const SizedBox(width: 8),
          const IndicadorEstado(
            etiqueta: 'Inactiva',
            color: ColoresApp.statusNeutral,
            colorFondo: ColoresApp.statusNeutralBg,
          ),
        ],
      ],
    );
  }
}
