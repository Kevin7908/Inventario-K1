import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../../../backend/features/motos/modelo/moto.dart';
import '../../../../../core/formato.dart';
import '../../../../share2/share2.dart';
import '../../../clientes/provider/cliente_provider.dart';
import '../../../motos/provider/motos_provider.dart';
import '../../provider/deudores_providers.dart';

/// A quién se le fía, antes de abrir la ficha.
///
/// Existe por lo mismo que el de reservas: `deudores.cliente_id` es `NOT NULL`,
/// así que la deuda no se puede crear vacía y la ficha no puede empezar sin
/// ella. Y escapar de este cuadro no crea nada, así que entrar y arrepentirse
/// no quema un consecutivo `DEU-`.
///
/// **No pregunta el monto**: la deuda nace en cero y el total sale de los
/// repuestos que se le anoten dentro, como una reserva. Antes se tecleaba a
/// mano y era la única forma de que la cifra no cuadrara con nada.
///
/// La moto es **opcional**: hay fiados de mostrador que no van a ninguna moto.
/// El concepto también —las líneas ya dicen qué se llevó—, y sirve para el
/// caso en que haga falta nombrarlo («Reparación del motor»).
class DialogoNuevaDeuda extends ConsumerStatefulWidget {
  const DialogoNuevaDeuda({super.key});

  /// Devuelve el id de la deuda creada, o `null` si se canceló.
  static Future<int?> mostrar(BuildContext context) => showDialog<int>(
        context: context,
        builder: (_) => const DialogoNuevaDeuda(),
      );

  @override
  ConsumerState<DialogoNuevaDeuda> createState() => _DialogoNuevaDeudaState();
}

class _DialogoNuevaDeudaState extends ConsumerState<DialogoNuevaDeuda> {
  final _concepto = TextEditingController();

  Cliente? _cliente;
  Moto? _moto;
  DateTime? _vence;
  bool _creando = false;
  String? _error;

  @override
  void dispose() {
    _concepto.dispose();
    super.dispose();
  }

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
      final id = await ref.read(repositorioDeudoresProvider).crear(
            clienteId: clienteId,
            motoId: _moto?.id,
            concepto: _concepto.text.trim(),
            fechaVencimiento: _vence,
          );
      if (!mounted) return;
      // El listado y los contadores se enteran solos: sus consultas son
      // streams de Drift.
      Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creando = false;
        _error = 'No se pudo crear la deuda: $e';
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

    // Solo las motos del cliente elegido: ofrecer las del taller entero invita
    // a cargarle a alguien el repuesto de la moto de otro.
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
          width: 460,
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
              const Text('Nueva deuda', style: TipografiaApp.heading3),
              const SizedBox(height: 6),
              const Text(
                'A quién se le fía. Los repuestos se eligen dentro.',
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
                    : 'Opcional: en qué moto se montó…',
                alCambiar: (moto) => setState(() => _moto = moto),
              ),
              const SizedBox(height: 14),
              CampoTexto(
                etiqueta: 'Concepto',
                controlador: _concepto,
                placeholder: 'Opcional: cómo se llama este fiado…',
              ),
              const SizedBox(height: 14),
              CampoFecha(
                etiqueta: 'Vence',
                valor: _vence,
                formatear: formatearFecha,
                placeholder: 'Opcional: hasta cuándo tiene plazo',
                alCambiar: (fecha) => setState(() => _vence = fecha),
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
                    etiqueta: _creando ? 'Creando…' : 'Abrir deuda',
                    icono: Icons.arrow_forward_rounded,
                    // Sin cliente no hay deuda: la columna es `NOT NULL`.
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
