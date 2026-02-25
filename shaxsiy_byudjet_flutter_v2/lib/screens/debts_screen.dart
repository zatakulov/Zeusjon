import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/app_db.dart';
import '../models/entities.dart';
import '../services/fx_rate_service.dart';
import '../utils/date_money.dart';

class DebtsScreen extends StatefulWidget {
  final AppDb db;
  const DebtsScreen({super.key, required this.db});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([
        widget.db.debtOutstanding('they_owe_me'),
        widget.db.debtOutstanding('i_owe'),
        widget.db.db.rawQuery('''
          SELECT de.*, p.full_name as person_name, a.name as account_name
          FROM debt_entries de
          JOIN persons p ON p.id = de.person_id
          JOIN accounts a ON a.id = de.account_id
          ORDER BY de.entry_date DESC, de.id DESC
          LIMIT 30
        ''')
      ]),
      builder: (context, snap) {
        final oweMe = snap.hasData ? (snap.data![0] as List<Map<String,Object?>>) : <Map<String,Object?>>[];
        final iOwe = snap.hasData ? (snap.data![1] as List<Map<String,Object?>>) : <Map<String,Object?>>[];
        final journal = snap.hasData ? (snap.data![2] as List<Map<String,Object?>>) : <Map<String,Object?>>[];
        return Scaffold(
          appBar: AppBar(title: const Text('Qarzlar')),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (!snap.hasData) const LinearProgressIndicator(),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Menga qarzdorlar (qoldiq)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    if (oweMe.isEmpty) const Text('Yo‘q'),
                    ...oweMe.map((r)=>ListTile(
                      dense: true, contentPadding: EdgeInsets.zero,
                      title: Text('${r["person"]}'),
                      trailing: Text(money((r["balance_uzs"] as num?) ?? 0)),
                    ))
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Men qarzdorlarim (qoldiq)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    if (iOwe.isEmpty) const Text('Yo‘q'),
                    ...iOwe.map((r)=>ListTile(
                      dense: true, contentPadding: EdgeInsets.zero,
                      title: Text('${r["person"]}'),
                      trailing: Text(money((r["balance_uzs"] as num?) ?? 0)),
                    ))
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Qarzlar jurnali', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    ...journal.map((r)=>ListTile(
                      dense: true, contentPadding: EdgeInsets.zero,
                      title: Text('${r["person_name"]} • ${r["operation"]}'),
                      subtitle: Text('${r["entry_date"]} • ${r["account_name"]}'),
                      trailing: Text('${r["amount"]} ${r["currency"]}'),
                    )),
                  ]),
                ),
              )
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => DebtAddScreen(db: widget.db)));
              if (changed == true) setState(() {});
            },
            icon: const Icon(Icons.add),
            label: const Text('Qarz harakati'),
          ),
        );
      },
    );
  }
}

class DebtAddScreen extends StatefulWidget {
  final AppDb db;
  const DebtAddScreen({super.key, required this.db});

  @override
  State<DebtAddScreen> createState() => _DebtAddScreenState();
}

class _DebtAddScreenState extends State<DebtAddScreen> {
  DateTime date = DateTime.now().isBefore(DateTime(2026,1,1)) ? DateTime(2026,1,1) : DateTime.now();
  String direction = 'they_owe_me';
  String operation = 'berildi';
  int? personId;
  int? accountId;
  String currency = 'UZS';
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  List<Map<String, Object?>> persons = [];
  List<Map<String, Object?>> accounts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<String> get ops => direction == 'they_owe_me' ? ['berildi', 'qaytarildi'] : ['oldim', 'qaytardim'];

  Future<void> _load() async {
    persons = await widget.db.listLookup('persons');
    accounts = await widget.db.db.rawQuery('SELECT id, name, currency FROM accounts WHERE is_active=1 ORDER BY name');
    if (persons.isNotEmpty) personId ??= persons.first['id'] as int;
    if (accounts.isNotEmpty) {
      accountId ??= accounts.first['id'] as int;
      currency = '${accounts.first['currency']}';
    }
    setState(() {});
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fx = FxRateService(widget.db);
    if (!ops.contains(operation)) operation = ops.first;
    return Scaffold(
      appBar: AppBar(title: const Text('Qarz harakati qo‘shish')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'they_owe_me', label: Text('Menga qarz')),
              ButtonSegment(value: 'i_owe', label: Text('Men qarzdor')),
            ],
            selected: {direction},
            onSelectionChanged: (s)=>setState((){direction = s.first; operation = ops.first;}),
          ),
          const SizedBox(height: 8),
          ListTile(
            tileColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text('Sana'),
            subtitle: Text(DateFormat('yyyy-MM-dd').format(date)),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                firstDate: DateTime(2026,1,1),
                lastDate: DateTime(2100,12,31),
                initialDate: date,
              );
              if (d != null) setState(()=>date = d);
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: personId,
            items: persons.map((e)=>DropdownMenuItem(value: e['id'] as int, child: Text('${e['name']}'))).toList(),
            onChanged: (v)=>setState(()=>personId = v),
            decoration: const InputDecoration(labelText: 'Shaxs', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: operation,
            items: ops.map((e)=>DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v)=>setState(()=>operation = v ?? ops.first),
            decoration: const InputDecoration(labelText: 'Operatsiya', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: accountId,
            items: accounts.map((e)=>DropdownMenuItem(value: e['id'] as int, child: Text('${e['name']} • ${e['currency']}'))).toList(),
            onChanged: (v){
              final row = accounts.firstWhere((a)=>a['id']==v);
              setState(() {
                accountId = v;
                currency = '${row['currency']}';
              });
            },
            decoration: const InputDecoration(labelText: 'Hisob', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Summa ($currency)', border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Izoh', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text.replaceAll(',', ''));
              if (amount == null || amount <= 0 || personId == null || accountId == null) return;
              double? rate;
              double amountUzs;
              if (currency == 'USD') {
                rate = await fx.getRateOnOrBefore(ymd(date));
                if (rate == null || rate <= 0) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('USD kurs topilmadi')));
                  return;
                }
                amountUzs = amount * rate;
              } else {
                amountUzs = amount;
              }
              await widget.db.addDebt(DebtEntity(
                entryDate: ymd(date),
                personId: personId!,
                direction: direction,
                operation: operation,
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
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
  }
}
