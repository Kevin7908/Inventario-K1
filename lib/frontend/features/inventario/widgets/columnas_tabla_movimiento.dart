import 'package:flutter/material.dart';

import '../../../../backend/features/inventario/modelo/movimiento_detalle.dart';
import '../../../../core/formato.dart';
import '../../../share/share.dart';
import 'estilo_movimiento.dart';

/// Columnas del libro mayor: cuándo se movió, qué producto, por qué, cuánto y
/// quién.
///
/// Viven aquí y no dentro de una vista para que la pantalla de Movimientos y
/// el kardex de un repuesto muestren **exactamente** las mismas columnas, que
/// es la misma regla de `columnasTablaProducto`: si se agrega una, aparece en
/// los dos sitios sin tener que acordarse.
///
/// - [mostrarProducto]: en el kardex de un repuesto sobra, porque todas las
///   filas son del mismo.
///
/// Ejemplo:
/// ```dart
/// TablaGenerica<MovimientoDetalle>(
///   items: movimientos,
///   columnas: columnasTablaMovimiento(),
/// )
/// ```
List<ColumnaTabla<MovimientoDetalle>> columnasTablaMovimiento({
  bool mostrarProducto = true,
}) {
  return [
    ColumnaTabla<MovimientoDetalle>(
      titulo: 'Cuándo',
      flex: 2,
      constructor: (m) => _Cuando(fecha: m.creadoEn),
    ),
    if (mostrarProducto)
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
  ];
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
