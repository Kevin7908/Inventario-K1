import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/especializacion/modelo/especializacion.dart';
import '../../../../backend/features/persona/repositorio/repositorio_persona.dart';
import '../../../../backend/features/tecnicos/modelo/tecnico.dart';
import '../../../../core/resultado.dart';
import '../../../share2/share2.dart';
import '../../especializacion/provider/especializacion_provider.dart';
import '../../persona/provider/persona_provider.dart';
import '../../persona/widgets/confirmar_persona_existente.dart';
import '../provider/tecnico_provider.dart';

/// Formulario de alta y edición de un técnico.
///
/// Es el **único** sitio donde vive el formulario. Sigue el patrón de
/// `FormularioProveedor`: la página que lo hospeda solo pone el marco y este
/// widget resuelve campos, validación y guardado. También lo reutiliza
/// [DialogoTecnico] para el alta rápida que abren cotizaciones, facturas y
/// órdenes sin salir de su pantalla.
///
/// Parámetros:
/// - [tecnicoAEditar]: técnico a modificar. Si es `null`, crea uno nuevo.
/// - [alTerminar]: se llama tras guardar con éxito, para volver a la lista.
/// - [alCancelar]: se llama al presionar "Cancelar".
class FormularioTecnico extends ConsumerStatefulWidget {
  const FormularioTecnico({
    super.key,
    this.tecnicoAEditar,
    required this.alTerminar,
    required this.alCancelar,
  });

  final Tecnico? tecnicoAEditar;
  final VoidCallback alTerminar;
  final VoidCallback alCancelar;

  bool get esEdicion => tecnicoAEditar != null;

  @override
  ConsumerState<FormularioTecnico> createState() => _FormularioTecnicoState();
}

class _FormularioTecnicoState extends ConsumerState<FormularioTecnico> {
  final _formKey = GlobalKey<FormState>();
  bool _guardando = false;

  late final TextEditingController _nombresCtrl;
  late final TextEditingController _apellidosCtrl;
  late final TextEditingController _cedulaCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _salarioCtrl;

  Especializacion? _especializacion;
  late bool _activo;

  @override
  void initState() {
    super.initState();
    final t = widget.tecnicoAEditar;

    _nombresCtrl = TextEditingController(text: t?.nombres ?? '');
    _apellidosCtrl = TextEditingController(text: t?.apellidos ?? '');
    _cedulaCtrl = TextEditingController(text: t?.documento ?? '');
    _telefonoCtrl = TextEditingController(text: t?.telefono ?? '');
    _emailCtrl = TextEditingController(text: t?.email ?? '');
    _salarioCtrl = TextEditingController(
      text: t?.salarioBase == null ? '' : t!.salarioBase!.toStringAsFixed(0),
    );
    _activo = t?.activo ?? true;

    if (t?.especializacionId != null) {
      // La lista de especializaciones vive en un provider que no está
      // resuelto durante `initState`. Se preselecciona tras el primer frame,
      // esperando el catálogo en vez de leer su valor actual: al abrir el
      // formulario en frío —el diálogo que abren cotizaciones, facturas u
      // órdenes— el stream todavía no ha emitido.
      WidgetsBinding.instance.addPostFrameCallback((_) => _preseleccionarFk(t!));
    }
  }

  Future<void> _preseleccionarFk(Tecnico t) async {
    final lista = await ref.read(especializacionesProvider.future);
    if (!mounted) return;
    setState(() {
      _especializacion =
          lista.where((e) => e.id == t.especializacionId).firstOrNull;
    });
  }

  @override
  void dispose() {
    _nombresCtrl.dispose();
    _apellidosCtrl.dispose();
    _cedulaCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _salarioCtrl.dispose();
    super.dispose();
  }

  /// Texto vacío = campo sin dato. Guardar `''` en vez de `NULL` haría que la
  /// tarjeta pintara una línea de contacto en blanco.
  String? _opcional(TextEditingController c) {
    final texto = c.text.trim();
    return texto.isEmpty ? null : texto;
  }

  void _mostrarMensaje(String texto, {required bool esError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          texto,
          style: TipografiaApp.sobrePrimario(TipografiaApp.cuerpo),
        ),
        backgroundColor:
            esError ? ColoresApp.statusDanger : ColoresApp.statusSuccess,
      ),
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (!await _confirmarReutilizacion()) return;

    setState(() => _guardando = true);

    final tecnico = Tecnico(
      id: widget.tecnicoAEditar?.id,
      personaId: widget.tecnicoAEditar?.personaId,
      documento: _opcional(_cedulaCtrl),
      nombres: _nombresCtrl.text.trim(),
      apellidos: _opcional(_apellidosCtrl),
      telefono: _opcional(_telefonoCtrl),
      email: _opcional(_emailCtrl),
      especializacionId: _especializacion?.id,
      salarioBase: _salarioCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_salarioCtrl.text.trim()),
      activo: _activo,
      creadoEn: widget.tecnicoAEditar?.creadoEn ?? DateTime.now(),
    );

    final notifier = ref.read(tecnicosProvider.notifier);
    final resultado = widget.esEdicion
        ? await notifier.actualizar(tecnico)
        : await notifier.crear(tecnico);

    if (!mounted) return;

    if (resultado case Fallo(:final mensaje)) {
      _mostrarMensaje(mensaje, esError: true);
      setState(() => _guardando = false);
      return;
    }

    _mostrarMensaje(
      widget.esEdicion
          ? 'Técnico actualizado correctamente.'
          : 'Técnico creado correctamente.',
      esError: false,
    );
    widget.alTerminar();
  }

  /// Avisa si la cédula tecleada ya pertenece a alguien registrado con otro
  /// rol, antes de que el repositorio reutilice —y sobrescriba— su ficha.
  ///
  /// Solo se pregunta al crear: al editar, la persona ya es la del técnico.
  Future<bool> _confirmarReutilizacion() async {
    final documento = _opcional(_cedulaCtrl);
    if (documento == null || widget.esEdicion) return true;

    final existente = await ref
        .read(repositorioPersonaProvider)
        .buscarPorDocumento(documento);
    if (!mounted) return false;

    return confirmarPersonaExistente(
      context,
      existente: existente,
      rolNuevo: RolPersona.tecnico,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AtajosFormulario(
      alGuardar: _guardando ? null : _guardar,
      alCancelar: _guardando ? null : widget.alCancelar,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bloqueIdentificacion(),
            const SizedBox(height: 20),
            _bloqueContacto(),
            const SizedBox(height: 20),
            _bloqueLaboral(),
            const SizedBox(height: 24),
            _acciones(),
          ],
        ),
      ),
    );
  }

  Widget _bloqueIdentificacion() {
    return PanelSeccion(
      titulo: 'Identificación',
      icono: Icons.badge_outlined,
      child: FilaCampos(
        pesos: const [2, 2, 1],
        hijos: [
          CampoTexto(
            etiqueta: 'Nombres *',
            controlador: _nombresCtrl,
            placeholder: 'Ej: Carlos Andrés',
            autofocus: true,
            validador: (v) {
              final texto = v?.trim() ?? '';
              if (texto.isEmpty) return 'El nombre es obligatorio.';
              if (texto.length < 2) return 'Mínimo 2 caracteres.';
              return null;
            },
          ),
          CampoTexto(
            etiqueta: 'Apellidos',
            controlador: _apellidosCtrl,
            placeholder: 'Ej: Méndez Ruiz',
          ),
          CampoTexto(
            etiqueta: 'Cédula',
            controlador: _cedulaCtrl,
            placeholder: 'Ej: 1020304050',
            monoespaciado: true,
          ),
        ],
      ),
    );
  }

  Widget _bloqueContacto() {
    return PanelSeccion(
      titulo: 'Contacto',
      icono: Icons.call_outlined,
      child: FilaCampos(
        hijos: [
          CampoTexto(
            etiqueta: 'Teléfono',
            controlador: _telefonoCtrl,
            placeholder: 'Ej: 3001234567',
          ),
          CampoTexto(
            etiqueta: 'Correo electrónico',
            controlador: _emailCtrl,
            placeholder: 'Ej: tecnico@taller.com',
            validador: (v) {
              final texto = v?.trim() ?? '';
              if (texto.isEmpty) return null;
              final valido = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
              return valido.hasMatch(texto)
                  ? null
                  : 'Correo con formato inválido.';
            },
          ),
        ],
      ),
    );
  }

  Widget _bloqueLaboral() {
    final especializaciones = ref.watch(especializacionesProvider).value ??
        const <Especializacion>[];

    return PanelSeccion(
      titulo: 'Datos laborales',
      icono: Icons.work_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilaCampos(
            hijos: [
              SelectorWidget<Especializacion?>(
                etiqueta: 'Especialización',
                valor: _especializacion,
                opciones: <Especializacion?>[null, ...especializaciones],
                constructorEtiqueta: (e) => e?.nombre ?? 'Sin especialización',
                alCambiar: (e) => setState(() => _especializacion = e),
              ),
              CampoTexto(
                etiqueta: 'Salario base',
                controlador: _salarioCtrl,
                placeholder: 'Ej: 1800000',
                validador: (v) {
                  final texto = v?.trim() ?? '';
                  if (texto.isEmpty) return null;
                  final valor = double.tryParse(texto);
                  if (valor == null || valor < 0) {
                    return 'Ingresa un número válido.';
                  }
                  return null;
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          InterruptorCampo(
            etiqueta: 'Técnico activo',
            detalle: _activo
                ? 'Sigue trabajando en el taller'
                : 'Ya no trabaja aquí, pero se conserva su historial',
            valor: _activo,
            alCambiar: (v) => setState(() => _activo = v),
          ),
        ],
      ),
    );
  }

  Widget _acciones() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        BotonSecundario(
          etiqueta: 'Cancelar',
          alPresionar: _guardando ? null : widget.alCancelar,
        ),
        const SizedBox(width: 12),
        BotonPrimario(
          etiqueta: _guardando
              ? 'Guardando...'
              : widget.esEdicion
                  ? 'Guardar cambios'
                  : 'Crear técnico',
          icono: Icons.check,
          alPresionar: _guardando ? null : _guardar,
        ),
      ],
    );
  }
}
