import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/backend/features/motos/modelo/moto.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/backend/share/database/locator.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';
import 'package:inventario_k1/frontend/share/widgets/input/app_searc_widget.dart';
import 'package:inventario_k1/frontend/share/widgets/output/snack_bar_mensaje.dart';

import 'package:inventario_k1/backend/features/cotizaciones/enum/enum_cotizacion.dart';
import 'package:inventario_k1/backend/features/cotizaciones/modelo/cotizacion_detalle.dart';
import 'package:inventario_k1/backend/features/cotizaciones/modelo/cotizacion_resumen.dart';
import 'package:inventario_k1/frontend/features/cotizaciones/provider/cotizaciones_provider.dart';
import 'package:inventario_k1/frontend/features/motos/widgets/dialogo_motos.dart';
import 'package:inventario_k1/frontend/features/productos/widgets/dialogo_producto_widget.dart';
import 'package:inventario_k1/frontend/features/proveedores/view_model/proveedores_view_model.dart';
import 'dialogo_cot_form_fields.dart';
import 'dialogo_cot_header.dart';
import 'dialogo_cot_items_tabla.dart';
import 'dialogo_cot_totales.dart';

/// Diálogo unificado agregar / editar.
/// [cotizacion] == null → agregar. != null → editar.
class DialogoCotizacion extends ConsumerStatefulWidget {
  const DialogoCotizacion({super.key, this.cotizacion, this.detalle});

  final CotizacionResumen? cotizacion;
  final CotizacionDetalle? detalle;

  static Future<void> mostrar(
    BuildContext context, {
    CotizacionResumen? cotizacion,
    CotizacionDetalle? detalle,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: false,
      builder: (_) =>
          DialogoCotizacion(cotizacion: cotizacion, detalle: detalle),
    );
  }

  @override
  ConsumerState<DialogoCotizacion> createState() => _DialogoCotizacionState();
}

class _DialogoCotizacionState extends ConsumerState<DialogoCotizacion> {
  bool get _esEditar => widget.cotizacion != null;

  late final ValueNotifier<Moto?> _motoNotifier;
  late final TextEditingController _vigenciaCtrl;
  late final TextEditingController _notasCtrl;

  String _nombreCliente = '';
  String _telefonoCliente = '';
  final List<CotItemDraft> _items = [];
  bool _cargando = false;

  int get _subtotal => _items.fold(0, (s, i) => s + i.subtotal);
  int get _iva => (_subtotal * kTasaIva).round();
  int get _total => _subtotal + _iva;

  void rebuild(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    _motoNotifier = ValueNotifier(null);
    _vigenciaCtrl = TextEditingController();
    _notasCtrl = TextEditingController();

    if (_esEditar) {
      final cot = widget.cotizacion!;
      _vigenciaCtrl.text = cot.vigenciaHasta;
      _notasCtrl.text = cot.notas ?? '';
      _nombreCliente = cot.nombreCliente;
      _telefonoCliente = cot.telefonoCliente ?? '';
      if (widget.detalle != null) {
        for (final item in widget.detalle!.items) {
          _items.add(CotItemDraft(
            tipo: item.tipoItem,
            referenciaId: item.referenciaId,
            descripcion: item.descripcion,
            cantidad: item.cantidad,
            precioUnitario: item.precioUnitario,
          ));
        }
      }
    }
  }

  @override
  void dispose() {
    _motoNotifier.dispose();
    _vigenciaCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  void _onMotoSeleccionada(Moto? moto) {
    if (moto == null) return;
    setState(() => _nombreCliente = moto.nombreCliente ?? '');
    final clientes = ref.read(clientesParaCotizacionProvider).value ?? [];
    final cliente =
        clientes.where((c) => c.id == moto.clienteId).firstOrNull;
    setState(() => _telefonoCliente = cliente?.telefono ?? '');
  }

  Future<void> _abrirFecha() async {
    final ahora = DateTime.now();
    final inicial = DateTime.tryParse(_vigenciaCtrl.text) ??
        ahora.add(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: ahora,
      lastDate: ahora.add(const Duration(days: 365 * 3)),
    );
    if (picked != null && mounted) {
      setState(() {
        _vigenciaCtrl.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  /// Mini-diálogo de selección genérico tipado.
  /// El precio viene del producto (solo lectura cuando [precioReadOnly] es true).
  void _seleccionarItem<T extends Object>({
    required String titulo,
    required IconData icono,
    required List<T> items,
    required String Function(T) labelBuilder,
    required void Function(T item, double cantidad, int precio) onSeleccionado,
    int Function(T)? precioInicial,
    VoidCallback? onAgregar,
    bool precioReadOnly = false,
  }) {
    final notifier = ValueNotifier<T?>(null);
    final cantCtrl = TextEditingController(text: '1');
    // precio se almacena como int (no editable si precioReadOnly)
    var precioActual = 0;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Dialog(
          backgroundColor: ColoresApp.bgCard,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: 460,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MiniDialogoHeader(titulo: titulo, icono: icono, ctx: ctx),
                  const SizedBox(height: 16),

                  // Búsqueda del ítem
                  AppSearch<T>(
                    notifier: notifier,
                    items: items,
                    labelBuilder: labelBuilder,
                    hint: 'Buscar...',
                    onAgregar: onAgregar,
                    onChanged: (item) {
                      if (item != null && precioInicial != null) {
                        precioActual = precioInicial(item);
                      }
                      setSt(() {});
                    },
                  ),
                  const SizedBox(height: 12),

                  // Campos cantidad + precio
                  Row(
                    children: [
                      Expanded(
                        child: _MiniCampo(
                          label: 'Cantidad',
                          ctrl: cantCtrl,
                          onChanged: () => setSt(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: precioReadOnly
                            ? _MiniPrecioAutoField(precio: precioActual)
                            : _MiniCampo(
                                label: 'Precio (\$)',
                                ctrl: TextEditingController(
                                    text: precioActual.toString()),
                                onChanged: () => setSt(() {}),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: notifier.value == null
                          ? null
                          : () {
                              final cant =
                                  double.tryParse(cantCtrl.text) ?? 1;
                              Navigator.of(ctx).pop();
                              onSeleccionado(
                                  notifier.value as T, cant, precioActual);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColoresApp.primary,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Agregar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).then((_) {
      notifier.dispose();
      cantCtrl.dispose();
    });
  }

  void _agregarProducto(List<Producto> producto) {
    final productos =
        ref.read(productosParaCotizacionProvider).value ?? <Producto>[];
    _seleccionarItem<Producto>(
      titulo: 'Agregar Producto',
      icono: Icons.inventory_2_outlined,
      items: productos,
      labelBuilder: (p) => p.nombre,
      precioInicial: (p) => p.precioVenta.round(),
      precioReadOnly: true,
      onAgregar: () {
        DialogoProducto.mostrar(
          context,
          proveedoresVm: locator<ProveedoresViewModel>(),
        ).then((_) => ref.invalidate(productosParaCotizacionProvider));
      },
      onSeleccionado: (p, cant, precio) => setState(() => _items.add(
            CotItemDraft(
              tipo: TipoItemCotizacion.producto,
              referenciaId: p.id,
              descripcion: p.nombre,
              cantidad: cant,
              precioUnitario: precio,
            ),
          )),
    );
  }

  Future<void> _guardar() async {
    final moto = _motoNotifier.value;
    if (!_esEditar && moto == null) {
      SnackBarMensaje.error(context, 'Selecciona una moto para continuar');
      return;
    }
    if (_vigenciaCtrl.text.isEmpty) {
      SnackBarMensaje.error(context, 'Ingresa la fecha de vigencia');
      return;
    }
    setState(() => _cargando = true);

    final notifier = ref.read(cotizacionesProvider.notifier);
    final notas =
        _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim();
    final itemsDraft = _items.map((i) => i.toItemDraft()).toList();
    String? error;

    if (_esEditar) {
      final cot = widget.cotizacion!;
      error = await notifier.actualizar(
        id: cot.id,
        clienteId: moto?.clienteId ?? cot.clienteId,
        motoId: moto?.id ?? cot.motoId,
        vigenciaHasta: _vigenciaCtrl.text,
        notas: notas,
        items: itemsDraft,
      );
    } else {
      error = await notifier.crear(
        clienteId: moto!.clienteId,
        motoId: moto.id,
        vigenciaHasta: _vigenciaCtrl.text,
        notas: notas,
        items: itemsDraft,
      );
    }

    if (!mounted) return;
    setState(() => _cargando = false);

    if (error != null) {
      SnackBarMensaje.error(context, error);
      return;
    }
    SnackBarMensaje.success(
      context,
      _esEditar ? 'Cotización actualizada.' : 'Cotización creada.',
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final motos = ref.watch(motosParaCotizacionProvider).value ?? <Moto>[];
    final productos = ref.watch(productosParaCotizacionProvider).value ?? <Producto>[];

    return Dialog(
      backgroundColor: ColoresApp.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: SizedBox(
        width: 720,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DialogoCotHeader(esEditar: _esEditar),
            Flexible(child: _CuerpoDialogo(state: this, motos: motos, productos: productos)),
            DialogoCotFooter(
              cargando: _cargando,
              esEditar: _esEditar,
              onCancelar: () => Navigator.of(context).pop(),
              onGuardar: _guardar,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cuerpo del diálogo ────────────────────────────────────────────────────────

class _CuerpoDialogo extends StatelessWidget {
  const _CuerpoDialogo({required this.state, required this.motos, required this.productos});

  final _DialogoCotizacionState state;
  final List<Moto> motos;
  final List<Producto> productos;

  @override
  Widget build(BuildContext context) {
    final esEditar = state._esEditar;
    final cot = state.widget.cotizacion;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cliente ────────────────────────────────────────────────
          const CotSeccionLabel(
              icono: Icons.person_outline_rounded, label: 'DATOS DEL CLIENTE'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CotFieldLabel('MOTO DE INTERÉS *'),
                    const SizedBox(height: 6),
                    AppSearch<Moto>(
                      notifier: state._motoNotifier,
                      items: motos,
                      labelBuilder: (m) => m.nombreDisplay,
                      hint: 'Buscar moto...',
                      onChanged: state._onMotoSeleccionada,
                      onAgregar: () {
                        // Crear nueva moto y refrescar lista
                        DialogoMoto.mostrar(context).then((_) {
                          state.ref.invalidate(motosParaCotizacionProvider);
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CotFieldLabel('CLIENTE (auto)'),
                    const SizedBox(height: 6),
                    CotReadOnlyField(
                      valor: state._nombreCliente.isEmpty
                          ? (esEditar
                              ? cot!.nombreCliente
                              : 'Se llenará al escoger moto')
                          : state._nombreCliente,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CotFieldLabel('TELÉFONO (auto)'),
                    const SizedBox(height: 6),
                    CotReadOnlyField(
                      valor: state._telefonoCliente.isEmpty
                          ? (esEditar ? (cot!.telefonoCliente ?? '—') : '—')
                          : state._telefonoCliente,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 20),

          // ── Condiciones ────────────────────────────────────────────
          const CotSeccionLabel(
              icono: Icons.calendar_today_outlined, label: 'CONDICIONES'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CotFieldLabel('VIGENCIA HASTA *'),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: state._abrirFecha,
                      child: AbsorbPointer(
                        child: TextField(
                          controller: state._vigenciaCtrl,
                          readOnly: true,
                          style: const TextStyle(
                              color: ColoresApp.textDark, fontSize: 13.5),
                          decoration: cotInputDecoration(
                            hint: 'YYYY-MM-DD',
                            suffixIcon: Icons.calendar_month_outlined,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CotFieldLabel('NOTAS INTERNAS'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: state._notasCtrl,
                      maxLines: 2,
                      style: const TextStyle(
                          color: ColoresApp.textDark, fontSize: 13.5),
                      decoration: cotInputDecoration(
                          hint: 'Ej: Cliente solicitó financiamiento...'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Ítems ──────────────────────────────────────────────────
          const CotSeccionLabel(
              icono: Icons.list_alt_outlined, label: 'ÍTEMS'),
          const SizedBox(height: 12),
          if (state._items.isNotEmpty) ...[
            const CotItemsTablaHeader(),
            const SizedBox(height: 4),
            for (int i = 0; i < state._items.length; i++)
              CotItemFila(
                key: ValueKey(i),
                item: state._items[i],
                onEliminar: () =>
                    state.rebuild(() => state._items.removeAt(i)),
                onCantidadChange: (v) =>
                    state.rebuild(() => state._items[i].cantidad = v),
                onPrecioChange: (v) =>
                    state.rebuild(() => state._items[i].precioUnitario = v),
              ),
            const SizedBox(height: 12),
          ],
          CotBtnAgregar(
            label: '+ Agregar Producto',
            onTap:() => state._agregarProducto(productos),
          ),
          const SizedBox(height: 20),
          CotTotalesResumen(
              subtotal: state._subtotal,
              iva: state._iva,
              total: state._total),
        ],
      ),
    );
  }
}

// ── Widgets del mini-diálogo de selección ────────────────────────────────────

class _MiniDialogoHeader extends StatelessWidget {
  const _MiniDialogoHeader({
    required this.titulo,
    required this.icono,
    required this.ctx,
  });

  final String titulo;
  final IconData icono;
  final BuildContext ctx;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: ColoresApp.primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icono, color: ColoresApp.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: ColoresApp.textDark),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded,
              color: ColoresApp.textLight, size: 18),
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ],
    );
  }
}

class _MiniCampo extends StatelessWidget {
  const _MiniCampo({
    required this.label,
    required this.ctrl,
    required this.onChanged,
  });

  final String label;
  final TextEditingController ctrl;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              color: ColoresApp.textMedium,
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          onChanged: (_) => onChanged(),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: ColoresApp.textDark, fontSize: 13.5),
          decoration: InputDecoration(
            filled: true,
            fillColor: ColoresApp.bgContent,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: ColoresApp.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: ColoresApp.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Campo de precio de solo lectura dentro del mini-diálogo.
class _MiniPrecioAutoField extends StatelessWidget {
  const _MiniPrecioAutoField({required this.precio});

  final int precio;

  @override
  Widget build(BuildContext context) {
    final tieneValor = precio > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Precio (\$)',
          style: TextStyle(
              color: ColoresApp.textMedium,
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: ColoresApp.bgContent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ColoresApp.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tieneValor ? '\$$precio' : 'Del producto',
                style: TextStyle(
                  color: tieneValor
                      ? ColoresApp.textDark
                      : ColoresApp.textLight,
                  fontSize: 13.5,
                  fontStyle: tieneValor
                      ? FontStyle.normal
                      : FontStyle.italic,
                ),
              ),
              const Icon(Icons.lock_outline_rounded,
                  size: 14, color: ColoresApp.textLight),
            ],
          ),
        ),
      ],
    );
  }
}
