import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../../../backend/features/motos/modelo/moto.dart';
import '../../../../../core/formato.dart';
import '../../../../share/share.dart';
import '../../../clientes/provider/cliente_provider.dart';
import '../../../motos/provider/motos_provider.dart';
import '../../provider/reservas_providers.dart';

/// Para quién se aparta la mercancía, antes de abrir el editor.
///
/// Existe por lo mismo que el de órdenes: `reservas.cliente_id` es `NOT NULL`,
/// así que la reserva no se puede crear vacía y el editor no puede empezar sin
/// ella. Y escapar de este cuadro no crea nada, así que entrar y arrepentirse
/// no quema un consecutivo `RES-`.
///
/// La moto es **opcional**, a diferencia de una orden: se aparta un repuesto
/// para alguien, y a veces todavía no se sabe para qué moto va. La fecha
/// límite también: hay apartados sin plazo.
class DialogoNuevaReserva extends ConsumerStatefulWidget {
  const DialogoNuevaReserva({super.key});

  /// Devuelve el id de la reserva creada, o `null` si se canceló.
  static Future<int?> mostrar(BuildContext context) => showDialog<int>(
        context: context,
        builder: (_) => const DialogoNuevaReserva(),
      );

  @override
  ConsumerState<DialogoNuevaReserva> createState() =>
      _DialogoNuevaReservaState();
}

class _DialogoNuevaReservaState extends ConsumerState<DialogoNuevaReserva> {
  Cliente? _cliente;
  Moto? _moto;
  DateTime? _fechaLimite;
  bool _creando = false;
  String? _error;

  /// Al cambiar de cliente se olvida la moto: la que estaba elegida es de otro.
  void _elegirCliente(Cliente? cliente) => setState(() {
        _cliente = cliente;
        _moto = null;
      });

  Future<void> _crear() async {
    final clienteId = _cliente?.id;
    if (clienteId == null || _creando) return;

    setState(() {
      _creando = true;
      _error = null;
    });

    try {
      final id = await ref.read(repositorioReservasProvider).crear(
            clienteId: clienteId,
            motoId: _moto?.id,
            fechaLimite: _fechaLimite,
            // Nace vacía: el total es la suma de sus líneas, y todavía no hay.
            totalReserva: 0,
            items: const [],
          );
      if (!mounted) return;
      // El listado se entera solo: su consulta es un stream de Drift.
      Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creando = false;
        _error = 'No se pudo crear la reserva: $e';
      });
    }
  }

  void _cancelar() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final clientes =
        ref.watch(catalogoClientesProvider).value ?? const <Cliente>[];
    final todasLasMotos =
        ref.watch(catalogoMotosProvider).value ?? const <Moto>[];

    // Solo las motos del cliente elegido: ofrecer las del taller entero
    // invita a apartarle una pieza a la moto de otro.
    final motos = _cliente == null
        ? const <Moto>[]
        : [
            for (final m in todasLasMotos)
              if (m.clienteId == _cliente!.id) m,
          ];

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
              const Text('Nueva reserva', style: TipografiaApp.heading3),
              const SizedBox(height: 6),
              const Text(
                'Para quién se aparta. La mercancía se elige dentro.',
                style: TipografiaApp.caption,
              ),
              const SizedBox(height: 20),
              CampoBusqueda<Cliente>(
                etiqueta: 'Cliente *',
                valor: _cliente,
                opciones: clientes,
                constructorEtiqueta: (c) => c.nombreCompleto,
                constructorDetalle: (c) => c.telefono,
                placeholder: 'Buscar por nombre o teléfono…',
                alCambiar: _elegirCliente,
              ),
              const SizedBox(height: 14),
              CampoBusqueda<Moto>(
                etiqueta: 'Moto',
                valor: _moto,
                opciones: motos,
                constructorEtiqueta: (m) => m.nombreDisplay,
                constructorDetalle: (m) => m.placa,
                placeholder: _cliente == null
                    ? 'Elige primero el cliente'
                    : 'Opcional: para qué moto es…',
                alCambiar: (moto) => setState(() => _moto = moto),
              ),
              const SizedBox(height: 14),
              CampoFecha(
                etiqueta: 'Se guarda hasta',
                valor: _fechaLimite,
                formatear: formatearFecha,
                placeholder: 'Opcional: hasta cuándo se aparta',
                alCambiar: (fecha) => setState(() => _fechaLimite = fecha),
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
                    etiqueta: _creando ? 'Creando…' : 'Abrir reserva',
                    icono: Icons.arrow_forward_rounded,
                    // Sin cliente no hay reserva: la columna es `NOT NULL`.
                    alPresionar: _cliente == null || _creando ? null : _crear,
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
