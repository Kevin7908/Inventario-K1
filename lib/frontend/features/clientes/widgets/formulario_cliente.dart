import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../../backend/features/motos/modelo/moto.dart';
import '../../../../backend/features/persona/repositorio/repositorio_persona.dart';
import '../../../../core/resultado.dart';
import '../../../../core/validaciones.dart';
import '../../../share/share.dart';
import '../../motos/provider/motos_provider.dart';
import '../../persona/provider/persona_provider.dart';
import '../../persona/widgets/confirmar_persona_existente.dart';
import '../provider/cliente_provider.dart';
import 'editor_motos_cliente.dart';

/// Formulario de alta y edición de un cliente **y sus motos**.
///
/// Es el **único** sitio donde vive el formulario. Sigue el patrón de
/// `FormularioTecnico`: la página que lo hospeda solo pone el marco y este
/// widget resuelve campos, validación y guardado. También lo reutiliza
/// `DialogoCliente` para el alta rápida que abren deudores, facturas y motos
/// sin salir de su pantalla.
///
/// Parámetros:
/// - [clienteAEditar]: cliente a modificar. Si es `null`, crea uno nuevo.
/// - [alTerminar]: se llama tras guardar con éxito.
/// - [alCancelar]: se llama al presionar "Cancelar".
class FormularioCliente extends ConsumerStatefulWidget {
  const FormularioCliente({
    super.key,
    this.clienteAEditar,
    required this.alTerminar,
    required this.alCancelar,
  });

  final Cliente? clienteAEditar;
  final VoidCallback alTerminar;
  final VoidCallback alCancelar;

  bool get esEdicion => clienteAEditar != null;

  @override
  ConsumerState<FormularioCliente> createState() => _FormularioClienteState();
}

class _FormularioClienteState extends ConsumerState<FormularioCliente> {
  final _formKey = GlobalKey<FormState>();
  bool _guardando = false;

  late final TextEditingController _nombresCtrl;
  late final TextEditingController _apellidosCtrl;
  late final TextEditingController _cedulaCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _ciudadCtrl;
  late final TextEditingController _notasCtrl;

  late bool _activo;

  /// Motos del cliente en edición. Solo se persisten al guardar: mientras
  /// tanto son objetos en memoria, y las nuevas llevan `id == 0`.
  List<Moto> _motos = const [];

  @override
  void initState() {
    super.initState();
    final c = widget.clienteAEditar;

    _nombresCtrl = TextEditingController(text: c?.nombres ?? '');
    _apellidosCtrl = TextEditingController(text: c?.apellidos ?? '');
    _cedulaCtrl = TextEditingController(text: c?.documento ?? '');
    _telefonoCtrl = TextEditingController(text: c?.telefono ?? '');
    _emailCtrl = TextEditingController(text: c?.email ?? '');
    _direccionCtrl = TextEditingController(text: c?.direccion ?? '');
    _ciudadCtrl = TextEditingController(text: c?.ciudad ?? '');
    _notasCtrl = TextEditingController(text: c?.notas ?? '');
    _activo = c?.activo ?? true;

    if (c != null) _cargarMotos(c.id);
  }

  /// Las motos se leen una vez al abrir, no por stream: el formulario es un
  /// borrador y no debe pisar lo que el usuario está editando si otra pantalla
  /// toca la tabla mientras tanto.
  Future<void> _cargarMotos(int clienteId) async {
    final motos =
        await ref.read(repositorioMotosProvider).obtenerPorCliente(clienteId);
    if (!mounted) return;
    setState(() => _motos = motos);
  }

  @override
  void dispose() {
    _nombresCtrl.dispose();
    _apellidosCtrl.dispose();
    _cedulaCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _direccionCtrl.dispose();
    _ciudadCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  /// Texto vacío = campo sin dato. Guardar `''` en vez de `NULL` haría que la
  /// ficha pintara una línea de contacto en blanco, y rompería el índice único
  /// de la cédula en cuanto hubiera dos clientes sin ella.
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

    final previo = widget.clienteAEditar;
    final cliente = Cliente(
      // `id == 0` marca al cliente como nuevo para el repositorio.
      id: previo?.id ?? 0,
      personaId: previo?.personaId,
      documento: _opcional(_cedulaCtrl),
      nombres: _nombresCtrl.text.trim(),
      apellidos: _opcional(_apellidosCtrl),
      telefono: _opcional(_telefonoCtrl),
      email: _opcional(_emailCtrl),
      direccion: _opcional(_direccionCtrl),
      ciudad: _opcional(_ciudadCtrl),
      fechaNacimiento: previo?.fechaNacimiento,
      notas: _opcional(_notasCtrl),
      activo: _activo,
      creadoEn: previo?.creadoEn ?? DateTime.now(),
    );

    final resultado = await ref
        .read(clientesProvider.notifier)
        .guardar(cliente: cliente, motos: _motos);

    if (!mounted) return;

    if (resultado case Fallo(:final mensaje)) {
      _mostrarMensaje(mensaje, esError: true);
      setState(() => _guardando = false);
      return;
    }

    _mostrarMensaje(
      widget.esEdicion
          ? 'Cliente actualizado correctamente.'
          : 'Cliente creado correctamente.',
      esError: false,
    );
    widget.alTerminar();
  }

  /// Avisa si la cédula tecleada ya pertenece a alguien registrado con otro
  /// rol, antes de que el repositorio reutilice —y sobrescriba— su ficha.
  ///
  /// Solo se pregunta al crear: al editar, la persona ya es la del cliente.
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
      rolNuevo: RolPersona.cliente,
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
            EditorMotosCliente(
              motos: _motos,
              alCambiar: (lista) => setState(() => _motos = lista),
            ),
            const SizedBox(height: 20),
            _bloqueNotas(),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilaCampos(
            pesos: const [3, 3, 2],
            hijos: [
              CampoTexto(
                etiqueta: 'Nombres *',
                controlador: _nombresCtrl,
                placeholder: 'Ej: Carlos Andrés',
                autofocus: true,
                validador: (v) => validarObligatorio(v, 'El nombre'),
              ),
              CampoTexto(
                etiqueta: 'Apellidos',
                controlador: _apellidosCtrl,
                placeholder: 'Ej: Ramírez Ruiz',
              ),
              CampoTexto(
                etiqueta: 'Cédula',
                controlador: _cedulaCtrl,
                placeholder: 'Ej: 1020304050',
                monoespaciado: true,
                soloEnteros: true,
                maximoCaracteres: maximoDigitosDocumento,
                validador: validarDocumento,
              ),
            ],
          ),
          const SizedBox(height: 16),
          InterruptorCampo(
            etiqueta: 'Cliente activo',
            detalle: _activo
                ? 'Sigue siendo cliente del taller'
                : 'Ya no viene, pero se conserva su historial',
            valor: _activo,
            alCambiar: (v) => setState(() => _activo = v),
          ),
        ],
      ),
    );
  }

  Widget _bloqueContacto() {
    return PanelSeccion(
      titulo: 'Contacto',
      icono: Icons.call_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilaCampos(
            hijos: [
              CampoTexto(
                etiqueta: 'Teléfono',
                controlador: _telefonoCtrl,
                placeholder: 'Ej: 3001234567',
                monoespaciado: true,
                soloEnteros: true,
                maximoCaracteres: maximoDigitosTelefono,
                validador: validarTelefono,
              ),
              CampoTexto(
                etiqueta: 'Correo electrónico',
                controlador: _emailCtrl,
                placeholder: 'Ej: cliente@correo.com',
                validador: validarEmail,
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilaCampos(
            pesos: const [2, 1],
            hijos: [
              CampoTexto(
                etiqueta: 'Dirección',
                controlador: _direccionCtrl,
                placeholder: 'Ej: Calle 45 # 12-30',
              ),
              CampoTexto(
                etiqueta: 'Ciudad',
                controlador: _ciudadCtrl,
                placeholder: 'Ej: Medellín',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bloqueNotas() {
    return PanelSeccion(
      titulo: 'Notas',
      icono: Icons.sticky_note_2_outlined,
      child: CampoTexto(
        etiqueta: 'Observaciones',
        controlador: _notasCtrl,
        placeholder: 'Preferencias, acuerdos de pago, detalles a recordar…',
        lineas: 3,
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
                  : 'Crear cliente',
          icono: Icons.check,
          alPresionar: _guardando ? null : _guardar,
        ),
      ],
    );
  }
}
