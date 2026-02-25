import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/app_db.dart';
import '../services/report_service.dart';
import '../utils/date_money.dart';

class DashboardScreen extends StatefulWidget {
  final AppDb db;
  const DashboardScreen({super.key, required this.db});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime month = DateTime(DateTime.now().year < 2026 ? 2026 : DateTime.now().year, DateTime.now().month, 1);

  @override
  Widget build(BuildContext context) {
    final rs = ReportService(widget.db);
    return FutureBuilder(
      future: Future.wait([
        rs.monthlySummary(month),
        rs.simpleForecastExpense(month),
      ]),
      builder: (context, snap) {
        final summary = snap.hasData ? (snap.data![0] as Map<String, double>) : {'income': 0, 'expense': 0, 'net': 0};
        final fc = snap.hasData ? (snap.data![1] as Map<String, dynamic>) : {'currentExpense': 0, 'projectedExpense': 0, 'elapsedDays': 0, 'totalDays': 0};
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Row(
              children: [
                const Expanded(child: Text('Bosh sahifa', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                OutlinedButton.icon(
                  onPressed: () async {
                    final d = await _pickMonth(context, month);
                    if (d != null) setState(() => month = d);
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: Text(DateFormat('yyyy-MM').format(month)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!snap.hasData) const LinearProgressIndicator(),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                _card('Daromad', money(summary['income'] ?? 0), Icons.trending_up, context),
                _card('Xarajat', money(summary['expense'] ?? 0), Icons.trending_down, context),
                _card('Sof natija', money(summary['net'] ?? 0), Icons.account_balance_wallet, context),
                _card('Prognoz xarajat', money((fc['projectedExpense'] as num?) ?? 0), Icons.insights, context),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('Kutilayotgan xarajat (joriy oy tempiga ko‘ra)'),
                subtitle: Text(
                  'Hozirgacha: ${money((fc["currentExpense"] as num?) ?? 0)}\n'
                  'Kunlar: ${fc["elapsedDays"]}/${fc["totalDays"]}\n'
                  'Prognoz: ${money((fc["projectedExpense"] as num?) ?? 0)}',
                ),
                isThreeLine: true,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _card(String title, String value, IconData icon, BuildContext c) {
    return SizedBox(
      width: (MediaQuery.sizeOf(c).width - 32) / 2,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon),
            const SizedBox(height: 6),
            Text(title, style: Theme.of(c).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    );
  }

  Future<DateTime?> _pickMonth(BuildContext context, DateTime initial) async {
    int y = initial.year;
    int m = initial.month;
    return showDialog<DateTime>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Oy tanlang'),
        content: StatefulBuilder(
          builder: (context, setS) => Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: y,
                  items: List.generate(15, (i) => 2026 + i).map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
                  onChanged: (v) => setS(() => y = v ?? y),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: m,
                  items: List.generate(12, (i) => i + 1).map((e) => DropdownMenuItem(value: e, child: Text(e.toString().padLeft(2, '0')))).toList(),
                  onChanged: (v) => setS(() => m = v ?? m),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Bekor')),
          FilledButton(onPressed: () => Navigator.pop(context, DateTime(y, m, 1)), child: const Text('Tanlash')),
        ],
      ),
    );
  }
}
