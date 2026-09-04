import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const ProviderScope(child: MoneyPlantApp()));
}

class MoneyPlantApp extends StatelessWidget {
  const MoneyPlantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Money Plant',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(dark: false),
      darkTheme: buildTheme(dark: true),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
