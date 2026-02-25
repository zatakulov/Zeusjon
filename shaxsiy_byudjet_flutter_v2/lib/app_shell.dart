import 'package:flutter/material.dart';
import 'data/app_db.dart';
import 'screens/dashboard_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/debts_screen.dart';
import 'screens/settings_screen.dart';
import 'services/pin_auth_service.dart';

class AppShell extends StatefulWidget {
  final AppDb db;
  final PinAuthService auth;
  const AppShell({super.key, required this.db, required this.auth});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(db: widget.db),
      TransactionsScreen(db: widget.db),
      ReportsScreen(db: widget.db),
      DebtsScreen(db: widget.db),
      SettingsScreen(db: widget.db, auth: widget.auth),
    ];

    return Scaffold(
      body: SafeArea(child: pages[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Bosh'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Tranzaksiya'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Hisobot'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Qarz'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Sozlama'),
        ],
      ),
    );
  }
}
