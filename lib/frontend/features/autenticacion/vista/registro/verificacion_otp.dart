import 'dart:async';

import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/features/autenticacion/vista/registro/decoracion_registro.dart';
import 'package:provider/provider.dart';

import '../../../../share/temas/colores_app.dart';
import '../../../../share/widgets/botones/boton_cargando_widget.dart';
import '../../view_model/registro_view_model.dart';
import 'caja_otp.dart';

class PasoVerificacionOtp extends StatefulWidget {
  const PasoVerificacionOtp({super.key});

  @override
  State<PasoVerificacionOtp> createState() => _PasoVerificacionOtpState();
}

class _PasoVerificacionOtpState extends State<PasoVerificacionOtp> {
  static const _len = 6;

  final _ctrls = List.generate(_len, (_) => TextEditingController());
  final _focus = List.generate(_len, (_) => FocusNode());

  Timer? _timer;
  // _secs vive en el State local: no necesita Provider ni setState del padre.
  int _secs = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus[0].requestFocus();
      _secs = context.read<RegistroViewModel>().segundosRestantes;
      _startTimer();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secs = (_secs - 1).clamp(0, 600));
      if (_secs == 0) _timer?.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrls) c.dispose();
    for (final f in _focus) f.dispose();
    super.dispose();
  }

  String get _codigo => _ctrls.map((c) => c.text).join();
  bool get _lleno => _codigo.length == _len;

  Future<void> _verificar() async {
    if (!_lleno) return;
    await context.read<RegistroViewModel>().verificarCodigo(_codigo);
  }

  Future<void> _reenviar() async {
    await context.read<RegistroViewModel>().reenviarCodigo();
    for (final c in _ctrls) c.clear();
    if (!mounted) return;
    _focus[0].requestFocus();
    _secs = context.read<RegistroViewModel>().segundosRestantes;
    _startTimer();
  }

  void _onChanged(int idx, String val) {
    // Soporte para pegar los 6 dígitos de una vez.
    if (val.length == _len) {
      for (int i = 0; i < _len; i++) _ctrls[i].text = val[i];
      _focus[_len - 1].requestFocus();
      _verificar();
      return;
    }
    if (val.isNotEmpty) {
      _ctrls[idx].text = val.characters.last;
      if (idx < _len - 1) {
        _focus[idx + 1].requestFocus();
      } else {
        _verificar(); // último dígito → verificar automáticamente
      }
    }
  }

  void _onBackspace(int idx) {
    if (_ctrls[idx].text.isNotEmpty) {
      _ctrls[idx].clear();
    } else if (idx > 0) {
      _ctrls[idx - 1].clear();
      _focus[idx - 1].requestFocus();
    }
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    // Consumer acotado: solo reconstruye este paso ante cambios del VM.
    return Consumer<RegistroViewModel>(
      builder: (_, vm, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 6 cajitas OTP ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              _len,
              (i) => CajaOtp(
                // Keys estables para que Flutter no descarte los TextEditingControllers
                // durante reconstrucciones internas del Column.
                key: ValueKey('otp_$i'),
                controller: _ctrls[i],
                focusNode: _focus[i],
                onChanged: (v) => _onChanged(i, v),
                onBackspace: () => _onBackspace(i),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Contador + Reenviar ──
          Row(
            children: [
              Icon(
                _secs > 0 ? Icons.timer_outlined : Icons.timer_off_outlined,
                size: 14,
                color:
                    _secs > 0 ? ColoresApp.textMedium : ColoresApp.statusDebt,
              ),
              const SizedBox(width: 6),
              Text(
                _secs > 0
                    ? 'Expira en ${_fmt(_secs)}'
                    : 'Código expirado',
                style: TextStyle(
                  fontSize: 12,
                  color: _secs > 0
                      ? ColoresApp.textMedium
                      : ColoresApp.statusDebt,
                ),
              ),
              const Spacer(),
              if (!vm.estaCargando)
                GestureDetector(
                  onTap: _reenviar,
                  child: const Text(
                    'Reenviar código',
                    style: TextStyle(
                      fontSize: 12,
                      color: ColoresApp.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),

          if (vm.intentosRestantes < 3 && vm.intentosRestantes > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${vm.intentosRestantes} intento${vm.intentosRestantes == 1 ? '' : 's'} '
              'restante${vm.intentosRestantes == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 12,
                color: vm.intentosRestantes == 1
                    ? ColoresApp.statusDebt
                    : ColoresApp.statusPending,
              ),
            ),
          ],

          const SizedBox(height: 16),
          if (vm.mensajeError != null) ...[
            BannerError(mensaje: vm.mensajeError!),
            const SizedBox(height: 16),
          ],

          BotonCargando(
            etiqueta: 'Verificar código',
            estaCargando: vm.estaCargando,
            alPresionar: _lleno ? _verificar : null,
            icono: Icons.verified_outlined,
          ),
          const SizedBox(height: 12),

          Center(
            child: TextButton.icon(
              onPressed: vm.estaCargando ? null : vm.volverADatosIniciales,
              icon: const Icon(Icons.arrow_back, size: 14),
              label: const Text('Cambiar correo'),
              style: TextButton.styleFrom(
                foregroundColor: ColoresApp.textMedium,
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}