import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/app_db.dart';
import '../models/entities.dart';
import '../services/fx_rate_service.dart';
import '../utils/date_money.dart';

class TransactionsScreen extends StatefulWidget {
  final AppDb db;
  const TransactionsScreen({super.key, required this.db});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  DateTime month = DateTime(DateTime.now().year < 2026 ? 2026 : DateTime.now().year, DateTime.now().month, 1);

  @override
  Widget build(BuildContext context) {
    final mk = ym(month);
    return FutureBuilder<List<Map<String, Object?>>>(
      future: widget.db.getTransactionsByMonth(mk),
      builder: (context, snap) {
        final rows = snap.data ?? [];
        return Scaffold(
          appBar: AppBar(
            title: const Text('Tranzaksiyalar'),
            actions: [
              OutlinedButton.icon(
                onPressed: () async {
                  final d = await _pickMonth(context, month);
                  if (d != null) setState(() => month = d);
                },
                icon: const Icon(Icons.calendar_month),
                label: Text(mk),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (!snap.hasData) const LinearProgressIndicator(),
              if (rows.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(12), child: Text('Bu oyda tranzaksiya yo‘q')))
              else
                ...rows.map((r) {
                  final t = r['entry_type'] as String;
                  final label = t == 'income' ? (r['income_type_name'] ?? 'Daromad') : (r['expense_category_name'] ?? 'Xarajat');
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Icon(t == 'income' ? Icons.add : Icons.remove)),
                      title: Text('$label'),
                      subtitle: Text(
                        '${r["entry_date"]} • ${r["tag_name"] ?? "-"} • ${r["account_name"]}\n${r["note"] ?? ""}',
                      ),
                      isThreeLine: true,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${t=="income" ? "+" : "-"} ${r["amount"]} ${r["currency"]}'),
                          Text('≈ ${r["amount_uzs"] ?? 0} UZS', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => TransactionAddScreen(db: widget.db)),
              );
              if (changed == true) setState(() {});
            },
            icon: const Icon(Icons.add),
            label: const Text('Qo‘shish'),
          ),
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
        content: StatefulBuilder(builder: (context, setS) {
          return Row(children: [
            Expanded(child: DropdownButtonFormField<int>(
              value: y, items: List.generate(15, (i)=>2026+i).map((e)=>DropdownMenuItem(value: e, child: Text('$e'))).toList(),
              onChanged: (v)=>setS(()=>y = v ?? y),
            )),
            const SizedBox(width: 8),
            Expanded(child: DropdownButtonFormField<int>(
              value: m, items: List.generate(12, (i)=>i+1).map((e)=>DropdownMenuItem(value: e, child: Text(e.toString().padLeft(2,'0')))).toList(),
              onChanged: (v)=>setS(()=>m = v ?? m),
            )),
          ]);
        }),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Bekor')),
          FilledButton(onPressed: ()=>Navigator.pop(context, DateTime(y,m,1)), child: const Text('Tanlash')),
        ],
      ),
    );
  }
}

class TransactionAddScreen extends StatefulWidget {
  final AppDb db;
  const TransactionAddScreen({super.key, required this.db});

  @override
  State<TransactionAddScreen> createState() => _TransactionAddScreenState();
}

class _TransactionAddScreenState extends State<TransactionAddScreen> {
  DateTime date = DateTime.now().isBefore(DateTime(2026,1,1)) ? DateTime(2026,1,1) : DateTime.now();
  String entryType = 'expense';
  int? incomeTypeId;
  int? expenseCategoryId;
  int? tagId;
  int? accountId;
  String currency = 'UZS';
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  List<Map<String, Object?>> incomeTypes = [];
  List<Map<String, Object?>> expenseCats = [];
  List<Map<String, Object?>> tags = [];
  List<Map<String, Object?>> accounts = [];

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    incomeTypes = await widget.db.listLookup('lists_income_types');
    expenseCats = await widget.db.listLookup('lists_expense_categories');
    tags = await widget.db.listLookup('lists_tags_projects');
    accounts = await widget.db.db.rawQuery('SELECT id, name, currency FROM accounts WHERE is_active=1 ORDER BY name');
    if (incomeTypes.isNotEmpty) incomeTypeId ??= incomeTypes.first['id'] as int;
    if (expenseCats.isNotEmpty) expenseCategoryId ??= expenseCats.first['id'] as int;
    if (tags.isNotEmpty) tagId ??= tags.first['id'] as int;
    if (accounts.isNotEmpty) {
      accountId ??= accounts.first['id'] as int;
      currency = (accounts.first['currency'] as String?) ?? 'UZS';
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fxService = FxRateService(widget.db);
    return Scaffold(
      appBar: AppBar(title: const Text('Yangi tranzaksiya')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'income', label: Text('Daromad')),
              ButtonSegment(value: 'expense', label: Text('Xarajat')),
            ],
            selected: {entryType},
            onSelectionChanged: (s) => setState(() => entryType = s.first),
          ),
          const SizedBox(height: 8),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.4),
            title: const Text('Sana'),
            subtitle: Text(DateFormat('yyyy-MM-dd').format(date)),
            trailing: const Icon(Icons.calendar_month),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                firstDate: DateTime(2026,1,1),
                lastDate: DateTime(2100,12,31),
                initialDate: date,
              );
              if (d != null) setState(() => date = d);
            },
          ),
          const SizedBox(height: 8),
          if (entryType == 'income')
            DropdownButtonFormField<int>(
              value: incomeTypeId,
              items: incomeTypes.map((e)=>DropdownMenuItem(value: e['id'] as int, child: Text('${e['name']}'))).toList(),
              onChanged: (v)=>setState(()=>incomeTypeId = v),
              decoration: const InputDecoration(labelText: 'Daromad turi', border: OutlineInputBorder()),
            )
          else
            DropdownButtonFormField<int>(
              value: expenseCategoryId,
              items: expenseCats.map((e)=>DropdownMenuItem(value: e['id'] as int, child: Text('${e['name']}'))).toList(),
              onChanged: (v)=>setState(()=>expenseCategoryId = v),
              decoration: const InputDecoration(labelText: 'Xarajat turkumi', border: OutlineInputBorder()),
            ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: tagId,
            items: tags.map((e)=>DropdownMenuItem(value: e['id'] as int, child: Text('${e['name']}'))).toList(),
            onChanged: (v)=>setState(()=>tagId = v),
            decoration: const InputDecoration(labelText: 'Tag / Loyiha', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: accountId,
            items: accounts.map((e)=>DropdownMenuItem(
              value: e['id'] as int,
              child: Text('${e['name']} • ${e['currency']}'),
            )).toList(),
            onChanged: (v){
              final row = accounts.firstWhere((a)=>a['id']==v);
              setState(() {
                accountId = v;
                currency = (row['currency'] as String?) ?? 'UZS';
              });
            },
            decoration: const InputDecoration(labelText: 'Hisob (naqd/karta)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          FutureBuilder<double?>(
            future: currency == 'USD' ? fxService.getRateOnOrBefore(ymd(date)) : Future.value(null),
            builder: (context, rateSnap) {
              return TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Summa ($currency)',
                  helperText: currency == 'USD'
                      ? 'USD kursi (CBU/manual): ${rateSnap.data ?? "yo‘q"}'
                      : null,
                  border: const OutlineInputBorder(),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: noteCtrl,
            decoration: const InputDecoration(labelText: 'Izoh', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text.replaceAll(',', ''));
              if (amount == null || amount <= 0) return;
              if (accountId == null) return;
              if (!isAllowedDate(date)) return;
              double? rate;
              double amountUzs;
              if (currency == 'USD') {
                rate = await fxService.getRateOnOrBefore(ymd(date));
                if (rate == null || rate <= 0) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('USD kurs topilmadi. Avval kurs kiriting.')));
                  return;
                }
                amountUzs = amount * rate;
              } else {
                amountUzs = amount;
              }
              await widget.db.addTransaction(TxEntity(
                entryDate: ymd(date),
                entryType: entryType,
                incomeTypeId: entryType == 'income' ? incomeTypeId : null,
                expenseCategoryId: entryType == 'expense' ? expenseCategoryId : null,
                tagProjectId: tagId,
                accountId: accountId!,
                currency: currency,
                amount: amount,
                amountUzs: amountUzs,
                fxRate: rate,
                note: noteCtrl.text.trim(),
              ));
              if (!mounted) return;
              Navigator.pop(context, true);
            },
            icon: const Icon(Icons.save),
            label: const Text('Saqlash'),
          ),
        ],
      ),
    );
  }
}
