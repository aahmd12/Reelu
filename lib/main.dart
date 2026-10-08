import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/dbsupabase.dart';
import 'core/theme/apptheme.dart';

import 'screens/splash/splashscreen.dart';
import 'screens/auth/login.dart';
import 'screens/auth/register.dart';
import 'screens/auth/forgotpassword.dart';
import 'screens/auth/verify.dart';
import 'screens/auth/updatepassword.dart';

import 'screens/dataacademic/dataacademic.dart';
import 'screens/dataacademic/editacademic.dart';
import 'screens/prediction/prediction.dart';

import 'services/history.dart';
import 'services/viewdetails.dart';

import 'bottomnavigation.dart';

final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
  );

  debugPrint('Supabase berhasil diinisialisasi');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Reelu',
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),

        '/login': (context) => const LoginScreen(),

        '/register': (context) => const RegisterScreen(),

        '/forgot-password': (context) =>
            const ForgotPasswordScreen(),

        '/verify': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments;

          final email = args is String ? args : '';

          return VerifyScreen(email: email);
        },

        '/update-password': (context) =>
            const UpdatePasswordScreen(),

        '/dashboard': (context) =>
            const BottomNavigation(),

        '/data-academic': (context) =>
            DataAcademicScreen(),

        '/data-academic-edit': (context) =>
            EditAcademicScreen(),

        '/prediction': (context) =>
            PredictionScreen(),

        '/history': (context) =>
            HistoryScreen(),

        '/view-details': (context) =>
            ViewDetailsScreen(),
      },
    );
  }
}