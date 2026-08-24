import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../share2/share2.dart';
import '../../widgets/estado_deuda_ui.dart';
import '../provider/deuda_editor_provider.dart';
import '../widgets/panel_deuda.dart';
import '../widgets/panel_pagos_deuda.dart';

/// Ficha de una deuda: dos paneles, como el resto de documentos de la app.
///
/// A la izquierda lo que se hace —cobrar y ver lo cobrado—; a la derecha la
/// deuda con su estado de cuentas. **Está al revés que en reservas a
/// propósito**: allí la izquierda es el catálogo del que se saca mercancía, y
/// aquí no hay nada que sacar, solo plata que entra.
///
/// La deuda **ya existe** cuando se llega aquí: la creó `DialogoNuevaDeuda`,
/// porque `cliente_id`, el concepto y el monto son obligatorios y no se puede
/// abrir vacía.
///
/// No hay indicador de guardado, al revés que en el editor de reservas: aquí
/// no hay autoguardado que explicar. Cada escritura es un gesto explícito
/// —registrar un abono, guardar el diálogo de datos— y avisa por su cuenta.
class DeudaDetalleVista extends ConsumerWidget {
  const DeudaDetalleVista({
    super.key,
    required this.deudaId,
    required this.alCerrar,
  });

  final int deudaId;
  final VoidCallback alCerrar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = deudaEditorProvider(deudaId);
    final cargando = ref.watch(provider.select((s) => !s.hasValue));

    if (cargando) {
      final error = ref.watch(provider.select((s) => s.error));
      if (error != null) {
        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BotonVolver(etiqueta: 'Cuentas por cobrar', alPresionar: alCerrar),
              const SizedBox(height: 24),
              Expanded(
                child: EstadoVacio(
                  icono: Icons.error_outline_rounded,
                  titulo: 'No se pudo abrir la deuda',
                  pista: '$error',
                ),
              ),
            ],
          ),
        );
      }
      return const Center(
        child: CircularProgressIndicator(color: ColoresApp.goGreen),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BarraSuperior(deudaId: deudaId, alVolver: alCerrar),
        const Divider(color: ColoresApp.border, height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: PanelPagosDeuda(deudaId: deudaId)),
              PanelDeuda(deudaId: deudaId),
            ],
          ),
        ),
      ],
    );
  }
}

/// Vuelta al listado, número de la deuda y en qué situación está.
class _BarraSuperior extends ConsumerWidget {
  const _BarraSuperior({required this.deudaId, required this.alVolver});

  final int deudaId;
  final VoidCallback alVolver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deuda =
        ref.watch(deudaEditorProvider(deudaId).select((s) => s.value?.deuda));

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 16),
      child: Row(
        children: [
          BotonVolver(etiqueta: 'Cuentas por cobrar', alPresionar: alVolver),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              deuda?.numero ?? 'Deuda',
              style: TipografiaApp.heading3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (deuda != null) BadgeSituacionDeuda(deuda: deuda),
        ],
      ),
    );
  }
}
