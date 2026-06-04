import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import '../modelo/moto.dart';

class MotoMapper {
  MotoMapper._();

  // Fila Drift → Modelo de dominio
  static Moto filaAModelo(TablaMotoData fila, {String? nombreCliente}) {
    return Moto(
      id: fila.id,
      clienteId: fila.clienteId,
      nombreCliente: nombreCliente,
      placa: fila.placa,
      marca: fila.marca,
      modelo: fila.modelo,
      anio: fila.anio,
      cilindraje: fila.cilindraje,
      color: fila.color,
      vin: fila.vin,
      numeroMotor: fila.numeroMotor,
      kilometrajeInicial: fila.kilometrajeInicial,
      notas: fila.notas,
      activo: fila.activo == 1,
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
      marca: Value(moto.marca),
      modelo: Value(moto.modelo),
      anio: Value(moto.anio),
      cilindraje: Value(moto.cilindraje),
      color: Value(moto.color),
      vin: Value(moto.vin),
      numeroMotor: Value(moto.numeroMotor),
      kilometrajeInicial: Value(moto.kilometrajeInicial),
      notas: Value(moto.notas),
      activo: Value(moto.activo ? 1 : 0),
      actualizadoEn: Value(DateTime.now()),
    );
  }
}