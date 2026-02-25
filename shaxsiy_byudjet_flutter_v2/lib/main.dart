import 'package:flutter/material.dart';
import 'app_shell.dart';
import 'data/app_db.dart';
import 'services/pin_auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDb();
  await db.init();
  final auth = PinAuthService();
  await auth.init();
  runApp(BudgetApp(db: db, auth: auth));
}

class BudgetApp extends StatelessWidget {
  final AppDb db;
  final PinAuthService auth;
  const BudgetApp({super.key, required this.db, required this.auth});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shaxsiy Byudjet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
      ),
      home: LockGate(db: db, auth: auth),
    );
  }
}

class LockGate extends StatefulWidget {
  final AppDb db;
  final PinAuthService auth;
  const LockGate({super.key, required this.db, required this.auth});

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> {
  bool? unlocked;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final pinEnabled = await widget.auth.isPinEnabled();
    if (!pinEnabled) {
      setState(() => unlocked = true);
      return;
    }
    final ok = await widget.auth.tryUnlockWithBiometricOrPin(context);
    if (!mounted) return;
    setState(() => unlocked = ok);
  }

  @override
  Widget build(BuildContext context) {
    if (unlocked == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (unlocked == false) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ilova qulflangan'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _check, child: const Text('Qayta urinish')),
            ],
          ),
        ),
      );
    }
    return AppShell(db: widget.db, auth: widget.auth);
  }
}
