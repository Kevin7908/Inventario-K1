import 'package:flutter/material.dart';

import '../../../../../../backend/features/motos/modelo/moto.dart';
import '../../../../../../frontend/share/temas/colores_app.dart';
import '../../../../../../frontend/share/widgets/input/app_searc_widget.dart';
import '../../widgets/dialogo/dialogo_cot_form_fields.dart';

/// Sección de formulario: moto de interés, cliente (auto), teléfono (auto),
/// vigencia y notas internas.
class SeccionDatosClienteWidget extends StatelessWidget {
  const SeccionDatosClienteWidget({
    super.key,
    required this.motoNotifier,
    required this.motos,
    required this.vigenciaCtrl,
    required this.notasCtrl,
    required this.nombreCliente,
    required this.telefono,
    required this.onMotoSeleccionada,
    required this.onAbrirFecha,
    required this.onAgregarMoto,
  });

  final ValueNotifier<Moto?> motoNotifier;
  final List<Moto> motos;
  final TextEditingController vigenciaCtrl;
  final TextEditingController notasCtrl;
  final String nombreCliente;
  final String telefono;
  final ValueChanged<Moto?> onMotoSeleccionada;
  final VoidCallback onAbrirFecha;
  final VoidCallback onAgregarMoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ColoresApp.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColoresApp.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CotSeccionLabel(
            icono: Icons.person_outline_rounded,
            label: 'DATOS DEL CLIENTE',
          ),
          const SizedBox(height: 16),

          // ── Moto + Cliente ─────────────────────────────────────
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
                      notifier: motoNotifier,
                      items: motos,
                      labelBuilder: (m) => m.nombreDisplay,
                      hint: 'Buscar moto...',
                      onChanged: onMotoSeleccionada,
                      onAgregar: onAgregarMoto,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CotFieldLabel('CLIENTE (AUTO)'),
                    const SizedBox(height: 6),
                    CotReadOnlyField(
                      valor: nombreCliente.isEmpty
                          ? 'Se llenará al escoger moto'
                          : nombreCliente,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Teléfono + Vigencia ─────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CotFieldLabel('TELÉFONO (AUTO)'),
                    const SizedBox(height: 6),
                    CotReadOnlyField(
                      valor: telefono.isEmpty ? '—' : telefono,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CotFieldLabel('VIGENCIA HASTA *'),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: onAbrirFecha,
                      child: AbsorbPointer(
                        child: TextField(
                          controller: vigenciaCtrl,
                          readOnly: true,
                          style: const TextStyle(
                            color: ColoresApp.textDark,
                            fontSize: 13.5,
                          ),
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
            ],
          ),
          const SizedBox(height: 14),

          // ── Notas internas ─────────────────────────────────────
          const CotFieldLabel('NOTAS INTERNAS'),
          const SizedBox(height: 6),
          TextField(
            controller: notasCtrl,
            maxLines: 3,
            style: const TextStyle(color: ColoresApp.textDark, fontSize: 13.5),
            decoration: cotInputDecoration(
              hint: 'Ej: Cliente solicitó financiamiento...',
            ),
          ),
        ],
      ),
    );
  }
}
