import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../backend/features/deudores/enum/enum_deudor.dart';
import '../../../../../../backend/features/deudores/modelo/deudor_resumen.dart';
import '../../../../../../backend/features/ventas/facturas/enum/enum_facturas.dart';
import '../../../../../share/formateadores/moneda_formateador.dart';
import '../../../../../share/temas/colores_app.dart';
import '../../../../../share/widgets/output/snack_bar_mensaje.dart';
import '../../../../deudores/provider/deudores_provider.dart';
import '../../widgets/dialogo_cobro_pos.dart';
import '../../provider/facturas_provider.dart';
import 'detalle_shared_widgets_factura.dart';

const _kBlue  = ColoresApp.primary;
const _kGreen = ColoresApp.accentGreen;
const _kRed   = ColoresApp.accentRed;

class ResumenFacturaPanel extends ConsumerStatefulWidget {
  const ResumenFacturaPanel({super.key, required this.facturaId});
  final int facturaId;

  @override
  ConsumerState<ResumenFacturaPanel> createState() => _ResumenFacturaPanelState();
}

class _ResumenFacturaPanelState extends ConsumerState<ResumenFacturaPanel> {
  bool _cobrando = false;

  Future<void> _cobrar() async {
    final detalle = ref.read(
      facturaDetalleProvider(widget.facturaId).select((a) => a.value),
    );
    if (detalle == null) return;

    final resultado = await DialogoCobrarPOS.mostrar(
      context,
      total:          detalle.saldoPendiente,
      clienteId:      detalle.clienteId,
      clienteNombre:  detalle.clienteNombre.isNotEmpty
          ? detalle.clienteNombre
          : null,
      numeroFactura:  detalle.numeroFactura,
    );
    if (resultado == null || !mounted) return;

    setState(() => _cobrando = true);
    final error = await ref.read(facturasProvider.notifier).cobrar(
      id:              detalle.id,
      totalPagado:     detalle.totalPagado + resultado.totalPagado,
      totalFactura:    detalle.total,
      estadoPago:      resultado.estadoPago,
      metodoPago:      detalle.metodoPago,
      clienteId:       detalle.clienteId,
      concepto:        resultado.datosDeuda?.concepto,
      metodoPagoDeuda: resultado.datosDeuda?.metodoPago,
      fechaVencimiento: resultado.datosDeuda?.fechaVencimiento,
      notasDeuda:      resultado.datosDeuda?.notas,
    );
    if (!mounted) return;
    setState(() => _cobrando = false);

    if (error != null) {
      SnackBarMensaje.error(context, error);
    } else {
      SnackBarMensaje.success(
        context,
        resultado.estadoPago == EstadoPago.pagado
            ? 'Factura marcada como pagada.'
            : 'Deuda registrada correctamente.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final detalle = ref.watch(
      facturaDetalleProvider(widget.facturaId).select((a) => a.value),
    );
    if (detalle == null) return const SizedBox.shrink();

    final deuda = ref.watch(deudorPorVentaProvider(widget.facturaId));

    final esPendiente   = detalle.estadoPago == EstadoPago.pendiente;
    final tieneDeuda    = esPendiente && deuda != null;
    final mostrarCobrar = esPendiente && deuda == null;

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 20, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColoresApp.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x07000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SeccionHeaderFactura(
            titulo: 'Resumen de la factura',
            icono:  Icons.receipt_long_outlined,
          ),

          if (detalle.itemsServicio.isNotEmpty)
            _ResumenBloque(
              titulo: 'Servicios',
              items:  detalle.itemsServicio
                  .map((i) => _Item(i.descripcion, i.subtotal))
                  .toList(),
            ),

          if (detalle.itemsProducto.isNotEmpty)
            _ResumenBloque(
              titulo: 'Productos',
              items:  detalle.itemsProducto
                  .map((i) => _Item(
                        '${i.descripcion} x${i.cantidad % 1 == 0 ? i.cantidad.toInt() : i.cantidad}',
                        i.subtotal,
                      ))
                  .toList(),
            ),

          // ── Totales ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: ColoresApp.border)),
            ),
            child: Column(
              children: [
                _FilaTotal('Subtotal', detalle.subtotal, false),
                if (detalle.descuento > 0) ...[
                  const SizedBox(height: 6),
                  _FilaTotal('Descuento', -detalle.descuento, false,
                      color: _kGreen),
                ],
                if (detalle.iva > 0) ...[
                  const SizedBox(height: 6),
                  _FilaTotal('IVA', detalle.iva, false),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: ColoresApp.border),
                ),
                _FilaTotal('TOTAL', detalle.total, true),
                if (detalle.totalPagado > 0 &&
                    detalle.totalPagado < detalle.total) ...[
                  const SizedBox(height: 8),
                  _FilaTotal('Pagado', detalle.totalPagado, false,
                      color: _kGreen),
                  const SizedBox(height: 4),
                  _FilaTotal(
                      'Saldo pendiente', detalle.saldoPendiente, false,
                      color: ColoresApp.statusPending),
                ],
              ],
            ),
          ),

          // ── Bloque de deuda activa ─────────────────────────────────
          if (tieneDeuda) ...[
            _DeudaInfoBloque(deuda: deuda),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cobrar deshabilitado
                  ElevatedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.bolt_rounded, size: 16),
                    label: Text(
                        'Cobrar ${fmtMoneda(detalle.saldoPendiente)}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColoresApp.border,
                      foregroundColor: ColoresApp.textLight,
                      disabledBackgroundColor: ColoresApp.border,
                      disabledForegroundColor: ColoresApp.textLight,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9)),
                      elevation: 0,
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Ver deuda
                  OutlinedButton.icon(
                    onPressed: () =>
                        _mostrarDetalleDeuda(context, deuda),
                    icon: const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 14),
                    label: Text('Ver deuda ${deuda.numero}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kBlue,
                      side: BorderSide(
                          color: _kBlue.withValues(alpha: 0.5)),
                      minimumSize: const Size.fromHeight(40),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9)),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Cobrar normal ──────────────────────────────────────────
          if (mostrarCobrar)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: ElevatedButton.icon(
                onPressed: _cobrando ? null : _cobrar,
                icon: _cobrando
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.bolt_rounded, size: 16),
                label: Text(
                  _cobrando
                      ? 'Procesando…'
                      : 'Cobrar ${fmtMoneda(detalle.saldoPendiente)}',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                  elevation: 0,
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _mostrarDetalleDeuda(BuildContext context, DeudorResumen deuda) {
    showDialog<void>(
      context: context,
      builder: (_) => _DialogoDeudaDetalle(deuda: deuda),
    );
  }
}

// ── Bloque info deuda (mini-card) ─────────────────────────────────────────────

class _DeudaInfoBloque extends StatelessWidget {
  const _DeudaInfoBloque({required this.deuda});
  final DeudorResumen deuda;

  static const _estadoColor = {
    EstadoDeudor.activa:      Color(0xFF3B82F6), // azul
    EstadoDeudor.pagada:      Color(0xFF10B981), // verde
    EstadoDeudor.vencida:     Color(0xFFEF4444), // rojo
    EstadoDeudor.incobrable:  Color(0xFF6B7280), // gris
  };

  @override
  Widget build(BuildContext context) {
    final color = _estadoColor[deuda.estado] ?? ColoresApp.textMedium;
    final porcentaje = deuda.porcentajePagado;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Número y estado ──────────────────────────────────────
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined,
                  size: 13, color: color),
              const SizedBox(width: 5),
              Text(
                deuda.numero,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _etiquetaEstado(deuda.estado),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Concepto ─────────────────────────────────────────────
          Text(
            deuda.concepto,
            style: const TextStyle(
              fontSize: 12,
              color: ColoresApp.textMedium,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // ── Montos ───────────────────────────────────────────────
          Row(
            children: [
              _InfoItem(
                label: 'SALDO',
                valor: fmtMoneda(deuda.saldo.toDouble()),
                color: _kRed,
              ),
              const SizedBox(width: 12),
              _InfoItem(
                label: 'TOTAL',
                valor: fmtMoneda(deuda.montoTotal.toDouble()),
              ),
              if (deuda.fechaVencimiento != null) ...[
                const SizedBox(width: 12),
                _InfoItem(
                  label: 'VENCE',
                  valor: deuda.fechaVencimiento!,
                  color: deuda.estaVencida ? _kRed : ColoresApp.textMedium,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // ── Barra de progreso ────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: porcentaje,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(
                  porcentaje >= 1.0 ? _kGreen : _kBlue),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(porcentaje * 100).toStringAsFixed(0)}% pagado',
            style: const TextStyle(
              fontSize: 10,
              color: ColoresApp.textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  static String _etiquetaEstado(EstadoDeudor estado) => switch (estado) {
        EstadoDeudor.activa     => 'Activa',
        EstadoDeudor.pagada     => 'Pagada',
        EstadoDeudor.vencida    => 'Vencida',
        EstadoDeudor.incobrable => 'Incobrable',
      };
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.label, required this.valor, this.color});
  final String label;
  final String valor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: ColoresApp.textLight,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          valor,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color ?? ColoresApp.textDark,
          ),
        ),
      ],
    );
  }
}

// ── Diálogo detalle de deuda ──────────────────────────────────────────────────

class _DialogoDeudaDetalle extends StatelessWidget {
  const _DialogoDeudaDetalle({required this.deuda});
  final DeudorResumen deuda;

  static const _estadoColor = {
    EstadoDeudor.activa:      Color(0xFF3B82F6),
    EstadoDeudor.pagada:      Color(0xFF10B981),
    EstadoDeudor.vencida:     Color(0xFFEF4444),
    EstadoDeudor.incobrable:  Color(0xFF6B7280),
  };

  @override
  Widget build(BuildContext context) {
    final color      = _estadoColor[deuda.estado] ?? ColoresApp.textMedium;
    final porcentaje = deuda.porcentajePagado;

    return Dialog(
      backgroundColor: ColoresApp.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Encabezado ────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                        Icons.account_balance_wallet_outlined,
                        color: color,
                        size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deuda.numero,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                        Text(
                          deuda.nombreCliente,
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: ColoresApp.textMedium),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _etiquetaEstado(deuda.estado),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Datos ────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: ColoresApp.bgContent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ColoresApp.border),
                ),
                child: Column(
                  children: [
                    _FilaDetalle(
                        label: 'Concepto', valor: deuda.concepto),
                    const Divider(height: 1, color: ColoresApp.border),
                    _FilaDetalle(
                      label: 'Total deuda',
                      valor: fmtMoneda(deuda.montoTotal.toDouble()),
                    ),
                    const Divider(height: 1, color: ColoresApp.border),
                    _FilaDetalle(
                      label: 'Pagado',
                      valor: fmtMoneda(deuda.montoPagado.toDouble()),
                      valorColor: _kGreen,
                    ),
                    const Divider(height: 1, color: ColoresApp.border),
                    _FilaDetalle(
                      label: 'Saldo pendiente',
                      valor: fmtMoneda(deuda.saldo.toDouble()),
                      valorBold: true,
                      valorColor: deuda.saldo > 0 ? _kRed : _kGreen,
                      fondo: deuda.saldo > 0
                          ? _kRed.withValues(alpha: 0.04)
                          : _kGreen.withValues(alpha: 0.04),
                    ),
                    if (deuda.fechaVencimiento != null) ...[
                      const Divider(height: 1, color: ColoresApp.border),
                      _FilaDetalle(
                        label: 'Vencimiento',
                        valor: deuda.fechaVencimiento!,
                        valorColor:
                            deuda.estaVencida ? _kRed : ColoresApp.textDark,
                      ),
                    ],
                    if (deuda.notas != null) ...[
                      const Divider(height: 1, color: ColoresApp.border),
                      _FilaDetalle(label: 'Notas', valor: deuda.notas!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Barra de progreso ────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'PROGRESO DE PAGO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: ColoresApp.textLight,
                        ),
                      ),
                      Text(
                        '${(porcentaje * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: porcentaje >= 1.0 ? _kGreen : _kBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: porcentaje,
                      backgroundColor: ColoresApp.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          porcentaje >= 1.0 ? _kGreen : _kBlue),
                      minHeight: 7,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Nota ────────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: _kBlue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: _kBlue.withValues(alpha: 0.15)),
                ),
                child: const Text(
                  'Para registrar pagos o gestionar esta deuda, ve al módulo de Deudores.',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: _kBlue,
                      fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 20),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: _kBlue,
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _etiquetaEstado(EstadoDeudor estado) => switch (estado) {
        EstadoDeudor.activa     => 'Activa',
        EstadoDeudor.pagada     => 'Pagada',
        EstadoDeudor.vencida    => 'Vencida',
        EstadoDeudor.incobrable => 'Incobrable',
      };
}

class _FilaDetalle extends StatelessWidget {
  const _FilaDetalle({
    required this.label,
    required this.valor,
    this.valorColor,
    this.valorBold = false,
    this.fondo,
  });

  final String label;
  final String valor;
  final Color? valorColor;
  final bool   valorBold;
  final Color? fondo;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: fondo,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12.5, color: ColoresApp.textMedium)),
          const Spacer(),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    valorBold ? FontWeight.w700 : FontWeight.w500,
                color: valorColor ?? ColoresApp.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets auxiliares del panel ──────────────────────────────────────────────

class _Item {
  const _Item(this.label, this.valor);
  final String label;
  final double valor;
}

class _ResumenBloque extends StatelessWidget {
  const _ResumenBloque({required this.titulo, required this.items});
  final String      titulo;
  final List<_Item> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ColoresApp.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: ColoresApp.textLight,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      i.label,
                      style: const TextStyle(
                          fontSize: 12.5, color: ColoresApp.textMedium),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    fmtMoneda(i.valor),
                    style: const TextStyle(
                        fontSize: 12.5, color: ColoresApp.textDark),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaTotal extends StatelessWidget {
  const _FilaTotal(this.etiqueta, this.valor, this.esTotal, {this.color});
  final String etiqueta;
  final double valor;
  final bool   esTotal;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final valorColor = color ??
        (esTotal ? ColoresApp.primary : ColoresApp.textDark);
    return Row(
      children: [
        Expanded(
          child: Text(
            etiqueta,
            style: TextStyle(
              fontSize: esTotal ? 14 : 12.5,
              fontWeight: esTotal ? FontWeight.w700 : FontWeight.w500,
              color:
                  esTotal ? ColoresApp.textDark : ColoresApp.textMedium,
            ),
          ),
        ),
        Text(
          fmtMoneda(valor),
          style: TextStyle(
            fontSize: esTotal ? 16 : 13,
            fontWeight: FontWeight.w700,
            color: valorColor,
          ),
        ),
      ],
    );
  }
}
