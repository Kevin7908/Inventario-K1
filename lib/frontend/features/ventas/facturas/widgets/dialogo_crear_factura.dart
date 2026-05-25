import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../../../backend/features/ventas/facturas/enum/enum_facturas.dart';
import '../../../../../backend/features/ventas/facturas/modelo/factura_detalle.dart';
import '../../../../../backend/features/ventas/facturas/modelo/factura_resumen.dart';
import '../../../../share/temas/colores_app.dart';
import '../../../../share/widgets/input/app_searc_widget.dart';
import '../../../../share/widgets/output/snack_bar_mensaje.dart';
import '../../../clientes/provider/cliente_provider.dart';
import '../provider/facturas_provider.dart';

class DialogoCrearFactura extends ConsumerStatefulWidget {
  const DialogoCrearFactura({
    super.key,
    this.facturaAEditar,
    this.ordenId,
    this.clienteId,
    this.clienteNombre,
    this.facturaExistente,
    this.tipoFijo,
  });
  final FacturaDetalle? facturaAEditar;
  final int? ordenId;
  final int? clienteId;
  final String? clienteNombre;
  final FacturaResumen? facturaExistente;
  final TipoVenta? tipoFijo;

  bool get esEdicion => facturaAEditar != null;
  bool get esDesdeOrden => ordenId != null;

  static Future<void> mostrar(
    BuildContext context, {
    FacturaDetalle? facturaAEditar,
    int? ordenId,
    int? clienteId,
    String? clienteNombre,
    FacturaResumen? facturaExistente,
    TipoVenta? tipoFijo,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoCrearFactura(
        facturaAEditar:   facturaAEditar,
        ordenId:          ordenId,
        clienteId:        clienteId,
        clienteNombre:    clienteNombre,
        facturaExistente: facturaExistente,
        tipoFijo:         tipoFijo,
      ),
    );
  }

  @override
  ConsumerState<DialogoCrearFactura> createState() =>
      _DialogoCrearFacturaState();
}

class _DialogoCrearFacturaState extends ConsumerState<DialogoCrearFactura> {
  final _formKey = GlobalKey<FormState>();
  late final ValueNotifier<Cliente?> _clienteNotifier;
  late MetodoPago _metodoPago;
  late EstadoPago _estadoPago;
  late TipoVenta _tipo;
  late final TextEditingController _ivaCtrl;
  late final TextEditingController _descuentoCtrl;
  bool _guardando = false;
  bool _clientePreseleccionado = false;

  @override
  void initState() {
    super.initState();
    final f = widget.facturaAEditar;
    final ex = widget.facturaExistente;
    _clienteNotifier = ValueNotifier(null);
    _metodoPago = f?.metodoPago ?? ex?.metodoPago ?? MetodoPago.efectivo;
    _estadoPago = f?.estadoPago ?? ex?.estadoPago ?? EstadoPago.pendiente;
    _tipo       = f?.tipo ?? widget.tipoFijo ?? TipoVenta.servicio;
    _ivaCtrl = TextEditingController(
      text: f != null
          ? f.iva.toStringAsFixed(0)
          : ex != null
              ? ex.iva.toStringAsFixed(0)
              : '0',
    );
    _descuentoCtrl = TextEditingController(
      text: f != null ? f.descuento.toStringAsFixed(0) : '0',
    );
  }

  @override
  void dispose() {
    _clienteNotifier.dispose();
    _ivaCtrl.dispose();
    _descuentoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final notifier   = ref.read(facturasProvider.notifier);
    final iva        = double.tryParse(_ivaCtrl.text.trim()) ?? 0;
    final descuento  = double.tryParse(_descuentoCtrl.text.trim()) ?? 0;
    String? error;

    if (widget.esEdicion) {
      error = await notifier.actualizar(
        id:               widget.facturaAEditar!.id,
        metodoPago:       _metodoPago,
        estadoPago:       _estadoPago,
        iva:              iva,
        descuento:        descuento,
        actualizarCliente: true,
        clienteId:        _clienteNotifier.value?.id,
      );
    } else if (widget.esDesdeOrden && widget.facturaExistente != null) {
      error = await notifier.actualizarDesdeOrden(
        facturaId:  widget.facturaExistente!.id,
        ordenId:    widget.ordenId!,
        metodoPago: _metodoPago,
        estadoPago: _estadoPago,
        iva:        iva,
      );
    } else if (widget.esDesdeOrden) {
      error = await notifier.crearDesdeOrden(
        ordenId:    widget.ordenId!,
        clienteId:  widget.clienteId!,
        metodoPago: _metodoPago,
        estadoPago: _estadoPago,
        iva:        iva,
      );
    } else {
      error = await notifier.crear(
        tipo:       _tipo,
        clienteId:  _clienteNotifier.value?.id,
        metodoPago: _metodoPago,
        estadoPago: _estadoPago,
        iva:        iva,
        descuento:  descuento,
      );
    }

    if (!mounted) return;
    if (error != null) {
      SnackBarMensaje.error(context, error);
      setState(() => _guardando = false);
    } else {
      Navigator.of(context).pop();
      SnackBarMensaje.success(
        context,
        widget.esEdicion || widget.facturaExistente != null
            ? 'Factura actualizada.'
            : 'Factura creada.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientes = ref.watch(clientesProvider).value?.filtrados ?? const [];

    if (widget.esEdicion && !_clientePreseleccionado && clientes.isNotEmpty) {
      final clienteId = widget.facturaAEditar!.clienteId;
      if (clienteId != null) {
        final encontrado = clientes.where((c) => c.id == clienteId).firstOrNull;
        if (encontrado != null) _clienteNotifier.value = encontrado;
      }
      _clientePreseleccionado = true;
    }

    return Dialog(
      backgroundColor: ColoresApp.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 480,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildEncabezado(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!widget.esEdicion && widget.esDesdeOrden) ...[
                        _label('Cliente'),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: ColoresApp.bgContent,
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: ColoresApp.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person_outline,
                                  size: 16, color: ColoresApp.textLight),
                              const SizedBox(width: 8),
                              Text(
                                widget.clienteNombre ?? '—',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: ColoresApp.textDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ColoresApp.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: ColoresApp.primary
                                    .withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  size: 14, color: ColoresApp.primary),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Se importarán automáticamente las tareas y repuestos de la orden.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ColoresApp.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (!widget.esEdicion && !widget.esDesdeOrden && widget.tipoFijo == null) ...[
                        _label('Tipo de venta *'),
                        const SizedBox(height: 8),
                        Row(
                          children: TipoVenta.values.map((t) {
                            final sel = _tipo == t;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _tipo = t),
                                child: Container(
                                  margin: EdgeInsets.only(
                                      right: t == TipoVenta.values.last ? 0 : 8),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? ColoresApp.primary.withValues(alpha: 0.08)
                                        : ColoresApp.bgContent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: sel
                                          ? ColoresApp.primary
                                          : ColoresApp.border,
                                      width: sel ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    t.etiqueta,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: sel
                                          ? ColoresApp.primary
                                          : ColoresApp.textMedium,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (!widget.esDesdeOrden) ...[
                        _label('Cliente (opcional)'),
                        const SizedBox(height: 6),
                        AppSearch<Cliente>(
                          notifier: _clienteNotifier,
                          items: clientes,
                          labelBuilder: (c) =>
                              '${c.nombres} ${c.apellidos ?? ''}'.trim(),
                          hint: 'Seleccionar cliente...',
                        ),
                        const SizedBox(height: 16),
                      ],

                      _label('Método de pago *'),
                      const SizedBox(height: 8),
                      _SelectorChip<MetodoPago>(
                        opciones: MetodoPago.values,
                        seleccionado: _metodoPago,
                        labelOf: (m) => m.etiqueta,
                        onTap: (m) => setState(() => _metodoPago = m),
                      ),
                      const SizedBox(height: 16),

                      _label('Estado de pago *'),
                      const SizedBox(height: 8),
                      _SelectorChip<EstadoPago>(
                        opciones: EstadoPago.values,
                        seleccionado: _estadoPago,
                        labelOf: (e) => e.etiqueta,
                        onTap: (e) => setState(() => _estadoPago = e),
                      ),
                      const SizedBox(height: 16),

                      _label('IVA (valor en \$)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _ivaCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        decoration: _inputDeco('0'),
                        validator: (v) {
                          if (v != null && v.isNotEmpty) {
                            if (double.tryParse(v.trim()) == null) return 'Valor inválido.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _label('Descuento (valor en \$)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descuentoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        decoration: _inputDeco('0'),
                        validator: (v) {
                          if (v != null && v.isNotEmpty) {
                            if (double.tryParse(v.trim()) == null) return 'Valor inválido.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
            _buildBotones(),
          ],
        ),
      ),
    );
  }

  Widget _buildEncabezado() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 20, 0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ColoresApp.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.request_quote_outlined,
                color: ColoresApp.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              widget.esEdicion ? 'Editar Factura' : 'Nueva Factura',
              style: const TextStyle(
                color: ColoresApp.textDark,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: _guardando ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: ColoresApp.textMedium),
            style: IconButton.styleFrom(
              backgroundColor: ColoresApp.bgContent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotones() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _guardando ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: ColoresApp.textMedium,
                side: const BorderSide(color: ColoresApp.border),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: ColoresApp.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: _guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(widget.esEdicion ? 'Guardar cambios' : 'Crear factura'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String texto) => Text(
        texto,
        style: const TextStyle(
            color: ColoresApp.textDark, fontSize: 13, fontWeight: FontWeight.w600),
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: ColoresApp.textLight, fontSize: 13.5),
        filled: true,
        fillColor: ColoresApp.bgContent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ColoresApp.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ColoresApp.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ColoresApp.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ColoresApp.statusDebt)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ColoresApp.statusDebt, width: 1.5)),
      );
}

class _SelectorChip<T> extends StatelessWidget {
  const _SelectorChip({
    required this.opciones,
    required this.seleccionado,
    required this.labelOf,
    required this.onTap,
  });
  final List<T> opciones;
  final T seleccionado;
  final String Function(T) labelOf;
  final ValueChanged<T> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: opciones.map((o) {
        final sel = o == seleccionado;
        return GestureDetector(
          onTap: () => onTap(o),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: sel
                  ? ColoresApp.primary.withValues(alpha: 0.08)
                  : ColoresApp.bgContent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: sel ? ColoresApp.primary : ColoresApp.border,
                width: sel ? 1.5 : 1,
              ),
            ),
            child: Text(
              labelOf(o),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: sel ? ColoresApp.primary : ColoresApp.textMedium,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
