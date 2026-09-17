import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/ordenes/enum/enum_ordenes.dart';
import '../../../../../backend/share/dominio/permiso.dart';
import '../../../../../core/resultado.dart';
import '../../../../share/share.dart';
import '../../../autenticacion/widgets/si_puede.dart';
import '../provider/orden_editor_provider.dart';

/// «Marcar lista» y «Entregar», los dos pasos del trabajo.
///
/// Estaban solo dentro del diálogo de datos de la cabecera, en un desplegable
/// junto al kilometraje y el diagnóstico: para decir que una moto ya está lista
/// había que abrir un cuadro, buscar un selector y cerrarlo. Es el gesto más
/// repetido del taller y ahora está donde se mira la orden.
///
/// **Solo se ofrece el paso siguiente**, no los cuatro estados: una orden
/// abierta se marca lista, una lista se entrega, y una entregada o anulada ya
/// no se mueve. Retroceder —de lista a abierta— sigue estando en el diálogo,
/// que es donde vive lo que se hace una vez cada tanto.
///
/// Anular no está aquí a propósito: devuelve el inventario entero y tiene su
/// confirmación en la pantalla, no en un botón junto a los de todos los días.
///
/// Parámetros:
/// - [ordenId]: qué orden se está trabajando.
///
/// Ejemplo:
/// ```dart
/// BotonesEstadoOrden(ordenId: ordenId)
/// ```
class BotonesEstadoOrden extends ConsumerStatefulWidget {
  const BotonesEstadoOrden({super.key, required this.ordenId});

  final int ordenId;

  @override
  ConsumerState<BotonesEstadoOrden> createState() => BotonesEstadoOrdenState();
}

class BotonesEstadoOrdenState extends ConsumerState<BotonesEstadoOrden> {
  bool _cambiando = false;

  Future<void> _pasarA(EstadoOrden nuevo) async {
    setState(() => _cambiando = true);
    final resultado = await ref
        .read(ordenEditorProvider(widget.ordenId).notifier)
        .cambiarEstado(nuevo);
    if (!mounted) return;
    setState(() => _cambiando = false);

    switch (resultado) {
      case Exito():
        MensajeApp.exito(context, 'La orden quedó ${nuevo.etiqueta.toLowerCase()}.');
      case Fallo(:final mensaje):
        MensajeApp.error(context, mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(
      ordenEditorProvider(widget.ordenId).select((s) => s.value?.estado),
    );

    // El paso siguiente, o ninguno si la orden ya terminó su recorrido.
    final siguiente = switch (estado) {
      EstadoOrden.abierta => EstadoOrden.lista,
      EstadoOrden.lista => EstadoOrden.entregada,
      _ => null,
    };
    if (siguiente == null) return const SizedBox.shrink();

    final (etiqueta, icono) = siguiente == EstadoOrden.lista
        ? ('Marcar lista', Icons.check_circle_outline_rounded)
        : ('Entregar la moto', Icons.local_shipping_outlined);

    return SiPuede(
      permiso: Permiso.ordenesEditar,
      child: BotonSecundario(
        etiqueta: _cambiando ? 'Guardando…' : etiqueta,
        icono: icono,
        oscuro: true,
        expandido: true,
        alPresionar: _cambiando ? null : () => unawaited(_pasarA(siguiente)),
      ),
    );
  }
}
