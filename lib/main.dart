import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'controllers/app_controller.dart';
import 'services/supabase_service.dart';
import 'views/app.dart';
import 'views/shared.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? startupError;
  SupabaseClient? client;
  try {
    client = await SupabaseService.initializeFromEnvironment();
  } catch (_) {
    startupError =
        'تعذر الاتصال. تحقق من SUPABASE_URL و SUPABASE_ANON_KEY ثم أعد تشغيل التطبيق.';
  }
  runApp(
    MainApp(
      store: AppController(client: client),
      startupError: startupError,
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, required this.store, this.startupError});
  final AppController store;
  final String? startupError;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'مولات كسكس',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Tajawal',
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: green,
        primary: green,
        surface: cream,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 15, color: ink),
        bodyLarge: TextStyle(fontSize: 17, color: ink),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cream,
        foregroundColor: green,
        centerTitle: true,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: green,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          textStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
      ),
      dividerTheme: const DividerThemeData(color: line),
    ),
    home: startupError == null
        ? AppRoot(store: store)
        : Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(startupError!, textAlign: TextAlign.center),
              ),
            ),
          ),
  );
}
