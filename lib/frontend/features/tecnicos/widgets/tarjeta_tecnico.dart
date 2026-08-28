import 'package:flutter/material.dart';

import '../../../../backend/features/tecnicos/modelo/tecnico.dart';
import '../../../share/share.dart';

/// Tarjeta de un técnico en la grilla del catálogo.
///
/// Replica la tarjeta del mockup: marcador oscuro con las iniciales del
/// técnico, nombre, teléfono y —debajo, en una franja propia— su
/// especialización y cuántas órdenes tiene asignadas. Vive en el módulo y no
/// en share porque traduce un [Tecnico] —un modelo de dominio— a la
/// [TarjetaCatalogo] compartida.
class TarjetaTecnico extends StatelessWidget {
  const TarjetaTecnico({
    super.key,
    required this.tecnico,
    required this.ordenes,
    this.especializacion,
    this.alPresionar,
    this.alEditar,
    this.alEliminar,
  });

  final Tecnico tecnico;

  /// Cuántas órdenes distintas tiene asignadas. Llega ya calculado por un
  /// `COUNT DISTINCT` en SQL.
  final int ordenes;

  /// Nombre de la especialización, ya resuelta desde el id. `null` si el
  /// técnico no tiene una asignada.
  final String? especializacion;

  final VoidCallback? alPresionar;
  final VoidCallback? alEditar;
  final VoidCallback? alEliminar;

  @override
  Widget build(BuildContext context) {
    final telefono = tecnico.telefono?.trim() ?? '';

    return TarjetaCatalogo(
      marcador: MarcadorIdentidad(
        inicial: tecnico.iniciales,
        color: ColoresApp.brightGreen,
        colorFondo: ColoresApp.blackChocolate,
        lado: 48,
        radio: 14,
      ),
      titulo: tecnico.nombreCompleto,
      subtitulo: telefono.isEmpty ? null : telefono,
      alPresionar: alPresionar,
      acciones: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Solo se marca cuando ya no trabaja aquí: un badge "Activo" en
          // cada tarjeta sería ruido, y es el estado por defecto.
          if (!tecnico.activo) ...[
            const IndicadorEstado(
              etiqueta: 'Inactivo',
              color: ColoresApp.statusNeutral,
              colorFondo: ColoresApp.statusNeutralBg,
            ),
            const SizedBox(width: 8),
          ],
          BotonIcono(
            icono: Icons.edit_outlined,
            tooltip: 'Editar',
            alPresionar: alEditar,
          ),
          BotonIcono(
            icono: Icons.delete_outline_rounded,
            tooltip: 'Eliminar',
            color: ColoresApp.statusDanger,
            alPresionar: alEliminar,
          ),
        ],
      ),
      pie: _FilaEspecializacion(especializacion: especializacion, ordenes: ordenes),
    );
  }
}

/// Franja del pie con la especialización y el conteo de órdenes, como en el
/// mockup: ícono + especialización a la izquierda (la línea la resuelve
/// [FilaDato], igual que en la tarjeta de proveedor), conteo a la derecha,
/// sobre el mismo fondo que usan los inputs.
class _FilaEspecializacion extends StatelessWidget {
  const _FilaEspecializacion({required this.especializacion, required this.ordenes});

  final String? especializacion;
  final int ordenes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: ColoresApp.bgInput,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: FilaDato(
              icono: Icons.build_outlined,
              texto: especializacion ?? 'Sin especialización',
              color: ColoresApp.textSecondary,
              colorIcono: ColoresApp.goGreen,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            ordenes == 1 ? '1 orden' : '$ordenes órdenes',
            style: TipografiaApp.caption.copyWith(
              fontSize: 12,
              color: ColoresApp.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
