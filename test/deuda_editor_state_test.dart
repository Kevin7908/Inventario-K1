// Qué se puede tocar de una deuda, según de dónde vino.
//
// Es la mitad de interfaz del arreglo del descuento doble: el repositorio
// rechaza anotarle líneas a la deuda que copia una orden y la base lo impide
// con su guarda, pero si la pantalla siguiera ofreciendo el gesto, el usuario
// chocaría contra un error en vez de entender que eso se corrige en la orden.
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/deudores/enum/enum_deudor.dart';
import 'package:inventario_k1/frontend/features/deudores/deuda_detalle/modelo/deuda_editor_state.dart';

DeudaEditorState _estado({
  EstadoDeudor estado = EstadoDeudor.activa,
  int? ordenId,
  String? numeroOrden,
  DateTime? vence,
}) =>
    DeudaEditorState(
      deudaId: 7,
      numero: 'DEU-014',
      clienteId: 3,
      clienteNombre: 'Carlos Ramírez',
      estado: estado,
      montoTotal: 117000,
      montoPagado: 0,
      ordenId: ordenId,
      numeroOrden: numeroOrden,
      fechaVencimiento: vence,
    );

void main() {
  group('la deuda de mostrador', () {
    test('activa se puede editar y no explica nada', () {
      final deuda = _estado();

      expect(deuda.vieneDeOrden, isFalse);
      expect(deuda.editable, isTrue);
      expect(deuda.motivoNoEditable, isNull);
    });

    test('pagada se lee pero no se toca, y lo dice', () {
      final deuda = _estado(estado: EstadoDeudor.pagada);

      expect(deuda.editable, isFalse);
      expect(deuda.motivoNoEditable, contains('pagada'));
    });
  });

  group('la deuda que copia una orden', () {
    test('no admite líneas nuevas aunque esté activa', () {
      final deuda = _estado(ordenId: 41, numeroOrden: 'ORD-0041');

      expect(deuda.vieneDeOrden, isTrue);
      expect(deuda.editable, isFalse);
      expect(deuda.motivoNoEditable, contains('ORD-0041'));
      expect(deuda.motivoNoEditable, contains('se corrigen en la orden'));
    });

    test('sigue viva: se le cobra y se puede dar por perdida', () {
      // `viva` y `editable` son cosas distintas, y confundirlas dejaba una
      // deuda que no se podía ni cerrar ni marcar como perdida.
      final deuda = _estado(ordenId: 41, numeroOrden: 'ORD-0041');

      expect(deuda.viva, isTrue);
      expect(deuda.saldo, 117000);
    });

    test('vence como cualquier otra', () {
      final deuda = _estado(
        ordenId: 41,
        numeroOrden: 'ORD-0041',
        vence: DateTime.now().subtract(const Duration(days: 2)),
      );

      expect(deuda.estaVencida, isTrue);
    });

    test('una cerrada no vence: ya no espera nada', () {
      final deuda = _estado(
        estado: EstadoDeudor.pagada,
        vence: DateTime.now().subtract(const Duration(days: 2)),
      );

      expect(deuda.estaVencida, isFalse);
    });
  });
}
