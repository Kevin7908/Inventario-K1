import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/reservas/modelo/reserva_resumen.dart';
import '../../../layout/encabezado_con_cuenta.dart';
import '../../../share2/share2.dart';
import '../provider/reservas_providers.dart';
import '../reserva_detalle/vista/reserva_detalle_vista.dart';
import '../reserva_detalle/widgets/dialogo_nueva_reserva.dart';
import '../widgets/grilla_reservas.dart';

/// Pantalla de Reservas, con el diseño del mockup: encabezado y una rejilla de
/// tarjetas donde cada una dice quién apartó, cuánto lleva y cuánto falta.
///
/// El mockup no dibuja buscador. Se le agrega porque las reservas se acumulan
/// con los meses —una tarjeta por apartado, sin cerrarse hasta que el cliente
/// vuelve— y porque la regla de teclado (§8) da por hecho que `Ctrl+F` enfoca
/// el buscador de la pantalla: sin campo, el atajo no tendría a dónde ir.
class ReservasVista extends ConsumerStatefulWidget {
  const ReservasVista({super.key});

  @override
  ConsumerState<ReservasVista> createState() => _ReservasVistaState();
}

class _ReservasVistaState extends ConsumerState<ReservasVista> {
  final _busqueda = TextEditingController();
  final _focoBusqueda = FocusNode();
  Timer? _debounce;

  /// Qué reserva está abierta en el editor. `null` = se ve el listado.
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
      ref.read(reservasListaProvider.notifier).buscar(texto);
    });
  }

  /// Una reserva nueva empieza preguntando para quién es, porque `cliente_id`
  /// es `NOT NULL`. Cancelar el cuadro no crea nada, así que entrar y
  /// arrepentirse no quema un consecutivo `RES-`.
  Future<void> _nueva() async {
    final id = await DialogoNuevaReserva.mostrar(context);
    if (id == null || !mounted) return;
    setState(() => _editando = id);
  }

  void _abrir(ReservaResumen reserva) => setState(() => _editando = reserva.id);

  void _volverALista() => setState(() => _editando = null);

  /// La raíz no observa ningún provider: cada bloque se suscribe al suyo, así
  /// que escribir en el buscador no reconstruye el encabezado.
  @override
  Widget build(BuildContext context) {
    final editando = _editando;
    if (editando != null) {
      return ReservaDetalleVista(
        reservaId: editando,
        alCerrar: _volverALista,
      );
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
              titulo: 'Reservas',
              subtitulo: 'Apartados y pagos a plazos',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: BarraBusqueda(
                    controlador: _busqueda,
                    focoTeclado: _focoBusqueda,
                    placeholder: 'Buscar por número o cliente...',
                    alCambiar: _alBuscar,
                  ),
                ),
                const SizedBox(width: 20),
                BotonPrimario(
                  etiqueta: 'Nueva reserva',
                  icono: Icons.add,
                  alPresionar: _nueva,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(child: GrillaReservas(alAbrir: _abrir)),
          ],
        ),
      ),
    );
  }
}
