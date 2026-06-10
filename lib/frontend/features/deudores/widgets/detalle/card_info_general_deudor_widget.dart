import 'package:flutter/material.dart';
import 'package:inventario_k1/backend/features/deudores/modelo/deudor_resumen.dart';
import 'package:inventario_k1/core/currency_ext.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

class CardInfoGeneralDeudorWidget extends StatelessWidget {
  const CardInfoGeneralDeudorWidget({super.key, required this.resumen});

  final DeudorResumen resumen;

  @override
  Widget build(BuildContext context) {
    return _CardSeccion(
      titulo: 'Información general',
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GrillaInfo2(
              campos: [
                _InfoField(
                  label: 'Cliente',
                  valor: resumen.nombreCliente,
                ),
                _InfoField(
                  label: 'Concepto',
                  valor: resumen.concepto,
                ),
                _InfoField(
                  label: 'Fecha vencimiento',
                  valor: resumen.fechaVencimiento ?? '—',
                  mono: true,
                  alerta: resumen.estaVencida,
                ),
                _InfoField(
                  label: 'Venta vinculada',
                  valor: resumen.ventaId != null
                      ? 'FAC-${resumen.ventaId.toString().padLeft(4, '0')}'
                      : 'Sin vínculo',
                  mono: true,
                ),
              ],
            ),
            if (resumen.notas != null && resumen.notas!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _InfoField(
                label: 'Notas',
                valor: '"${resumen.notas}"',
                italic: true,
              ),
            ],
            const SizedBox(height: 14),
            _BarraProgresoDetalle(resumen: resumen),
          ],
        ),
      ),
    );
  }
}

class _GrillaInfo2 extends StatelessWidget {
  const _GrillaInfo2({required this.campos});

  final List<Widget> campos;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < campos.length; i += 2) {
      rows.add(
        Row(
          children: [
            Expanded(child: campos[i]),
            const SizedBox(width: 12),
            Expanded(
              child: i + 1 < campos.length ? campos[i + 1] : const SizedBox(),
            ),
          ],
        ),
      );
      if (i + 2 < campos.length) rows.add(const SizedBox(height: 10));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

class _InfoField extends StatelessWidget {
  const _InfoField({
    required this.label,
    required this.valor,
    this.mono = false,
    this.italic = false,
    this.alerta = false,
  });

  final String label;
  final String valor;
  final bool mono;
  final bool italic;
  final bool alerta;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: ColoresApp.textLight,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          valor,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: alerta ? ColoresApp.statusPending : ColoresApp.textDark,
            fontFamily: mono ? 'monospace' : null,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ],
    );
  }
}

class _BarraProgresoDetalle extends StatelessWidget {
  const _BarraProgresoDetalle({required this.resumen});

  final DeudorResumen resumen;

  Color get _colorBarra {
    if (resumen.porcentajePagado >= 1.0) return ColoresApp.statusPaid;
    if (resumen.estaVencida) return ColoresApp.statusPending;
    return ColoresApp.primary;
  }

  @override
  Widget build(BuildContext context) {
    final pct = resumen.porcentajePagado;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: ColoresApp.border,
            valueColor: AlwaysStoppedAnimation<Color>(_colorBarra),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${resumen.montoPagado.toCopString()} pagado',
              style: const TextStyle(
                fontSize: 10.5,
                color: ColoresApp.textMedium,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              '${(pct * 100).toStringAsFixed(0)}% · ${resumen.montoTotal.toCopString()} total',
              style: const TextStyle(
                fontSize: 10.5,
                color: ColoresApp.textMedium,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Widget compartido de sección ───────────────────────────────────────────────

class _CardSeccion extends StatelessWidget {
  const _CardSeccion({required this.titulo, required this.child, this.trailing});

  final String titulo;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColoresApp.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColoresApp.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: const BoxDecoration(
              color: ColoresApp.primaryLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Text(
                  titulo.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.primaryDark,
                    letterSpacing: 0.8,
                  ),
                ),
                if (trailing != null) ...[
                  const Spacer(),
                  trailing!,
                ],
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// Exportamos para que otros widgets de detalle lo usen
class CardSeccionDeudor extends StatelessWidget {
  const CardSeccionDeudor({
    super.key,
    required this.titulo,
    required this.child,
    this.trailing,
  });

  final String titulo;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) =>
      _CardSeccion(titulo: titulo, trailing: trailing, child: child);
}
