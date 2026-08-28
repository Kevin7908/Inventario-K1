import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/inventario/modelo/movimiento_detalle.dart';
import '../../../../core/formato.dart';
import '../../../share/share.dart';
import '../provider/inventario_providers.dart';
import 'estilo_movimiento.dart';

/// El libro mayor: cuándo se movió, qué producto, por qué, cuánto y quién.
///
/// Observa `movimientosPaginaProvider` ella sola para que escribir en el
/// buscador no reconstruya el encabezado ni los filtros (`CLAUDE.md` §3).
class TablaMovimientos extends ConsumerWidget {
  const TablaMovimientos({super.key, required this.alLimpiarFiltros});

  final VoidCallback alLimpiarFiltros;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movimientos = ref.watch(movimientosPaginaProvider);
    final hayFiltro = ref.watch(movimientosProvider).value?.hayFiltro ?? false;

    if (movimientos.isEmpty) {
      return _Vacio(hayFiltro: hayFiltro, alLimpiarFiltros: alLimpiarFiltros);
    }

    return TablaGenerica<MovimientoDetalle>(
      items: movimientos,
      columnas: [
        ColumnaTabla<MovimientoDetalle>(
          titulo: 'Cuándo',
          flex: 2,
          constructor: (m) => _Cuando(fecha: m.creadoEn),
        ),
        ColumnaTabla<MovimientoDetalle>(
          titulo: 'Producto',
          flex: 4,
          constructor: (m) => _Producto(movimiento: m),
        ),
        ColumnaTabla<MovimientoDetalle>(
          titulo: 'Por qué',
          flex: 3,
          constructor: (m) => _Motivo(movimiento: m),
        ),
        ColumnaTabla<MovimientoDetalle>(
          titulo: 'Quién',
          flex: 3,
          constructor: (m) => _Autor(nombre: m.usuario),
        ),
        ColumnaTabla<MovimientoDetalle>(
          titulo: 'Cantidad',
          flex: 2,
          alineacion: Alignment.centerRight,
          constructor: (m) => _Cantidad(movimiento: m),
        ),
      ],
    );
  }
}

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

class _Producto extends StatelessWidget {
  const _Producto({required this.movimiento});

  final MovimientoDetalle movimiento;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          movimiento.productoNombre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TipografiaApp.cuerpoMedium,
        ),
        Text(
          movimiento.productoSku,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TipografiaApp.monoespaciada(TipografiaApp.caption)
              .copyWith(color: ColoresApp.textMuted),
        ),
      ],
    );
  }
}

/// El tipo con su ícono, y debajo el documento que lo causó o la nota.
class _Motivo extends StatelessWidget {
  const _Motivo({required this.movimiento});

  final MovimientoDetalle movimiento;

  @override
  Widget build(BuildContext context) {
    final estilo =
        EstiloMovimiento.de(movimiento.tipo, entra: movimiento.entra);
    final notas = movimiento.notas;
    final pie = movimiento.numeroDocumento ?? (notas ?? '');

    return Row(
      children: [
        Icon(estilo.icono, size: 15, color: estilo.color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                movimiento.tipo.etiqueta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TipografiaApp.cuerpo,
              ),
              if (pie.isNotEmpty)
                Text(
                  pie,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TipografiaApp.caption
                      .copyWith(color: ColoresApp.textMuted),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Autor extends StatelessWidget {
  const _Autor({required this.nombre});

  final String nombre;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AvatarUsuario(iniciales: inicialDe(nombre), tamano: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TipografiaApp.cuerpo,
          ),
        ),
      ],
    );
  }
}

class _Cantidad extends StatelessWidget {
  const _Cantidad({required this.movimiento});

  final MovimientoDetalle movimiento;

  @override
  Widget build(BuildContext context) {
    final estilo =
        EstiloMovimiento.de(movimiento.tipo, entra: movimiento.entra);

    return Text(
      formatearCantidadMovimiento(movimiento.cantidad),
      textAlign: TextAlign.right,
      style: TipografiaApp.cuerpoMedium.copyWith(color: estilo.color),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.hayFiltro, required this.alLimpiarFiltros});

  final bool hayFiltro;
  final VoidCallback alLimpiarFiltros;

  @override
  Widget build(BuildContext context) {
    if (!hayFiltro) {
      return const EstadoVacio(
        icono: Icons.swap_vert_rounded,
        titulo: 'Todavía no se ha movido nada',
        pista: 'Cada venta, ajuste o entrada de mercancía deja aquí su '
            'renglón.',
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const EstadoVacio(
          icono: Icons.filter_alt_off_outlined,
          titulo: 'Ningún movimiento con esos filtros',
          pista: 'Prueba con otro rango de fechas o quita el tipo.',
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
