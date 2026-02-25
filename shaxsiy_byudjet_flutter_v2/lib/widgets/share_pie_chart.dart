import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SharePieChart extends StatelessWidget {
  final List<Map<String, Object?>> rows;
  final double height;
  const SharePieChart({super.key, required this.rows, this.height = 220});

  @override
  Widget build(BuildContext context) {
    final valid = rows.where((r) => ((r['amount'] as num?) ?? 0) > 0).toList();
    final total = valid.fold<double>(0, (s, r) => s + (((r['amount'] as num?) ?? 0).toDouble()));
    if (valid.isEmpty) return const Text('Ma’lumot yo‘q');

    final palette = [
      Colors.teal, Colors.blue, Colors.orange, Colors.purple,
      Colors.red, Colors.green, Colors.amber, Colors.indigo
    ];

    return SizedBox(
      height: height,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 32,
          sections: List.generate(valid.length, (i) {
            final amount = (((valid[i]['amount'] as num?) ?? 0).toDouble());
            final pct = total == 0 ? 0 : amount / total * 100;
            return PieChartSectionData(
              value: amount,
              title: '${pct.toStringAsFixed(1)}%',
              radius: 70,
              color: palette[i % palette.length],
            );
          }),
        ),
      ),
    );
  }
}
