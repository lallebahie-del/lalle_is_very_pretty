import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'app_language.dart';
import 'app_theme_manager.dart';
import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'screens/user_home_page.dart';
import 'screens/dashboard_admin.dart';
import 'widgets/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final appLanguage = AppLanguage();
  final themeManager = AppThemeManager();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([appLanguage, themeManager]),
      builder: (_, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: appLanguage.locale,
          supportedLocales: const [
            Locale('fr'),
            Locale('ar'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: themeManager.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: const Color(0xFF386641),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            colorSchemeSeed: const Color(0xFF386641),
          ),
          home: AuthWrapper(
            appLanguage: appLanguage,
            themeManager: themeManager,
          ),
          routes: {
            '/login': (_) => LoginPage(
                  appLanguage: appLanguage,
                  themeManager: themeManager,
                ),
            '/register': (_) => RegisterPage(appLanguage: appLanguage),
            '/user': (_) => UserHomePage(
                  appLanguage: appLanguage,
                  themeManager: themeManager,
                ),
            '/admin': (_) => DashboardAdmin(
                  themeManager: themeManager,
                ),
            '/user-reports': (_) => UserReportsPage(
                  themeManager: themeManager,
                ),
          },
        );
      },
    );
  }
}
