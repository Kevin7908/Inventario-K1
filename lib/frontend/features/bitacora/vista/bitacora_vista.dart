import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/share/dominio/permiso.dart';
import '../../../layout/encabezado_con_cuenta.dart';
import '../../../share/share.dart';
import '../../autenticacion/provider/auth_providers.dart';
import '../provider/bitacora_providers.dart';
import '../widgets/filtros_bitacora.dart';
import '../widgets/tabla_bitacora.dart';

/// Bitácora: quién hizo qué, y cuándo.
///
/// Es la contraparte visible de las columnas `usuario_id` de los documentos.
/// Aquéllas dicen quién **creó** una venta y viven dentro de ella; esta tabla
/// es la única que puede contar quién **editó** o **borró** algo, porque
/// sobrevive a la fila que desapareció.
///
/// **Solo la ve quien tenga `bitacoraVer`**, que de fábrica es el
/// administrador. Son tres capas y hacen falta las tres: el ítem no se dibuja
/// en el sidebar, esta vista muestra un aviso en vez de la tabla, y el
/// repositorio corta la consulta con `exigir`. Las dos primeras son orden; la
/// que manda es la tercera (`CLAUDE.md` §7 bis).
///
/// **No se edita nada.** La tabla es de solo escritura en la base —su guarda
/// está en `guardas_sql.dart`—, así que aquí no hay filas que abrir ni botones
/// que guardar: una bitácora que se puede corregir no prueba nada.
class BitacoraVista extends ConsumerWidget {
  const BitacoraVista({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final puedeVer = ref.watch(puedeProvider(Permiso.bitacoraVer));

    if (!puedeVer) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(32, 28, 32, 28),
        child: Align(
          alignment: Alignment.topCenter,
          child: AvisoEnLinea(
            tono: TonoAviso.alerta,
            titulo: 'Solo para administradores',
            mensaje: 'La bitácora dice quién movió el inventario y quién '
                'borró qué. Pídele acceso a un administrador del taller.',
          ),
        ),
      );
    }

    return const _PanelBitacora();
  }
}

class _PanelBitacora extends ConsumerStatefulWidget {
  const _PanelBitacora();

  @override
  ConsumerState<_PanelBitacora> createState() => _PanelBitacoraState();
}

class _PanelBitacoraState extends ConsumerState<_PanelBitacora> {
  final _busqueda = TextEditingController();
  final _focoBusqueda = FocusNode();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _busqueda.dispose();
    _focoBusqueda.dispose();
    super.dispose();
  }

  /// Con retardo: cada tecla reabre el stream con un `WHERE` nuevo, y no hace
  /// falta consultar la base mientras se escribe.
  void _alBuscar(String texto) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      ref.read(bitacoraListaProvider.notifier).buscar(texto);
    });
  }

  void _limpiarFiltros() {
    _busqueda.clear();
    ref.read(bitacoraListaProvider.notifier).limpiarFiltros();
  }

  /// La raíz no observa el listado: cada bloque se suscribe al suyo, así que
  /// escribir en el buscador no reconstruye el encabezado ni los filtros.
  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            _focoBusqueda.requestFocus(),
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EncabezadoConCuenta(
              titulo: 'Bitácora',
              subtitulo: 'Quién hizo qué, y cuándo',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: BarraBusqueda(
                    controlador: _busqueda,
                    focoTeclado: _focoBusqueda,
                    placeholder: 'Buscar por nombre o por lo que se tocó...',
                    alCambiar: _alBuscar,
                  ),
                ),
                const SizedBox(width: 20),
                // `Flexible` para que los chips envuelvan a dos líneas en vez
                // de empujar la fila fuera de la pantalla.
                const Flexible(child: ChipsAccion()),
              ],
            ),
            const SizedBox(height: 16),
            const FiltrosBitacora(),
            const SizedBox(height: 8),
            const _ResumenFiltro(),
            const SizedBox(height: 12),
            // `Expanded` porque `TablaGenerica` lleva encabezado fijo y exige
            // un padre acotado (`CLAUDE.md` §4).
            Expanded(
              child: TablaBitacora(alLimpiarFiltros: _limpiarFiltros),
            ),
            const SizedBox(height: 16),
            const _Paginador(),
          ],
        ),
      ),
    );
  }
}

/// Cuántos renglones hay y, si se está filtrando, cómo quitarlo.
class _ResumenFiltro extends ConsumerWidget {
  const _ResumenFiltro();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(bitacoraListaProvider).value;
    if (estado == null) return const SizedBox.shrink();

    return Row(
      children: [
        Text(
          estado.total == 1
              ? '1 movimiento'
              : '${estado.total} movimientos',
          style: TipografiaApp.caption.copyWith(color: ColoresApp.textMuted),
        ),
        if (estado.hayFiltro) ...[
          const SizedBox(width: 12),
          TextButton(
            onPressed: () =>
                ref.read(bitacoraListaProvider.notifier).limpiarFiltros(),
            child: Text(
              'Quitar los filtros',
              style: TipografiaApp.enlace(TipografiaApp.caption),
            ),
          ),
        ],
      ],
    );
  }
}

class _Paginador extends ConsumerWidget {
  const _Paginador();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(bitacoraListaProvider).value;
    if (estado == null || estado.total == 0) return const SizedBox.shrink();

    return PaginacionWidget(
      paginaActual: estado.pagina,
      totalPaginas: estado.totalPaginas,
      totalItems: estado.total,
      itemsPorPagina: estado.tamanoPagina,
      alCambiarPagina: (pagina) =>
          ref.read(bitacoraListaProvider.notifier).irAPagina(pagina),
    );
  }
}
