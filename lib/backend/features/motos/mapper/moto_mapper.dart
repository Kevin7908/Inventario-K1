import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import '../modelo/moto.dart';

class MotoMapper {
  MotoMapper._();

  /// Fila Drift → modelo de dominio.
  ///
  /// [marca], [modelo] y [cilindraje] no salen de la fila: los resuelve el
  /// JOIN con el catálogo y los pasa el repositorio, igual que
  /// [nombreCliente]. En `motos` solo están las FK.
  static Moto filaAModelo(
    TablaMotoData fila, {
    String? nombreCliente,
    required String marca,
    String? modelo,
    int? cilindraje,
  }) {
    return Moto(
      id: fila.id,
      clienteId: fila.clienteId,
      nombreCliente: nombreCliente,
      placa: fila.placa,
      marcaId: fila.marcaId,
      marca: marca,
      modeloId: fila.modeloId,
      modelo: modelo,
      cilindraje: cilindraje,
      anio: fila.anio,
      color: fila.color,
      numeroMotor: fila.numeroMotor,
      notas: fila.notas,
      activo: fila.activo,
      creadoEn: fila.creadoEn,
      actualizadoEn: fila.actualizadoEn,
    );
  }

  // Modelo de dominio → Companion Drift
  static TablaMotoCompanion modeloACompanion(Moto moto) {
    return TablaMotoCompanion(
      id: moto.id == 0 ? const Value.absent() : Value(moto.id),
      clienteId: Value(moto.clienteId),
      placa: Value(moto.placa),
      // Solo viajan las FK: los nombres son de presentación.
      marcaId: Value(moto.marcaId),
      modeloId: Value(moto.modeloId),
      anio: Value(moto.anio),
      color: Value(moto.color),
      numeroMotor: Value(moto.numeroMotor),
      notas: Value(moto.notas),
      activo: Value(moto.activo),
      actualizadoEn: Value(DateTime.now()),
    );
  }
}