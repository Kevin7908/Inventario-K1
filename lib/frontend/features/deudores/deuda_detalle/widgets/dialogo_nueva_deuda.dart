import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../../../core/formato.dart';
import '../../../../share2/share2.dart';
import '../../../clientes/provider/cliente_provider.dart';
import '../../provider/deudores_providers.dart';

/// Quién debe, cuánto y por qué, antes de abrir la ficha.
///
/// **La deuda nace aquí, no en una factura.** Antes solo aparecía como resto
/// de una venta a crédito; desde que el mostrador cobra completo, fiar es una
/// decisión que se toma en Cuentas por cobrar, igual que apartar mercancía se
/// decide en Reservas.
///
/// Los tres campos de arriba son obligatorios porque las columnas lo son:
/// `cliente_id` es `NOT NULL`, y el esquema exige concepto no vacío y monto
/// mayor que cero. El plazo es opcional —hay fiados sin fecha— y el abono
/// inicial también: está porque lo normal es que el cliente deje algo.
///
/// Escapar del cuadro no crea nada, así que entrar y arrepentirse no quema un
/// consecutivo `DEU-`.
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
  final _monto = TextEditingController();
  final _abono = TextEditingController();

  Cliente? _cliente;
  DateTime? _vence;
  bool _creando = false;
  String? _error;

  @override
  void dispose() {
    _concepto.dispose();
    _monto.dispose();
    _abono.dispose();
    super.dispose();
  }

  int get _montoTotal => int.tryParse(_monto.text) ?? 0;
  int get _pagoInicial => int.tryParse(_abono.text) ?? 0;

  bool get _puedeCrear =>
      !_creando &&
      _cliente != null &&
      _concepto.text.trim().isNotEmpty &&
      _montoTotal > 0 &&
      _pagoInicial <= _montoTotal;

  Future<void> _crear() async {
    final clienteId = _cliente?.id;
    if (clienteId == null || !_puedeCrear) return;

    setState(() {
      _creando = true;
      _error = null;
    });

    try {
      final id = await ref.read(repositorioDeudoresProvider).crear(
            clienteId: clienteId,
            concepto: _concepto.text.trim(),
            montoTotal: _montoTotal,
            fechaVencimiento: _vence,
            pagoInicial: _pagoInicial,
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
    final excedido = _pagoInicial > _montoTotal && _montoTotal > 0;

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
                'Quién queda debiendo y por cuánto. Los abonos se registran '
                'después, en la ficha.',
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
                alCambiar: (c) => setState(() => _cliente = c),
              ),
              const SizedBox(height: 14),
              CampoTexto(
                etiqueta: 'Concepto *',
                controlador: _concepto,
                placeholder: 'Por qué queda debiendo…',
                alCambiar: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              FilaCampos(
                // Van juntos porque se tecleen juntos: el abono inicial solo
                // significa algo al lado del monto.
                anchoMinimo: 360,
                hijos: [
                  CampoTexto(
                    etiqueta: 'Monto total *',
                    controlador: _monto,
                    placeholder: '0',
                    soloEnteros: true,
                    alCambiar: (_) => setState(() {}),
                  ),
                  CampoTexto(
                    etiqueta: 'Abono inicial',
                    controlador: _abono,
                    placeholder: 'Opcional',
                    soloEnteros: true,
                    alCambiar: (_) => setState(() {}),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              CampoFecha(
                etiqueta: 'Vence',
                valor: _vence,
                formatear: formatearFecha,
                placeholder: 'Opcional: hasta cuándo tiene plazo',
                alCambiar: (fecha) => setState(() => _vence = fecha),
              ),
              if (excedido) ...[
                const SizedBox(height: 12),
                Text(
                  'El abono inicial no puede pasar del monto: si ya pagó todo, '
                  'no hay deuda que anotar.',
                  style: TipografiaApp.caption.copyWith(
                    color: ColoresApp.statusDanger,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
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
                    alPresionar: _puedeCrear ? _crear : null,
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
