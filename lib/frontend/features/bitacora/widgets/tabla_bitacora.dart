import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/bitacora/modelo/entrada_bitacora.dart';
import '../../../../core/formato.dart';
import '../../../share/share.dart';
import '../provider/bitacora_providers.dart';
import 'estilo_accion.dart';

/// La tabla del historial: cuándo, quién, qué hizo y sobre qué.
///
/// Observa `bitacoraPaginaProvider` ella sola para que escribir en el buscador
/// no reconstruya el encabezado ni los filtros de la pantalla (`CLAUDE.md`
/// §3).
///
/// Las filas **no se tocan**: la bitácora es de solo lectura y no hay ficha a
/// donde ir. Ofrecer un clic que no lleva a ninguna parte se siente roto.
class TablaBitacora extends ConsumerWidget {
  const TablaBitacora({super.key, required this.alLimpiarFiltros});

  /// Lo llama el estado vacío cuando lo que sobra es el filtro, no el
  /// historial.
  final VoidCallback alLimpiarFiltros;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entradas = ref.watch(bitacoraPaginaProvider);
    final hayFiltro =
        ref.watch(bitacoraListaProvider).value?.hayFiltro ?? false;

    if (entradas.isEmpty) {
      return _Vacia(hayFiltro: hayFiltro, alLimpiarFiltros: alLimpiarFiltros);
    }

    return TablaGenerica<EntradaBitacora>(
      items: entradas,
      columnas: [
        ColumnaTabla<EntradaBitacora>(
          titulo: 'Cuándo',
          flex: 2,
          constructor: (e) => _Cuando(fecha: e.creadoEn),
        ),
        ColumnaTabla<EntradaBitacora>(
          titulo: 'Quién',
          flex: 3,
          constructor: (e) => _Quien(entrada: e),
        ),
        ColumnaTabla<EntradaBitacora>(
          titulo: 'Qué hizo',
          flex: 2,
          constructor: (e) => _Accion(accion: e.accion),
        ),
        ColumnaTabla<EntradaBitacora>(
          titulo: 'Sobre qué',
          flex: 4,
          constructor: (e) => _Objeto(entrada: e),
        ),
        ColumnaTabla<EntradaBitacora>(
          titulo: 'Detalle',
          flex: 3,
          constructor: (e) => Text(
            e.detalle ?? '—',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TipografiaApp.caption.copyWith(
              color: e.detalle == null
                  ? ColoresApp.textDisabled
                  : ColoresApp.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// La fecha arriba y la hora debajo: en un historial se busca por día, y la
/// hora solo hace falta para desempatar dos renglones seguidos.
class _Cuando extends StatelessWidget {
  const _Cuando({required this.fecha});

  final DateTime fecha;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(formatearFecha(fecha), style: TipografiaApp.cuerpoMedium),
        Text(
          formatearHora(fecha),
          style: TipografiaApp.caption.copyWith(color: ColoresApp.textMuted),
        ),
      ],
    );
  }
}

class _Quien extends StatelessWidget {
  const _Quien({required this.entrada});

  final EntradaBitacora entrada;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AvatarUsuario(iniciales: inicialDe(entrada.nombreUsuario), tamano: 30),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entrada.nombreUsuario,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TipografiaApp.cuerpoMedium,
              ),
              Text(
                entrada.usuario,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TipografiaApp.monoespaciada(TipografiaApp.caption)
                    .copyWith(color: ColoresApp.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Accion extends StatelessWidget {
  const _Accion({required this.accion});

  final AccionAuditada accion;

  @override
  Widget build(BuildContext context) {
    final estilo = EstiloAccion.de(accion);

    return Row(
      children: [
        Flexible(
          child: IndicadorEstado(
            etiqueta: accion.etiqueta,
            color: estilo.color,
            colorFondo: estilo.fondo,
          ),
        ),
      ],
    );
  }
}

/// Qué se tocó: el tipo arriba en pequeño y el nombre que tenía **cuando
/// pasó** debajo. Ese nombre es lo único que sobrevive a un borrado.
class _Objeto extends StatelessWidget {
  const _Objeto({required this.entrada});

  final EntradaBitacora entrada;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(entrada.entidad.etiqueta.toUpperCase(),
            style: TipografiaApp.overline),
        Text(
          entrada.descripcion,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TipografiaApp.cuerpo,
        ),
      ],
    );
  }
}

class _Vacia extends StatelessWidget {
  const _Vacia({required this.hayFiltro, required this.alLimpiarFiltros});

  final bool hayFiltro;
  final VoidCallback alLimpiarFiltros;

  @override
  Widget build(BuildContext context) {
    if (!hayFiltro) {
      return const EstadoVacio(
        icono: Icons.history_rounded,
        titulo: 'Todavía no hay nada anotado',
        pista: 'Aquí van a aparecer las ediciones y los borrados en cuanto '
            'alguien haga el primero.',
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const EstadoVacio(
          icono: Icons.filter_alt_off_outlined,
          titulo: 'Nada con esos filtros',
          pista: 'Prueba con otro rango de fechas o con otra cuenta.',
        ),
        BotonSecundario(
          etiqueta: 'Quitar los filtros',
          icono: Icons.close_rounded,
          alPresionar: alLimpiarFiltros,
        ),
      ],
    );
  }
}
