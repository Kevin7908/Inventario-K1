import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/proveedores/modelo/proveedor.dart';
import '../../../../core/resultado.dart';
import '../../../../core/validaciones.dart';
import '../../../share/share.dart';
import '../provider/proveedores_provider.dart';

/// Formulario de alta y edición de un proveedor.
///
/// Es el **único** sitio donde vive el formulario. Sigue el patrón de
/// `FormularioProducto`: la página que lo hospeda solo pone el marco y este
/// widget resuelve campos, validación y guardado.
///
/// Parámetros:
/// - [proveedorAEditar]: proveedor a modificar. Si es `null`, crea uno nuevo.
/// - [alTerminar]: se llama tras guardar con éxito, para volver a la lista.
/// - [alCancelar]: se llama al presionar "Cancelar".
class FormularioProveedor extends ConsumerStatefulWidget {
  const FormularioProveedor({
    super.key,
    this.proveedorAEditar,
    required this.alTerminar,
    required this.alCancelar,
  });

  final Proveedor? proveedorAEditar;
  final VoidCallback alTerminar;
  final VoidCallback alCancelar;

  bool get esEdicion => proveedorAEditar != null;

  @override
  ConsumerState<FormularioProveedor> createState() =>
      _FormularioProveedorState();
}

class _FormularioProveedorState extends ConsumerState<FormularioProveedor> {
  final _formKey = GlobalKey<FormState>();
  bool _guardando = false;

  late final TextEditingController _nombreCtrl;
  late final TextEditingController _nitCtrl;
  late final TextEditingController _contactoCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _ciudadCtrl;
  late final TextEditingController _notasCtrl;

  late bool _activo;

  @override
  void initState() {
    super.initState();
    final p = widget.proveedorAEditar;

    _nombreCtrl = TextEditingController(text: p?.nombre ?? '');
    _nitCtrl = TextEditingController(text: p?.nitCedula ?? '');
    _contactoCtrl = TextEditingController(text: p?.contacto ?? '');
    _telefonoCtrl = TextEditingController(text: p?.telefono ?? '');
    _emailCtrl = TextEditingController(text: p?.email ?? '');
    _direccionCtrl = TextEditingController(text: p?.direccion ?? '');
    _ciudadCtrl = TextEditingController(text: p?.ciudad ?? '');
    _notasCtrl = TextEditingController(text: p?.notas ?? '');

    _activo = p?.activo ?? true;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _nitCtrl.dispose();
    _contactoCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _direccionCtrl.dispose();
    _ciudadCtrl.dispose();
    _notasCtrl.dispose();
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

    setState(() => _guardando = true);

    final proveedor = Proveedor(
      id: widget.proveedorAEditar?.id,
      nombre: _nombreCtrl.text.trim(),
      nitCedula: _opcional(_nitCtrl),
      contacto: _opcional(_contactoCtrl),
      telefono: _opcional(_telefonoCtrl),
      email: _opcional(_emailCtrl),
      direccion: _opcional(_direccionCtrl),
      ciudad: _opcional(_ciudadCtrl),
      notas: _opcional(_notasCtrl),
      activo: _activo,
      creadoEn: widget.proveedorAEditar?.creadoEn,
    );

    final notifier = ref.read(proveedoresProvider.notifier);
    final resultado = widget.esEdicion
        ? await notifier.actualizar(proveedor)
        : await notifier.crear(proveedor);

    if (!mounted) return;

    if (resultado case Fallo(:final mensaje)) {
      _mostrarMensaje(mensaje, esError: true);
      setState(() => _guardando = false);
      return;
    }

    _mostrarMensaje(
      widget.esEdicion
          ? 'Proveedor actualizado correctamente.'
          : 'Proveedor creado correctamente.',
      esError: false,
    );
    widget.alTerminar();
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
            _bloqueEstado(),
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
            hijos: [
              CampoTexto(
                etiqueta: 'Nombre *',
                controlador: _nombreCtrl,
                placeholder: 'Ej: Distribuidora Moto Parts SAS',
                autofocus: true,
                validador: (v) => validarObligatorio(v, 'El nombre'),
              ),
              CampoTexto(
                etiqueta: 'NIT / Cédula',
                controlador: _nitCtrl,
                placeholder: 'Ej: 9001234567',
                monoespaciado: true,
                soloEnteros: true,
                maximoCaracteres: maximoDigitosDocumento,
                validador: validarDocumento,
              ),
            ],
          ),
          const SizedBox(height: 16),
          CampoTexto(
            etiqueta: 'Notas',
            controlador: _notasCtrl,
            placeholder: 'Condiciones de pago, tiempos de entrega...',
            lineas: 3,
          ),
        ],
      ),
    );
  }

  Widget _bloqueContacto() {
    return PanelSeccion(
      titulo: 'Contacto',
      icono: Icons.person_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilaCampos(
            hijos: [
              CampoTexto(
                etiqueta: 'Persona de contacto',
                controlador: _contactoCtrl,
                placeholder: 'Ej: Carlos Méndez',
              ),
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
                placeholder: 'Ej: ventas@proveedor.com',
                validador: validarEmail,
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilaCampos(
            hijos: [
              CampoTexto(
                etiqueta: 'Dirección',
                controlador: _direccionCtrl,
                placeholder: 'Ej: Cra 15 # 80-45',
              ),
              CampoTexto(
                etiqueta: 'Ciudad',
                controlador: _ciudadCtrl,
                placeholder: 'Ej: Bogotá',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Solo el estado. La apariencia se fue: todos los proveedores se pintan
  /// igual, con el almacén y el color de la app (ver `IdentidadProveedor`).
  Widget _bloqueEstado() {
    return PanelSeccion(
      titulo: 'Estado',
      icono: Icons.toggle_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InterruptorCampo(
            etiqueta: 'Proveedor activo',
            detalle: _activo
                ? 'Aparece al asignar proveedor a un producto'
                : 'Se conserva su historial, pero no se ofrece al crear productos',
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
                  : 'Crear proveedor',
          icono: Icons.check,
          alPresionar: _guardando ? null : _guardar,
        ),
      ],
    );
  }
}
