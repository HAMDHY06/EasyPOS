import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app/app_state.dart';
import 'app/easypos_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.initialize();
  runApp(ChangeNotifierProvider.value(value: state, child: const EasyPosApp()));
}
