import 'package:flutter/material.dart';

import '../../../../share/temas/colores_app.dart';
import '../../view_model/registro_view_model.dart';

// ─── Banner de error ──────────────────────────────────────────────────────────

class BannerError extends StatelessWidget {
  final String mensaje;
  const BannerError({super.key, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ColoresApp.statusDebtBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColoresApp.statusDebt),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: ColoresApp.statusDebt),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(fontSize: 13, color: Color(0xFF991B1B)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Encabezado dinámico ──────────────────────────────────────────────────────

class EncabezadoRegistro extends StatelessWidget {
  final RegistroViewModel vm;
  final VoidCallback alVolverLogin;

  const EncabezadoRegistro({
    super.key,
    required this.vm,
    required this.alVolverLogin,
  });

  @override
  Widget build(BuildContext context) {
    final (titulo, subtitulo) = switch (vm.paso) {
      PasoRegistro.verificandoCodigo => (
          'Verifica tu correo',
          'Código enviado a ${vm.emailGuardado}',
        ),
      PasoRegistro.creandoPassword => ('Crea tu contraseña', null),
      _ => ('Crear cuenta', null),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: ColoresApp.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.inventory_2_outlined,
              color: ColoresApp.textWhite, size: 26),
        ),
        const SizedBox(height: 20),
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: ColoresApp.textDark,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        if (subtitulo != null)
          Text(subtitulo,
              style:
                  const TextStyle(fontSize: 13, color: ColoresApp.textMedium))
        else if (vm.paso == PasoRegistro.datosIniciales)
          _LinkIniciarSesion(alVolverLogin: alVolverLogin),
      ],
    );
  }
}

class _LinkIniciarSesion extends StatelessWidget {
  final VoidCallback alVolverLogin;
  const _LinkIniciarSesion({required this.alVolverLogin});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('¿Ya tienes cuenta? ',
            style: TextStyle(fontSize: 14, color: ColoresApp.textMedium)),
        GestureDetector(
          onTap: alVolverLogin,
          child: const Text(
            'Inicia sesión',
            style: TextStyle(
              fontSize: 14,
              color: ColoresApp.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Indicador de 3 pasos ─────────────────────────────────────────────────────

class IndicadorPasos extends StatelessWidget {
  final PasoRegistro pasoActual;
  const IndicadorPasos({super.key, required this.pasoActual});

  int get _indice => switch (pasoActual) {
        PasoRegistro.datosIniciales => 0,
        PasoRegistro.verificandoCodigo => 1,
        PasoRegistro.creandoPassword => 2,
        _ => 2,
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final activo = i == _indice;
        final completado = i < _indice;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: completado
                  ? ColoresApp.primary
                  : activo
                      ? ColoresApp.primary.withOpacity(0.4)
                      : ColoresApp.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}