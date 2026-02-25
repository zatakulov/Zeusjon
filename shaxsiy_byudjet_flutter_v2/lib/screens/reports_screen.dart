import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/app_db.dart';
import '../services/report_service.dart';
import '../utils/date_money.dart';
import '../widgets/share_pie_chart.dart';

class ReportsScreen extends StatefulWidget {
  final AppDb db;
  const ReportsScreen({super.key, required this.db});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime month = DateTime(DateTime.now().year < 2026 ? 2026 : DateTime.now().year, DateTime.now().month, 1);
  int year = DateTime.now().year < 2026 ? 2026 : DateTime.now().year;
  DateTime tagStart = DateTime(DateTime.now().year < 2026 ? 2026 : DateTime.now().year, 1, 1);
  DateTime tagEnd = DateTime(DateTime.now().year < 2026 ? 2026 : DateTime.now().year, DateTime.now().month, 1);

  @override
  Widget build(BuildContext context) {
    final rs = ReportService(widget.db);
    return FutureBuilder(
      future: Future.wait([
        rs.expenseShare(month),
        rs.incomeShare(month),
        rs.yearlyLines(year),
        rs.tagSummary(tagStart, tagEnd),
      ]),
      builder: (context, snap) {
        final expenseRows = snap.hasData ? (snap.data![0] as List<Map<String, Object?>>) : <Map<String, Object?>>[];
        final incomeRows = snap.hasData ? (snap.data![1] as List<Map<String, Object?>>) : <Map<String, Object?>>[];
        final yearRows = snap.hasData ? (snap.data![2] as List<Map<String, Object?>>) : <Map<String, Object?>>[];
        final tagRows = snap.hasData ? (snap.data![3] as List<Map<String, Object?>>) : <Map<String, Object?>>[];

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Row(
              children: [
                const Expanded(child: Text('Hisobotlar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
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
            if (!snap.hasData) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Xarajatlar ulushi (turkum bo‘yicha)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SharePieChart(rows: expenseRows),
                  const SizedBox(height: 8),
                  ...expenseRows.map((r) => ListTile(
                    dense: true, contentPadding: EdgeInsets.zero,
                    title: Text('${r["label"]}'),
                    trailing: Text(money((r["amount"] as num?) ?? 0)),
                  ))
                ]),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Daromad ulushi (turlar bo‘yicha)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SharePieChart(rows: incomeRows),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Tag / Loyiha jamlanma', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, children: [
                    OutlinedButton(onPressed: () async {
                      final d = await _pickMonth(context, tagStart);
                      if (d != null) setState(() => tagStart = d);
                    }, child: Text('Boshlanish: ${DateFormat('yyyy-MM').format(tagStart)}')),
                    OutlinedButton(onPressed: () async {
                      final d = await _pickMonth(context, tagEnd);
                      if (d != null) setState(() => tagEnd = d);
                    }, child: Text('Tugash: ${DateFormat('yyyy-MM').format(tagEnd)}')),
                  ]),
                  const SizedBox(height: 8),
                  ...tagRows.map((r) => ListTile(
                    dense: true, contentPadding: EdgeInsets.zero,
                    title: Text('${r["tag_name"]}'),
                    subtitle: Text('Daromad: ${money((r["income"] as num?) ?? 0)} | Xarajat: ${money((r["expense"] as num?) ?? 0)}'),
                    trailing: Text(money((r["net"] as num?) ?? 0)),
                  )),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Expanded(child: Text('Yillik trend', style: TextStyle(fontWeight: FontWeight.bold))),
                    DropdownButton<int>(
                      value: year,
                      items: List.generate(15, (i) => 2026 + i).map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                      onChanged: (v) => setState(() => year = v ?? year),
                    ),
                  ]),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Oy')),
                        DataColumn(label: Text('Daromad')),
                        DataColumn(label: Text('Xarajat')),
                        DataColumn(label: Text('Sof')),
                      ],
                      rows: yearRows.map((r) {
                        final income = ((r['income'] as num?) ?? 0).toDouble();
                        final expense = ((r['expense'] as num?) ?? 0).toDouble();
                        return DataRow(cells: [
                          DataCell(Text('${r["month"]}')),
                          DataCell(Text(money(income, suffix: ''))),
                          DataCell(Text(money(expense, suffix: ''))),
                          DataCell(Text(money(income - expense, suffix: ''))),
                        ]);
                      }).toList(),
                    ),
                  )
                ]),
              ),
            ),
          ],
        );
      },
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
          builder: (context, setS) => Row(children: [
            Expanded(child: DropdownButtonFormField<int>(
              value: y,
              items: List.generate(15, (i) => 2026 + i).map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
              onChanged: (v) => setS(() => y = v ?? y),
            )),
            const SizedBox(width: 8),
            Expanded(child: DropdownButtonFormField<int>(
              value: m,
              items: List.generate(12, (i) => i+1).map((e) => DropdownMenuItem(value: e, child: Text(e.toString().padLeft(2, '0')))).toList(),
              onChanged: (v) => setS(() => m = v ?? m),
            )),
          ]),
        ),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Bekor')),
          FilledButton(onPressed: ()=>Navigator.pop(context, DateTime(y,m,1)), child: const Text('Tanlash')),
        ],
      ),
    );
  }
}
