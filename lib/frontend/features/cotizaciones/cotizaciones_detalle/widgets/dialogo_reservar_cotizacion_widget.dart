import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/core/currency_ext.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';
import 'package:inventario_k1/frontend/share/widgets/output/snack_bar_mensaje.dart';

import '../../../../../backend/features/cotizaciones/modelo/cotizacion_resumen.dart';
import '../../../../../backend/features/reservas/enum/enum_reserva.dart';
import '../../../../../backend/features/reservas/repositorio/repositorio_reservas.dart';
import '../provider/cotizar_a_reserva_provider.dart';

/// Diálogo que recolecta los únicos datos faltantes para crear la reserva
/// (fecha límite y abono inicial opcional) y delega al [CotizarAReservaUseCase].
class DialogoReservarCotizacion extends ConsumerStatefulWidget {
  const DialogoReservarCotizacion._({
    required this.cotizacion,
    required this.items,
    required this.totalReserva,
  });

  final CotizacionResumen cotizacion;
  final List<ItemReservaDraft> items;
  final int totalReserva;

  /// Muestra el diálogo y devuelve `true` si la reserva fue creada.
  static Future<bool> mostrar(
    BuildContext context, {
    required CotizacionResumen cotizacion,
    required List<ItemReservaDraft> items,
    required int totalReserva,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoReservarCotizacion._(
        cotizacion: cotizacion,
        items: items,
        totalReserva: totalReserva,
      ),
    );
    return result == true;
  }

  @override
  ConsumerState<DialogoReservarCotizacion> createState() =>
      _DialogoReservarCotizacionState();
}

class _DialogoReservarCotizacionState
    extends ConsumerState<DialogoReservarCotizacion> {
  late final TextEditingController _fechaCtrl;
  final _abonoCtrl = TextEditingController();
  String _metodoPago = kMetodosPago.first;
  bool _creando = false;

  @override
  void initState() {
    super.initState();
    _fechaCtrl =
        TextEditingController(text: widget.cotizacion.vigenciaHasta);
  }

  @override
  void dispose() {
    _fechaCtrl.dispose();
    _abonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final ahora = DateTime.now();
    final parsed = DateTime.tryParse(_fechaCtrl.text);
    final inicial = (parsed != null && !parsed.isBefore(ahora))
        ? parsed
        : ahora.add(const Duration(days: 30));

    final picked = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: ahora,
      lastDate: ahora.add(const Duration(days: 365 * 3)),
    );
    if (picked != null && mounted) {
      _fechaCtrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _confirmar() async {
    if (_fechaCtrl.text.isEmpty) {
      SnackBarMensaje.error(context, 'Selecciona una fecha límite.');
      return;
    }
    final abono =
        int.tryParse(_abonoCtrl.text.replaceAll('.', '')) ?? 0;
    if (abono > widget.totalReserva) {
      SnackBarMensaje.error(
        context,
        'El abono inicial no puede superar el total.',
      );
      return;
    }

    setState(() => _creando = true);
    final error = await ref.read(cotizarAReservaProvider).ejecutar(
          clienteId: widget.cotizacion.clienteId!,
          motoId: widget.cotizacion.motoId,
          cotizacionId: widget.cotizacion.id,
          totalReserva: widget.totalReserva,
          items: widget.items,
          fechaLimite: _fechaCtrl.text,
          abonoInicial: abono,
          metodoPago: _metodoPago,
        );

    if (!mounted) return;
    setState(() => _creando = false);

    if (error != null) {
      SnackBarMensaje.error(context, error);
    } else {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      title: _Titulo(numero: widget.cotizacion.numero),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ResumenCotizacion(
              cotizacion: widget.cotizacion,
              cantItems: widget.items.length,
              totalReserva: widget.totalReserva,
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: ColoresApp.border),
            const SizedBox(height: 16),
            _CampoFecha(
              controller: _fechaCtrl,
              onTap: _seleccionarFecha,
            ),
            const SizedBox(height: 12),
            _FilaAbonoMetodo(
              abonoCtrl: _abonoCtrl,
              metodoPago: _metodoPago,
              onMetodoCambio: (v) => setState(() => _metodoPago = v!),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _creando ? null : () => Navigator.pop(context, false),
          style: OutlinedButton.styleFrom(
            foregroundColor: ColoresApp.textMedium,
            side: const BorderSide(color: ColoresApp.border),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _creando ? null : _confirmar,
          icon: _creando
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.bookmark_add_outlined, size: 16),
          label: const Text('Crear reserva'),
          style: ElevatedButton.styleFrom(
            backgroundColor: ColoresApp.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

// ── Sub-widgets del diálogo ───────────────────────────────────────────────────

class _Titulo extends StatelessWidget {
  const _Titulo({required this.numero});

  final String numero;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Crear reserva',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: ColoresApp.textDark,
          ),
        ),
        Text(
          'desde cotización $numero',
          style: const TextStyle(fontSize: 12, color: ColoresApp.textMedium),
        ),
      ],
    );
  }
}

class _ResumenCotizacion extends StatelessWidget {
  const _ResumenCotizacion({
    required this.cotizacion,
    required this.cantItems,
    required this.totalReserva,
  });

  final CotizacionResumen cotizacion;
  final int cantItems;
  final int totalReserva;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColoresApp.bgContent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilaResumen(
            icono: Icons.person_outline_rounded,
            texto: cotizacion.nombreCliente,
          ),
          if (cotizacion.nombreMoto.isNotEmpty) ...[
            const SizedBox(height: 6),
            _FilaResumen(
              icono: Icons.two_wheeler_rounded,
              texto: cotizacion.nombreMoto,
            ),
          ],
          const SizedBox(height: 6),
          _FilaResumen(
            icono: Icons.inventory_2_outlined,
            texto:
                '$cantItems producto${cantItems == 1 ? '' : 's'} para reservar',
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: ColoresApp.border),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total a reservar',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.textDark,
                ),
              ),
              Text(
                totalReserva.toCopString(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: ColoresApp.primary,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilaResumen extends StatelessWidget {
  const _FilaResumen({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 14, color: ColoresApp.textMedium),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
                fontSize: 12.5, color: ColoresApp.textMedium),
          ),
        ),
      ],
    );
  }
}

class _CampoFecha extends StatelessWidget {
  const _CampoFecha({required this.controller, required this.onTap});

  final TextEditingController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _CampoLabel(
      label: 'FECHA LÍMITE DE RESERVA *',
      child: TextField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        style: const TextStyle(fontSize: 13, color: ColoresApp.textDark),
        decoration: _decor(
          hint: 'YYYY-MM-DD',
          suffix: const Icon(
            Icons.calendar_today_outlined,
            size: 16,
            color: ColoresApp.textMedium,
          ),
        ),
      ),
    );
  }
}

class _FilaAbonoMetodo extends StatelessWidget {
  const _FilaAbonoMetodo({
    required this.abonoCtrl,
    required this.metodoPago,
    required this.onMetodoCambio,
  });

  final TextEditingController abonoCtrl;
  final String metodoPago;
  final ValueChanged<String?> onMetodoCambio;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _CampoLabel(
            label: 'ABONO INICIAL (OPC.)',
            child: TextField(
              controller: abonoCtrl,
              keyboardType: TextInputType.number,
              style:
                  const TextStyle(fontSize: 13, color: ColoresApp.textDark),
              decoration: _decor(hint: '0'),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _CampoLabel(
            label: 'MÉTODO DE PAGO',
            child: DropdownButtonFormField<String>(
              initialValue: metodoPago,
              onChanged: onMetodoCambio,
              style:
                  const TextStyle(fontSize: 13, color: ColoresApp.textDark),
              decoration: _decor(),
              items: kMetodosPago
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _CampoLabel extends StatelessWidget {
  const _CampoLabel({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: ColoresApp.textMedium,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 5),
        child,
      ],
    );
  }
}

InputDecoration _decor({String? hint, Widget? suffix}) => InputDecoration(
      hintText: hint,
      hintStyle:
          const TextStyle(color: ColoresApp.textLight, fontSize: 13),
      suffixIcon: suffix,
      filled: true,
      fillColor: ColoresApp.bgContent,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: ColoresApp.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: ColoresApp.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            const BorderSide(color: ColoresApp.primary, width: 1.5),
      ),
    );
