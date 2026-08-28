import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/deudores/modelo/deudor_resumen.dart';
import '../../../../core/formato.dart';
import '../../../share/share.dart';
import '../provider/deudores_providers.dart';
import 'estado_deuda_ui.dart';

/// La tabla del listado de cuentas por cobrar, con las seis columnas del
/// diseño.
///
/// Los anchos son los `grid-template-columns: 1.4fr 1.6fr 1fr 1.4fr 1fr 1fr`
/// del mockup, traducidos a `flex`. Como `flex` es entero van multiplicados
/// por diez: 1.4 no se puede expresar de otro modo.
///
/// Es la única parte de la pantalla que observa el listado: así el encabezado,
/// el buscador y los contadores no se reconstruyen al cambiar de página.
///
/// Recibe **una página**, no la cartera: el `WHERE`, el `COUNT` y el `LIMIT`
/// los resolvió SQLite (§5 de `REGLAS_BD.md`).
class TablaDeudores extends ConsumerWidget {
  const TablaDeudores({super.key, required this.alAbrir});

  final ValueChanged<DeudorResumen> alAbrir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estadoAsync = ref.watch(deudoresListaProvider);

    if (estadoAsync.hasError) {
      return EstadoVacio(
        icono: Icons.error_outline_rounded,
        titulo: 'No se pudo cargar la cartera',
        pista: '${estadoAsync.error}',
      );
    }

    final deudas = ref.watch(deudoresPaginaProvider);
    if (estadoAsync.isLoading && deudas.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: ColoresApp.goGreen),
      );
    }

    final pagina = ref.watch(
      deudoresListaProvider.select((s) => (
            actual: s.value?.pagina ?? 0,
            total: s.value?.total ?? 0,
            paginas: s.value?.totalPaginas ?? 1,
            tamano: s.value?.tamanoPagina ?? 12,
            hayFiltro: s.value?.hayFiltro ?? false,
          )),
    );

    return Column(
      children: [
        // `Expanded`: la tabla tiene encabezado fijo y exige altura acotada
        // (§4 de `CLAUDE.md`).
        Expanded(child: _tabla(deudas, pagina.hayFiltro)),
        if (pagina.paginas > 1)
          PaginacionWidget(
            paginaActual: pagina.actual,
            totalPaginas: pagina.paginas,
            totalItems: pagina.total,
            itemsPorPagina: pagina.tamano,
            alCambiarPagina: (p) =>
                ref.read(deudoresListaProvider.notifier).irAPagina(p),
          ),
      ],
    );
  }

  Widget _tabla(List<DeudorResumen> deudas, bool hayFiltro) {
    return TablaGenerica<DeudorResumen>(
      items: deudas,
      alPresionarFila: alAbrir,
      mensajeVacio: hayFiltro
          ? 'Ninguna deuda coincide con lo que buscas'
          : 'Nadie debe nada. Anota la primera con «Nueva deuda».',
      columnas: [
        ColumnaTabla(
          titulo: 'Cliente',
          flex: 14,
          constructor: (d) => _Cliente(deuda: d),
        ),
        const ColumnaTabla(
          titulo: 'Concepto',
          flex: 16,
          constructor: _Concepto.new,
        ),
        const ColumnaTabla(
          titulo: 'Vence',
          flex: 10,
          constructor: _Vence.new,
        ),
        ColumnaTabla(
          titulo: 'Progreso',
          flex: 14,
          constructor: (d) => _Progreso(deuda: d),
        ),
        ColumnaTabla(
          titulo: 'Estado',
          flex: 10,
          constructor: (d) => BadgeSituacionDeuda(deuda: d),
        ),
        ColumnaTabla(
          titulo: 'Saldo',
          flex: 10,
          alineacion: Alignment.centerRight,
          constructor: (d) => Text(
            formatearPrecio(d.saldo),
            // Rojo el que falta, verde el que ya no debe nada: la columna se
            // recorre buscando a quién hay que llamar.
            style: TipografiaApp.cuerpoMedium.copyWith(
              color: d.saldo > 0
                  ? ColoresApp.statusDanger
                  : ColoresApp.statusSuccess,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Marcador con la inicial y el nombre, como en el diseño.
class _Cliente extends StatelessWidget {
  const _Cliente({required this.deuda});

  final DeudorResumen deuda;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MarcadorIdentidad(
          inicial: inicialDe(deuda.nombreCliente),
          colorFondo: ColoresApp.goGreen,
          colorFondoFin: ColoresApp.castletonGreen,
          lado: 38,
          radio: 11,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                deuda.nombreCliente,
                style: TipografiaApp.cuerpoMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                deuda.numero,
                // Monoespaciada: los consecutivos se comparan de un vistazo
                // cuando los dígitos van alineados.
                style: TipografiaApp.caption.copyWith(
                  fontSize: 11.5,
                  fontFamily: 'monospace',
                  fontFamilyFallback: const ['RobotoMono', 'Courier'],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Por qué se debe. El concepto es opcional —las líneas ya dicen qué se
/// llevó—, así que cuando falta se dice en qué moto se montó, que es la otra
/// forma de reconocer el fiado. Si tampoco hay moto, queda el guion.
class _Concepto extends StatelessWidget {
  const _Concepto(this.deuda, {super.key});

  final DeudorResumen deuda;

  @override
  Widget build(BuildContext context) {
    final texto = deuda.concepto ?? deuda.descripcionMoto;

    return Text(
      texto ?? '—',
      style: TipografiaApp.cuerpo.copyWith(
        fontSize: 12.5,
        color: texto == null
            ? ColoresApp.textDisabled
            : ColoresApp.textSecondary,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// El plazo. Sin fecha pactada no hay nada que vencer, y decirlo es más útil
/// que un guion.
class _Vence extends StatelessWidget {
  const _Vence(this.deuda, {super.key});

  final DeudorResumen deuda;

  @override
  Widget build(BuildContext context) {
    final limite = deuda.fechaVencimiento;

    return Text(
      limite == null ? 'Sin plazo' : formatearFecha(limite),
      style: TipografiaApp.cuerpo.copyWith(
        fontSize: 12.5,
        color: deuda.estaVencida
            ? ColoresApp.statusDanger
            : ColoresApp.textSecondary,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Cuánto se lleva cobrado. La barra sola no dice el número, así que debajo va
/// lo abonado sobre el total: el porcentaje se lee de lejos y la cifra
/// responde «¿cuánto entregó?» sin abrir la ficha.
class _Progreso extends StatelessWidget {
  const _Progreso({required this.deuda});

  final DeudorResumen deuda;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BarraProgreso(
          progreso: deuda.porcentajePagado,
          color: colorDeAvance(situacionDe(deuda)),
          alto: 7,
        ),
        const SizedBox(height: 5),
        Text(
          '${formatearPrecio(deuda.montoPagado)} de '
          '${formatearPrecio(deuda.montoTotal)}',
          style: TipografiaApp.caption.copyWith(fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
