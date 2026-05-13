import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_db.dart';
import 'locator.dart';

// Este es el "puente" único. Se pone aquí para que cualquier feature 
// pueda importarlo sin depender de la feature "especializaciones".
final appDatabaseProvider = Provider<AppDb>(
  (ref) => locator<AppDb>(),
  name: 'appDatabaseProvider',
);
