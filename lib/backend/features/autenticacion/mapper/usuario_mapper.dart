import 'package:inventario_k1/backend/features/autenticacion/modelo/usuario.dart';

import '../../../share/database/app_db.dart';

class UsuarioMapper {
  
    static Usuario filaAModelo(TablaUsuarioData fila) {
    return Usuario(
      id: fila.id,
      nombre: fila.nombre,
      usuario: fila.usuario,
      email: fila.email,
      passwordHash: fila.passwordHash,
      esAdmin: fila.esAdmin,
      estaActivo: fila.estaActivo,
      creadoEn: fila.creadoEn,
    );
  }
}