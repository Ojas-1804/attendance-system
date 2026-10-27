import 'package:flutter/material.dart';

import 'api_client.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StudentApp());
}

class StudentApp extends StatefulWidget {
  const StudentApp({super.key});

  @override
  State<StudentApp> createState() => _StudentAppState();
}

class _StudentAppState extends State<StudentApp> {
  late final Future<void> _boot = ApiClient.instance.init();

  @override
  void initState() {
    super.initState();
    // If the session ends while a detail screen is open, go back to the root so login is visible.
    ApiClient.instance.authenticated.addListener(() {
      if (!ApiClient.instance.authenticated.value) {
        navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Attendance',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF3F51B5), useMaterial3: true),
      home: FutureBuilder<void>(
        future: _boot,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const _Splash();
          return ValueListenableBuilder<bool>(
            valueListenable: ApiClient.instance.authenticated,
            builder: (_, loggedIn, __) => loggedIn ? const Shell() : const LoginScreen(),
          );
        },
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.how_to_reg, size: 72),
            SizedBox(height: 16),
            Text('Student Attendance', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ]),
        ),
      );
}
