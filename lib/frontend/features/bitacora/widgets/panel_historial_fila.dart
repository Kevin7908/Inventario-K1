import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/bitacora/modelo/entrada_bitacora.dart';
import '../../../../backend/share/dominio/permiso.dart';
import '../../../../core/formato.dart';
import '../../../share/share.dart';
import '../../autenticacion/widgets/si_puede.dart';
import '../provider/bitacora_providers.dart';
import 'estilo_accion.dart';

/// «Últimos cambios» de la ficha de una fila: quién la tocó y cuándo.
///
/// Es la bitácora vista al revés. La pantalla de Administración responde «¿qué
/// pasó hoy en el taller?»; esto responde «¿quién tocó **esto**?», que es la
/// pregunta que se hace con la ficha delante: por qué el precio cambió, quién
/// le movió el stock mínimo.
///
/// Vive en el módulo de la bitácora y no en `share` porque observa un provider
/// y conoce `EntidadAuditada`; la ficha del producto y la del cliente lo
/// importan, que es la misma regla de `PanelMovimientosProducto`.
///
/// **Solo lo ve quien tenga `bitacoraVer`.** El repositorio corta la consulta
/// igual, pero sin el [SiPuede] la ficha enseñaría un panel con un error
/// dentro a todo el que no sea administrador.
///
/// Parámetros:
/// - [entidad]: de qué tipo es la fila (`EntidadAuditada.producto`, …).
/// - [entidadId]: el id de la fila.
/// - [titulo]: encabezado del panel. Por defecto, «Últimos cambios».
///
/// Ejemplo:
/// ```dart
/// PanelHistorialFila(
///   entidad: EntidadAuditada.producto,
///   entidadId: producto.id!,
/// )
/// ```
class PanelHistorialFila extends StatelessWidget {
  const PanelHistorialFila({
    super.key,
    required this.entidad,
    required this.entidadId,
    this.titulo = 'Últimos cambios',
  });

  final EntidadAuditada entidad;
  final int entidadId;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return SiPuede(
      permiso: Permiso.bitacoraVer,
      child: _Panel(
        entidad: entidad,
        entidadId: entidadId,
        titulo: titulo,
      ),
    );
  }
}

class _Panel extends ConsumerWidget {
  const _Panel({
    required this.entidad,
    required this.entidadId,
    required this.titulo,
  });

  final EntidadAuditada entidad;
  final int entidadId;
  final String titulo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historial = ref.watch(
      historialDeFilaProvider((entidad: entidad, id: entidadId)),
    );

    return PanelSeccion(
      titulo: titulo,
      child: switch (historial) {
        AsyncData(value: final lista) when lista.isEmpty => const _Hueco(),
        AsyncData(value: final lista) => _Lista(entradas: lista),
        AsyncError() => const _Hueco(
            texto: 'No se pudo leer el historial de esta ficha',
          ),
        _ => const PanelSinDatos.cargando(),
      },
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.entradas});

  final List<EntradaBitacora> entradas;

  @override
  Widget build(BuildContext context) {
    // Son cinco como mucho —el límite lo pone el provider en SQL—, así que
    // una columna concreta es correcta: no hay lista larga que construir.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entrada in entradas)
          _Fila(key: ValueKey(entrada.id), entrada: entrada),
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({super.key, required this.entrada});

  final EntradaBitacora entrada;

  @override
  Widget build(BuildContext context) {
    final estilo = EstiloAccion.de(entrada.accion);
    final detalle = entrada.detalle;

    return FilaMovimiento(
      icono: estilo.icono,
      titulo: '${entrada.accion.etiqueta} ${entrada.nombreUsuario}',
      // El «hace cuánto» va donde iría la fecha exacta: con la ficha delante,
      // lo que se quiere saber es si fue hoy o el mes pasado.
      detalle: detalle == null || detalle.isEmpty
          ? formatearHaceCuanto(entrada.creadoEn)
          : '${formatearHaceCuanto(entrada.creadoEn)} · $detalle',
      importe: formatearHora(entrada.creadoEn),
      color: estilo.color,
    );
  }
}

/// El hueco cuando la fila no se ha tocado desde que se creó.
class _Hueco extends StatelessWidget {
  const _Hueco({this.texto = 'Nadie la ha modificado todavía'});

  final String texto;

  @override
  Widget build(BuildContext context) => PanelSinDatos(
        icono: Icons.history_rounded,
        texto: texto,
      );
}
