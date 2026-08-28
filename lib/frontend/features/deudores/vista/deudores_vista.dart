import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/deudores/modelo/deudor_resumen.dart';
import '../../../layout/encabezado_con_cuenta.dart';
import '../../../share/share.dart';
import '../deuda_detalle/vista/deuda_detalle_vista.dart';
import '../deuda_detalle/widgets/dialogo_nueva_deuda.dart';
import '../provider/deudores_providers.dart';
import '../widgets/tabla_deudores.dart';
import '../widgets/tarjetas_deudores.dart';

/// Pantalla de Cuentas por cobrar, con el diseño del mockup: encabezado,
/// cuatro contadores y la tabla de seis columnas.
///
/// **Aquí es donde nace una deuda.** Antes solo aparecía como resto de una
/// venta a crédito, y al dejar el mostrador de fiar se quedó sin quien la
/// creara; ahora se abre desde el listado, igual que una reserva.
///
/// El mockup no dibuja buscador. Se le agrega porque la cartera se acumula —una
/// deuda no se cierra hasta que el cliente vuelve— y porque la regla de teclado
/// (§8) da por hecho que `Ctrl+F` enfoca el buscador de la pantalla: sin campo,
/// el atajo no tendría a dónde ir.
class DeudoresVista extends ConsumerStatefulWidget {
  const DeudoresVista({super.key});

  @override
  ConsumerState<DeudoresVista> createState() => _DeudoresVistaState();
}

class _DeudoresVistaState extends ConsumerState<DeudoresVista> {
  final _busqueda = TextEditingController();
  final _focoBusqueda = FocusNode();
  Timer? _debounce;

  /// Qué deuda está abierta en la ficha. `null` = se ve el listado.
  int? _abierta;

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
      ref.read(deudoresListaProvider.notifier).buscar(texto);
    });
  }

  /// Una deuda nueva empieza preguntando de quién es y por cuánto, porque
  /// `cliente_id` es `NOT NULL` y el esquema exige concepto y monto. Cancelar
  /// el cuadro no crea nada, así que entrar y arrepentirse no quema un
  /// consecutivo `DEU-`.
  Future<void> _nueva() async {
    final id = await DialogoNuevaDeuda.mostrar(context);
    if (id == null || !mounted) return;
    setState(() => _abierta = id);
  }

  void _abrir(DeudorResumen deuda) => setState(() => _abierta = deuda.id);

  void _volverALista() => setState(() => _abierta = null);

  /// La raíz no observa ningún provider: cada bloque se suscribe al suyo, así
  /// que escribir en el buscador no reconstruye ni el encabezado ni los
  /// contadores.
  @override
  Widget build(BuildContext context) {
    final abierta = _abierta;
    if (abierta != null) {
      return DeudaDetalleVista(deudaId: abierta, alCerrar: _volverALista);
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
              titulo: 'Cuentas por cobrar',
              subtitulo: 'Control de créditos y deudores',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: BarraBusqueda(
                    controlador: _busqueda,
                    focoTeclado: _focoBusqueda,
                    placeholder: 'Buscar por número, cliente o concepto...',
                    alCambiar: _alBuscar,
                  ),
                ),
                const SizedBox(width: 20),
                BotonPrimario(
                  etiqueta: 'Nueva deuda',
                  icono: Icons.add,
                  alPresionar: _nueva,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const TarjetasDeudores(),
            const SizedBox(height: 20),
            // `Expanded` porque `TablaGenerica` lleva encabezado fijo y exige
            // un padre acotado (§4 de `CLAUDE.md`).
            Expanded(child: TablaDeudores(alAbrir: _abrir)),
          ],
        ),
      ),
    );
  }
}
