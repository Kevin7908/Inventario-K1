import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/ventas/ordenes/modelo/orden_resumen.dart';
import '../../../layout/encabezado_con_cuenta.dart';
import '../../../share2/share2.dart';
import '../orden_detalle/vista/orden_detalle_vista.dart';
import '../orden_detalle/widgets/dialogo_nueva_orden.dart';
import '../provider/ordenes_providers.dart';
import '../widgets/tabla_ordenes.dart';
import '../widgets/tarjetas_ordenes.dart';

/// Pantalla de Órdenes de servicio, con el diseño del mockup: encabezado,
/// cuatro contadores y la tabla de seis columnas.
///
/// Reemplaza a `features/ventas/ordenes/vista/ordenes_vista.dart`, que sigue
/// en el árbol hasta que el editor esté migrado.
///
/// El mockup no dibuja buscador. Se le agrega porque es una pantalla de uso
/// diario en un taller con cientos de órdenes, y la regla de teclado (§8) da
/// por hecho que `Ctrl+F` enfoca el buscador de la pantalla: sin campo, el
/// atajo no tendría a dónde ir.
class OrdenesVista extends ConsumerStatefulWidget {
  const OrdenesVista({super.key});

  @override
  ConsumerState<OrdenesVista> createState() => _OrdenesVistaState();
}

class _OrdenesVistaState extends ConsumerState<OrdenesVista> {
  final _busqueda = TextEditingController();
  final _focoBusqueda = FocusNode();
  Timer? _debounce;

  /// Qué orden está abierta en el editor. `null` = se ve el listado.
  int? _editando;

  @override
  void dispose() {
    _debounce?.cancel();
    _busqueda.dispose();
    _focoBusqueda.dispose();
    super.dispose();
  }

  /// El filtro se aplica con retardo: cada tecla reabre el stream con un
  /// `WHERE` nuevo, y no hace falta consultar la base mientras se escribe.
  void _alBuscar(String texto) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      ref.read(ordenesProvider.notifier).buscar(texto);
    });
  }

  /// Una orden nueva empieza preguntando qué moto entra, porque `moto_id` y
  /// `cliente_id` son `NOT NULL`: no se puede crear vacía como una cotización.
  /// Cancelar el cuadro no crea nada, así que entrar y arrepentirse no quema
  /// un consecutivo `ORD-`.
  Future<void> _nueva() async {
    final id = await DialogoNuevaOrden.mostrar(context);
    if (id == null || !mounted) return;
    setState(() => _editando = id);
  }

  void _abrir(OrdenResumen orden) => setState(() => _editando = orden.id);

  void _volverALista() => setState(() => _editando = null);

  /// La raíz no observa ningún provider: cada bloque se suscribe al suyo, así
  /// que escribir en el buscador no reconstruye ni el encabezado ni las
  /// tarjetas.
  @override
  Widget build(BuildContext context) {
    final editando = _editando;
    if (editando != null) {
      return OrdenDetalleVista(ordenId: editando, alCerrar: _volverALista);
    }

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
              titulo: 'Órdenes de servicio',
              subtitulo: 'Gestión de trabajos del taller',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: BarraBusqueda(
                    controlador: _busqueda,
                    focoTeclado: _focoBusqueda,
                    placeholder: 'Buscar por orden, cliente o moto...',
                    alCambiar: _alBuscar,
                  ),
                ),
                const SizedBox(width: 20),
                BotonPrimario(
                  etiqueta: 'Nueva orden',
                  icono: Icons.add,
                  alPresionar: _nueva,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const TarjetasOrdenes(),
            const SizedBox(height: 20),
            // `Expanded` porque `TablaGenerica` lleva encabezado fijo y exige
            // un padre acotado (§4 de `CLAUDE.md`).
            Expanded(child: TablaOrdenes(alAbrir: _abrir)),
          ],
        ),
      ),
    );
  }
}
