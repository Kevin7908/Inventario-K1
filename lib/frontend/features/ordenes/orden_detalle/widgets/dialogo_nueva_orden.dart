import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/motos/modelo/moto.dart';
import '../../../../share2/share2.dart';
import '../../../clientes/provider/cliente_provider.dart';
import '../../../motos/provider/motos_provider.dart';
import '../../provider/ordenes_providers.dart';

/// Qué moto entra al taller, antes de abrir el editor.
///
/// ## Por qué existe este cuadro y el de cotizaciones no tiene equivalente
///
/// `ordenes_servicio.moto_id` y `cliente_id` son `NOT NULL`: una orden **es**
/// una moto en el taller, y sin moto no hay nada que abrir. Así que la orden
/// no se puede crear vacía como se hace con una cotización, y el editor no
/// puede empezar sin ella.
///
/// Resolverlo aquí tiene una ventaja de propina: **nunca queda una orden
/// huérfana**. Si el editor creara la fila al abrirse, cada vez que alguien
/// entra y se arrepiente quedaría una orden vacía con su consecutivo `ORD-`
/// quemado. Escapar de este cuadro no crea nada.
///
/// El kilometraje va aquí y no en el editor porque se lee del tablero al
/// recibir la moto, que es exactamente este momento. Diagnóstico y
/// observaciones quedan para después: se completan mientras se revisa.
class DialogoNuevaOrden extends ConsumerStatefulWidget {
  const DialogoNuevaOrden({super.key});

  /// Devuelve el id de la orden creada, o `null` si se canceló.
  static Future<int?> mostrar(BuildContext context) => showDialog<int>(
        context: context,
        builder: (_) => const DialogoNuevaOrden(),
      );

  @override
  ConsumerState<DialogoNuevaOrden> createState() => _DialogoNuevaOrdenState();
}

class _DialogoNuevaOrdenState extends ConsumerState<DialogoNuevaOrden> {
  final _kilometraje = TextEditingController();
  final _diagnostico = TextEditingController();

  Moto? _moto;
  bool _creando = false;
  String? _error;

  @override
  void dispose() {
    _kilometraje.dispose();
    _diagnostico.dispose();
    super.dispose();
  }

  void _elegirMoto(Moto? moto) => setState(() {
        _moto = moto;
        // El kilometraje inicial de la moto es el mejor punto de partida: casi
        // siempre hay que subirlo un poco, no teclearlo de cero.
        if (moto != null && _kilometraje.text.isEmpty) {
          _kilometraje.text = '${moto.kilometrajeInicial}';
        }
      });

  Future<void> _crear() async {
    final moto = _moto;
    if (moto == null || _creando) return;

    setState(() {
      _creando = true;
      _error = null;
    });

    try {
      final orden = await ref.read(repositorioOrdenesProvider).agregar(
            motoId: moto.id,
            clienteId: moto.clienteId,
            kilometrajeEntrada: int.tryParse(_kilometraje.text) ?? 0,
            diagnostico: _diagnostico.text.trim().isEmpty
                ? null
                : _diagnostico.text.trim(),
          );
      if (!mounted) return;
      // El listado y sus contadores tienen una orden más.
      ref.invalidate(ordenesResumenProvider);
      Navigator.of(context).pop(orden.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creando = false;
        _error = 'No se pudo abrir la orden: $e';
      });
    }
  }

  void _cancelar() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final motos = ref.watch(catalogoMotosProvider).value ?? const <Moto>[];
    final clientes = ref.watch(catalogoClientesProvider).value;

    final moto = _moto;
    final duena = moto == null
        ? null
        : clientes?.where((c) => c.id == moto.clienteId).firstOrNull;

    return AtajosFormulario(
      alGuardar: _crear,
      alCancelar: _cancelar,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ColoresApp.bgCard,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: ColoresApp.shadowMedium,
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Nueva orden', style: TipografiaApp.heading3),
              const SizedBox(height: 6),
              const Text(
                'Qué moto entra al taller. El resto se completa dentro.',
                style: TipografiaApp.caption,
              ),
              const SizedBox(height: 20),
              CampoBusqueda<Moto>(
                etiqueta: 'Moto *',
                valor: _moto,
                opciones: motos,
                constructorEtiqueta: (m) => m.nombreDisplay,
                constructorDetalle: (m) => m.placa,
                placeholder: 'Buscar por placa, marca o modelo…',
                alCambiar: _elegirMoto,
              ),
              // El dueño no se elige: sale de la moto. Se muestra para poder
              // confirmar de un vistazo que es la moto correcta.
              if (duena != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 15,
                      color: ColoresApp.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        duena.nombreCompleto,
                        style: TipografiaApp.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              CampoTexto(
                etiqueta: 'Kilometraje de entrada',
                controlador: _kilometraje,
                placeholder: '15000',
                soloEnteros: true,
              ),
              const SizedBox(height: 14),
              CampoTexto(
                etiqueta: 'Qué reporta el cliente',
                controlador: _diagnostico,
                placeholder: 'No enciende en frío…',
                lineas: 3,
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: TipografiaApp.caption.copyWith(
                    color: ColoresApp.statusDanger,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  BotonSecundario(
                    etiqueta: 'Cancelar',
                    alPresionar: _creando ? null : _cancelar,
                  ),
                  const SizedBox(width: 12),
                  BotonPrimario(
                    etiqueta: _creando ? 'Abriendo…' : 'Abrir orden',
                    icono: Icons.arrow_forward_rounded,
                    // Sin moto no hay orden posible: la columna es `NOT NULL`.
                    alPresionar: _moto == null || _creando ? null : _crear,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
