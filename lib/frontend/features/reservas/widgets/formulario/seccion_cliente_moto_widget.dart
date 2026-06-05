import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/backend/features/motos/modelo/moto.dart';
import 'package:inventario_k1/frontend/features/motos/widgets/dialogo_motos.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';
import 'package:inventario_k1/frontend/share/widgets/input/app_searc_widget.dart';

import '../../provider/reservas_provider.dart';
import '../../reserva_editor/provider/reserva_editor_provider.dart';

class SeccionClienteMotoWidget extends ConsumerWidget {
  const SeccionClienteMotoWidget({
    super.key,
    required this.motoNotifier,
  });

  final ValueNotifier<Moto?> motoNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motos = ref.watch(motosParaReservaProvider).value ?? const [];
    final estado = ref.watch(reservaEditorProvider);

    return Container(
      decoration: BoxDecoration(
        color: ColoresApp.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CabeceraTarjeta(esEdicion: estado.esEdicion),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _LabeledField(
                        label: 'Moto *',
                        child: AppSearch<Moto>(
                          notifier: motoNotifier,
                          items: motos,
                          labelBuilder: (m) => m.nombreDisplay,
                          hint: 'Buscar moto…',
                          onAgregar: () async {
                            await DialogoMoto.mostrar(context);
                            ref.invalidate(motosParaReservaProvider);
                          },
                          onChanged: (moto) {
                            if (moto != null) {
                              ref
                                  .read(reservaEditorProvider.notifier)
                                  .seleccionarMoto(moto);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoAutorellenada(
                        label: 'Cliente (auto)',
                        valor: estado.moto?.nombreCliente ?? '—',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _LabeledField(
                        label: 'Fecha límite *',
                        child: _SelectorFecha(
                          fechaActual: estado.fechaLimite,
                          onFechaCambiada: (f) => ref
                              .read(reservaEditorProvider.notifier)
                              .cambiarFecha(f),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _PlaceholderFecha(moto: estado.moto)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CabeceraTarjeta extends StatelessWidget {
  const _CabeceraTarjeta({required this.esEdicion});

  final bool esEdicion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: ColoresApp.bgContent,
        borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
        border: Border(bottom: BorderSide(color: ColoresApp.border)),
      ),
      child: Text(
        esEdicion ? 'EDITAR DATOS' : 'DATOS DEL CLIENTE',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: ColoresApp.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _InfoAutorellenada extends StatelessWidget {
  const _InfoAutorellenada({required this.label, required this.valor});

  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: ColoresApp.textMedium,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: ColoresApp.bgContent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ColoresApp.border),
          ),
          child: Text(
            valor,
            style: const TextStyle(
              fontSize: 13.5,
              color: ColoresApp.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _PlaceholderFecha extends StatelessWidget {
  const _PlaceholderFecha({this.moto});

  final Moto? moto;

  @override
  Widget build(BuildContext context) {
    if (moto == null) {
      return const _InfoAutorellenada(
        label: 'Placa moto',
        valor: '—',
      );
    }
    return _InfoAutorellenada(
      label: 'Placa moto',
      valor: moto!.placa ?? '—',
    );
  }
}

class _SelectorFecha extends StatelessWidget {
  const _SelectorFecha({
    required this.fechaActual,
    required this.onFechaCambiada,
  });

  final String fechaActual;
  final ValueChanged<String> onFechaCambiada;

  Future<void> _abrirPicker(BuildContext context) async {
    final ahora = DateTime.now();
    final inicial = DateTime.tryParse(fechaActual) ?? ahora.add(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: ahora,
      lastDate: ahora.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      onFechaCambiada(
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _abrirPicker(context),
      child: AbsorbPointer(
        child: TextFormField(
          readOnly: true,
          decoration: InputDecoration(
            hintText: fechaActual.isEmpty ? 'Seleccionar fecha…' : fechaActual,
            hintStyle: TextStyle(
              color: fechaActual.isEmpty ? ColoresApp.textLight : ColoresApp.textDark,
              fontSize: 13.5,
            ),
            filled: true,
            fillColor: ColoresApp.bgContent,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            suffixIcon: const Icon(Icons.calendar_today_outlined,
                size: 18, color: ColoresApp.textLight),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: ColoresApp.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: ColoresApp.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: ColoresApp.primary, width: 1.5),
            ),
          ),
          controller: TextEditingController(text: fechaActual),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: ColoresApp.textMedium,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}
