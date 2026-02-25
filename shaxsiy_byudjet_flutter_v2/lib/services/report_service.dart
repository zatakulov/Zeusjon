import 'package:intl/intl.dart';
import '../data/app_db.dart';

class ReportService {
  final AppDb db;
  ReportService(this.db);

  String monthKey(DateTime m) => DateFormat('yyyy-MM').format(DateTime(m.year, m.month, 1));

  Future<Map<String, double>> monthlySummary(DateTime month) => db.monthlyTotals(monthKey(month));
  Future<List<Map<String, Object?>>> expenseShare(DateTime month) => db.expenseShareByCategory(monthKey(month));
  Future<List<Map<String, Object?>>> incomeShare(DateTime month) => db.incomeShareByType(monthKey(month));

  Future<List<Map<String, Object?>>> tagSummary(DateTime startMonth, DateTime endMonth) {
    return db.tagSummary(monthKey(startMonth), monthKey(endMonth));
  }

  Future<List<Map<String, Object?>>> yearlyLines(int year) => db.yearMonthlyLines(year);

  Future<Map<String, dynamic>> simpleForecastExpense(DateTime month) async {
    final mk = monthKey(month);
    final totals = await db.monthlyTotals(month);
    final expense = totals['expense'] ?? 0;
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    final now = DateTime.now();
    final effectiveDay = (now.year == month.year && now.month == month.month) ? now.day : monthEnd.day;
    final avg = effectiveDay == 0 ? 0 : expense / effectiveDay;
    return {
      'elapsedDays': effectiveDay,
      'totalDays': monthEnd.day,
      'currentExpense': expense,
      'projectedExpense': avg * monthEnd.day,
      'monthKey': mk,
    };
  }
}
