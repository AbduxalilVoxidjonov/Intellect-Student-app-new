import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/session.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = Session();
  await session.init();
  runApp(
    ChangeNotifierProvider.value(value: session, child: const StudentApp()),
  );
}

class StudentApp extends StatelessWidget {
  const StudentApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final colors = session.isDark ? AppColors.dark : AppColors.light;
    return MaterialApp(
      title: 'Intellect Student',
      debugShowCheckedModeBanner: false,
      theme: buildMaterialTheme(colors),
      // AppTheme'ni Navigator ustida joylashtiramiz — barcha push qilingan
      // sub-screen'lar ham `AppTheme.of(context)` orqali ranglarni oladi.
      builder: (context, child) => AppTheme(colors: colors, child: child ?? const SizedBox()),
      home: !session.ready
          ? const _Splash()
          : (session.isAuthed ? const ShellScreen() : const LoginScreen()),
    );
  }
}

/// Sessiya o'qilayotgandagi ekran. Native splash (logo + ko'k fon) bilan AYNAN bir xil
/// ko'rinadi — shu sabab ilova ochilganda ekran o'zgarib "sakramaydi".
class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: kBrandBlue,
      body: Center(
        child: SizedBox(
          width: 150,
          height: 150,
          child: Image(image: AssetImage('assets/logo.png'), fit: BoxFit.contain),
        ),
      ),
    );
  }
}
