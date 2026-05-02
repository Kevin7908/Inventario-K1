import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/features/autenticacion/vista/registro/crear_password.dart';
import 'package:inventario_k1/frontend/features/autenticacion/vista/registro/paso_datos_iniciales.dart';
import 'package:inventario_k1/frontend/features/autenticacion/vista/registro/verificacion_otp.dart';
import 'package:provider/provider.dart';

import '../../../../share/temas/colores_app.dart';
import '../../view_model/registro_view_model.dart';
import 'decoracion_registro.dart';


class TarjetaRegistro extends StatelessWidget {
  final VoidCallback alVolverLogin;

  const TarjetaRegistro({super.key, required this.alVolverLogin});

  @override
  Widget build(BuildContext context) {
    // Leemos sin escuchar (watch) solo para obtener referencia al vm en este
    // nivel. Cada paso tiene su propio Consumer que escucha los cambios.
    final vm = context.watch<RegistroViewModel>();

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: ColoresApp.bgCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EncabezadoRegistro(vm: vm, alVolverLogin: alVolverLogin),
            const SizedBox(height: 8),
            IndicadorPasos(pasoActual: vm.paso),
            const SizedBox(height: 28),
            _ContenidoPaso(paso: vm.paso),
          ],
        ),
      ),
    );
  }
}

/// Widget dedicado solo al AnimatedSwitcher de pasos.
/// Separarlo evita que la decoración de la tarjeta se reconstruya
/// en cada transición de paso.
class _ContenidoPaso extends StatelessWidget {
  final PasoRegistro paso;

  const _ContenidoPaso({required this.paso});

  // Mapa paso → widget con key estable para que AnimatedSwitcher detecte el cambio.
  static Widget _buildPaso(PasoRegistro paso) => switch (paso) {
        PasoRegistro.datosIniciales =>
          const PasoDatosIniciales(key: ValueKey('paso1')),
        PasoRegistro.verificandoCodigo =>
          const PasoVerificacionOtp(key: ValueKey('paso2')),
        PasoRegistro.creandoPassword =>
          const PasoCrearPassword(key: ValueKey('paso3')),
        _ => const SizedBox.shrink(key: ValueKey('done')),
      };

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: _buildPaso(paso),
    );
  }
}