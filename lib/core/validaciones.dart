/// Validadores de los datos de identidad y contacto.
///
/// **Fuente única.** Documento, teléfono y correo viven en `personas`, que
/// comparten cliente, técnico, proveedor y cuenta de usuario: si cada
/// formulario trajera su propia regla, la misma cédula sería válida en una
/// pantalla e inválida en otra.
///
/// Todos devuelven `null` cuando el valor es aceptable y el mensaje de error
/// cuando no, que es lo que espera un `validator` de `TextFormField`.
///
/// Los campos opcionales aceptan vacío: lo que se valida es el **formato de lo
/// que se escribió**, no que se haya escrito. Quién es obligatorio lo decide
/// cada formulario.
library;

/// Longitudes de un documento colombiano.
///
/// La cédula tiene entre 7 y 10 dígitos; el NIT de una empresa, 9 más el de
/// verificación. Once cubre los dos con margen.
const int minimoDigitosDocumento = 7;
const int maximoDigitosDocumento = 11;

/// Un celular colombiano son 10 dígitos; un fijo con indicativo, 10 también.
const int maximoDigitosTelefono = 10;

/// Solo dígitos, ya sin puntos, guiones ni espacios.
final RegExp _soloDigitos = RegExp(r'^\d+$');

/// Deja el valor como se guarda: sin separadores. Los usuarios teclean
/// `900.123.456-7` y eso no es un documento distinto de `9001234567`.
String normalizarDigitos(String valor) => valor.replaceAll(RegExp(r'\D'), '');

/// Cédula o NIT. Opcional: hay clientes de mostrador que no lo dan.
String? validarDocumento(String? valor, {bool obligatorio = false}) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return obligatorio ? 'El documento es obligatorio.' : null;
  }
  if (!_soloDigitos.hasMatch(texto)) {
    return 'El documento solo lleva números, sin puntos ni guiones.';
  }
  if (texto.length < minimoDigitosDocumento) {
    return 'Mínimo $minimoDigitosDocumento dígitos.';
  }
  if (texto.length > maximoDigitosDocumento) {
    return 'Máximo $maximoDigitosDocumento dígitos.';
  }
  return null;
}

/// Teléfono fijo o celular.
String? validarTelefono(String? valor, {bool obligatorio = false}) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return obligatorio ? 'El teléfono es obligatorio.' : null;
  }
  if (!_soloDigitos.hasMatch(texto)) {
    return 'El teléfono solo lleva números.';
  }
  if (texto.length > maximoDigitosTelefono) {
    return 'Máximo $maximoDigitosTelefono dígitos.';
  }
  return null;
}

/// Correo electrónico.
///
/// Deliberadamente laxa: basta con que tenga forma de correo. Rechazar
/// direcciones raras pero válidas molesta más de lo que ayuda.
String? validarEmail(String? valor, {bool obligatorio = false}) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return obligatorio ? 'El correo es obligatorio.' : null;
  }
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(texto)
      ? null
      : 'Correo con formato inválido.';
}

/// Un texto que hay que escribir sí o sí.
String? validarObligatorio(
  String? valor,
  String queEs, {
  int minimo = 2,
  int maximo = 120,
}) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) return '$queEs es obligatorio.';
  if (texto.length < minimo) return 'Mínimo $minimo caracteres.';
  if (texto.length > maximo) return 'Máximo $maximo caracteres.';
  return null;
}

/// Un importe en pesos. Nunca negativo, y sin letras.
///
/// [obligatorio] en `false` acepta el campo vacío, que es como se dice «este
/// producto no tiene precio de taller».
String? validarImporte(String? valor, {bool obligatorio = true}) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return obligatorio ? 'Escribe un valor.' : null;
  }
  final numero = int.tryParse(normalizarDigitos(texto));
  if (numero == null) return 'Solo números.';
  if (numero < 0) return 'No puede ser negativo.';
  return null;
}

/// Una cantidad que puede llevar decimales: hay productos por litro y por
/// metro. Nunca negativa.
String? validarCantidad(String? valor, {bool obligatorio = true}) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return obligatorio ? 'Escribe una cantidad.' : null;
  }
  final numero = double.tryParse(texto.replaceAll(',', '.'));
  if (numero == null) return 'Solo números.';
  if (numero < 0) return 'No puede ser negativa.';
  return null;
}
