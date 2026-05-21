import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../backend/features/productos/repositorio/repositorio_producto.dart';
import '../../../../backend/features/productos/repositorio/repositorio_producto_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';
import '../view_model/productos_view_model.dart';

final repositorioProductosProvider = Provider<RepositorioProducto>(
  name: 'repositorioProductosProvider',
  (ref) => RepositorioProductosImpl(ref.watch(appDatabaseProvider)),
);

final productosProvider = ChangeNotifierProvider<ProductosViewModel>(
  name: 'productosProvider',
  (ref) => ProductosViewModel(ref.watch(repositorioProductosProvider)),
);