import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventario_k1/core/currency_ext.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

import 'package:inventario_k1/backend/features/cotizaciones/enum/enum_cotizacion.dart';
import 'package:inventario_k1/backend/features/cotizaciones/repositorio/repositorio_cotizaciones.dart';

// ── Modelo de borrador (solo vive en el diálogo) ──────────────────────────────

class CotItemDraft {
  CotItemDraft({
    required this.tipo,
    this.referenciaId,
    required this.descripcion,
    required this.cantidad,
    required this.precioUnitario,
  });

  final TipoItemCotizacion tipo;
  final int? referenciaId;
  final String descripcion;
  double cantidad;
  int precioUnitario;

  int get subtotal => (cantidad * precioUnitario).round();

  ItemDraft toItemDraft() => ItemDraft(
        tipo: tipo,
        referenciaId: referenciaId,
        descripcion: descripcion,
        cantidad: cantidad,
        precioUnitario: precioUnitario,
      );
}

// ── Encabezado de la tabla de ítems ──────────────────────────────────────────

class CotItemsTablaHeader extends StatelessWidget {
  const CotItemsTablaHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ColoresApp.bgContent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          SizedBox(width: 80, child: _ColHeader('TIPO')),
          Expanded(child: _ColHeader('DESCRIPCIÓN')),
          SizedBox(width: 64, child: _ColHeader('CANT.')),
          SizedBox(width: 100, child: _ColHeader('PRECIO UNIT.')),
          SizedBox(width: 100, child: _ColHeader('SUBTOTAL')),
          SizedBox(width: 32),
        ],
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  const _ColHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: ColoresApp.textLight,
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
  }
}

// ── Fila editable de borrador ─────────────────────────────────────────────────

class CotItemFila extends StatelessWidget {
  const CotItemFila({
    super.key,
    required this.item,
    required this.onEliminar,
    required this.onCantidadChange,
    required this.onPrecioChange,
  });

  final CotItemDraft item;
  final VoidCallback onEliminar;
  final ValueChanged<double> onCantidadChange;
  final ValueChanged<int> onPrecioChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: ColoresApp.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(width: 80, child: CotTipoChip(tipo: item.tipo)),
          Expanded(
            child: Text(
              item.descripcion,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ColoresApp.textDark, fontSize: 13),
            ),
          ),
          SizedBox(
            width: 64,
            child: CotMiniNumField(
              valor: item.cantidad.toInt().toString(),
              onChanged: (v) {
                final n = double.tryParse(v);
                if (n != null) onCantidadChange(n);
              },
            ),
          ),
          SizedBox(
            width: 100,
            child: CotMiniNumField(
              valor: item.precioUnitario.toString(),
              onChanged: (v) {
                final n = int.tryParse(v);
                if (n != null) onPrecioChange(n);
              },
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              item.subtotal.toCopString(),
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: ColoresApp.textDark,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: IconButton(
              icon: const Icon(Icons.close_rounded,
                  size: 16, color: ColoresApp.textLight),
              onPressed: onEliminar,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chip de tipo (PRODUCTO / SERVICIO) ────────────────────────────────────────

class CotTipoChip extends StatelessWidget {
  const CotTipoChip({super.key, required this.tipo});

  final TipoItemCotizacion tipo;

  @override
  Widget build(BuildContext context) {
    final esProducto = tipo == TipoItemCotizacion.producto;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: esProducto
            ? ColoresApp.primaryLight
            : ColoresApp.accentPurple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        esProducto ? 'PRODUC.' : 'SERVIC.',
        style: TextStyle(
          color: esProducto ? ColoresApp.primary : ColoresApp.accentPurple,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Campo numérico compacto ───────────────────────────────────────────────────

class CotMiniNumField extends StatelessWidget {
  const CotMiniNumField({
    super.key,
    required this.valor,
    required this.onChanged,
  });

  final String valor;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: valor,
      onChanged: onChanged,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(color: ColoresApp.textDark, fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: ColoresApp.bgContent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: ColoresApp.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: ColoresApp.primary, width: 1.5),
        ),
      ),
    );
  }
}

// ── Botón para agregar ítem ───────────────────────────────────────────────────

class CotBtnAgregar extends StatelessWidget {
  const CotBtnAgregar({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: ColoresApp.primary.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
          color: ColoresApp.primaryLight,
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: ColoresApp.primary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
