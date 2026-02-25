import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import '../data/app_db.dart';

class ExportBackupService {
  final AppDb db;
  ExportBackupService(this.db);

  Future<File> exportTransactionsCsv(String monthKey) async {
    final rows = await db.getTransactionsByMonth(monthKey);
    final data = <List<dynamic>>[
      ['id', 'entry_date', 'entry_type', 'income_type_name', 'expense_category_name', 'tag_name', 'account_name', 'currency', 'amount', 'amount_uzs', 'note'],
      ...rows.map((r) => [
            r['id'],
            r['entry_date'],
            r['entry_type'],
            r['income_type_name'],
            r['expense_category_name'],
            r['tag_name'],
            r['account_name'],
            r['currency'],
            r['amount'],
            r['amount_uzs'],
            r['note'],
          ]),
    ];
    final csv = const ListToCsvConverter().convert(data);
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/transactions_$monthKey.csv');
    return f.writeAsString(csv);
  }

  Future<File> backupJson() async {
    final payload = await db.exportAllAsJson();
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/budget_backup.json');
    return f.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
  }

  Future<void> restoreJsonFile(File file) async {
    final txt = await file.readAsString();
    final data = jsonDecode(txt) as Map<String, dynamic>;
    await db.restoreFromJson(data);
  }
}
