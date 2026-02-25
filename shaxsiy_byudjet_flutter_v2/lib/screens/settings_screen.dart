import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/app_db.dart';
import '../models/entities.dart';
import '../services/export_backup_service.dart';
import '../services/fx_rate_service.dart';
import '../services/pin_auth_service.dart';
import '../utils/date_money.dart';

class SettingsScreen extends StatefulWidget {
  final AppDb db;
  final PinAuthService auth;
  const SettingsScreen({super.key, required this.db, required this.auth});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _manualRateCtrl = TextEditingController();
  DateTime rateDate = DateTime.now().isBefore(DateTime(2026, 1, 1)) ? DateTime(2026,1,1) : DateTime.now();

  @override
  void dispose() {
    _manualRateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fx = FxRateService(widget.db);
    final ex = ExportBackupService(widget.db);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('Sozlamalar / Ro‘yxatlar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        _SectionCard(
          title: 'Dinamik ro‘yxatlar',
          child: Column(
            children: [
              _AddLookupRow(db: widget.db, table: 'lists_income_types', label: 'Daromad turi'),
              _AddLookupRow(db: widget.db, table: 'lists_expense_categories', label: 'Xarajat turkumi'),
              _AddLookupRow(db: widget.db, table: 'lists_tags_projects', label: 'Tag / Loyiha'),
              _AddLookupRow(db: widget.db, table: 'persons', label: 'Shaxs'),
            ],
          ),
        ),

        const SizedBox(height: 8),
        _SectionCard(
          title: 'Hisoblar (naqd/karta, bir nechta bank)',
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () async {
                    final result = await showDialog<AccountEntity>(
                      context: context,
                      builder: (_) => const _AddAccountDialog(),
                    );
                    if (result != null) {
                      await widget.db.addAccount(result);
                      if (mounted) setState(() {});
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Hisob qo‘shish'),
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder(
                future: widget.db.getAccounts(),
                builder: (context, snap) {
                  final rows = snap.data ?? <AccountEntity>[];
                  return Column(
                    children: rows.map((a) => ListTile(
                      dense: true, contentPadding: EdgeInsets.zero,
                      title: Text(a.name),
                      subtitle: Text('${a.kind == 'cash' ? 'Naqd' : 'Karta'} • ${a.currency}${a.bankName != null ? ' • ${a.bankName}' : ''}'),
                    )).toList(),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),
        _SectionCard(
          title: 'USD kurslari (manual + auto skeleton)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2026,1,1),
                      lastDate: DateTime(2100,12,31),
                      initialDate: rateDate,
                    );
                    if (d != null) setState(() => rateDate = d);
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: Text(DateFormat('yyyy-MM-dd').format(rateDate)),
                ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _manualRateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'USD kursi (UZS)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () async {
                    final r = double.tryParse(_manualRateCtrl.text.replaceAll(',', ''));
                    if (r == null || r <= 0) return;
                    await fx.setManualRate(ymd(rateDate), r);
                    _manualRateCtrl.clear();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kurs saqlandi')));
                  },
                  child: const Text('Saqlash'),
                ),
              ]),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: () async {
                  final n = await fx.fetchAndStoreRecentUsdRates();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Auto-update tugadi. Yangi kurslar: $n ta')));
                },
                icon: const Icon(Icons.download),
                label: const Text('CBU kurslarini auto-update (skeleton)'),
              ),
              const SizedBox(height: 8),
              FutureBuilder<double?>(
                future: fx.getRateOnOrBefore(ymd(rateDate)),
                builder: (context, snap) => Text('Tanlangan sana uchun oxirgi kurs: ${snap.data ?? "yo‘q"}'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),
        _SectionCard(
          title: 'Oy boshidagi qoldiqlar (hisoblar bo‘yicha)',
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () async {
                final month = await _pickMonth(context, DateTime.now().year < 2026 ? DateTime(2026,1,1) : DateTime.now());
                if (month == null || !mounted) return;
                await showDialog(context: context, builder: (_) => _OpeningBalanceDialog(db: widget.db, month: DateTime(month.year, month.month, 1)));
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.account_balance_wallet),
              label: const Text('Qoldiq kiritish'),
            ),
          ),
        ),

        const SizedBox(height: 8),
        _SectionCard(
          title: 'Export / Backup / Restore',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () async {
                  final m = await _pickMonth(context, DateTime.now().year < 2026 ? DateTime(2026,1,1) : DateTime.now());
                  if (m == null) return;
                  final f = await ex.exportTransactionsCsv(ym(m));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV saqlandi: ${f.path}')));
                },
                icon: const Icon(Icons.table_view),
                label: const Text('CSV eksport'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final f = await ex.backupJson();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup saqlandi: ${f.path}')));
                },
                icon: const Icon(Icons.backup),
                label: const Text('JSON backup'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Restore uchun file picker qo‘shing (bu skeletonda UI kiritilmadi, servis tayyor).'),
                  ));
                },
                icon: const Icon(Icons.restore),
                label: const Text('Restore (skeleton)'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),
        _SectionCard(
          title: 'PIN / Biometrik himoya',
          child: FutureBuilder<bool>(
            future: widget.auth.isPinEnabled(),
            builder: (context, snap) {
              final enabled = snap.data ?? false;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PIN holati: ${enabled ? "Yoqilgan" : "O‘chirilgan"}'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton.icon(
                      onPressed: () async {
                        await widget.auth.setupPinFlow(context);
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(Icons.lock),
                      label: const Text('PIN o‘rnatish'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await widget.auth.disablePin();
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(Icons.lock_open),
                      label: const Text('PIN o‘chirish'),
                    ),
                  ]),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<DateTime?> _pickMonth(BuildContext context, DateTime initial) async {
    int y = initial.year < 2026 ? 2026 : initial.year;
    int m = initial.month;
    return showDialog<DateTime>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Oy tanlang'),
        content: StatefulBuilder(builder: (context, setS) => Row(children: [
          Expanded(child: DropdownButtonFormField<int>(
            value: y,
            items: List.generate(15, (i)=>2026+i).map((e)=>DropdownMenuItem(value: e, child: Text('$e'))).toList(),
            onChanged: (v)=>setS(()=>y = v ?? y),
          )),
          const SizedBox(width: 8),
          Expanded(child: DropdownButtonFormField<int>(
            value: m,
            items: List.generate(12, (i)=>i+1).map((e)=>DropdownMenuItem(value: e, child: Text(e.toString().padLeft(2,'0')))).toList(),
            onChanged: (v)=>setS(()=>m = v ?? m),
          )),
        ])),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Bekor')),
          FilledButton(onPressed: ()=>Navigator.pop(context, DateTime(y,m,1)), child: const Text('Tanlash')),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          child,
        ]),
      ),
    );
  }
}

class _AddLookupRow extends StatefulWidget {
  final AppDb db;
  final String table;
  final String label;
  const _AddLookupRow({required this.db, required this.table, required this.label});

  @override
  State<_AddLookupRow> createState() => _AddLookupRowState();
}

class _AddLookupRowState extends State<_AddLookupRow> {
  final ctrl = TextEditingController();
  int _refresh = 0;

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      key: ValueKey('${widget.table}_$_refresh'),
      future: widget.db.listLookup(widget.table),
      builder: (context, snap) {
        final rows = snap.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: TextField(controller: ctrl, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Yangi qiymat'))),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  await widget.db.addLookup(widget.table, ctrl.text.trim());
                  ctrl.clear();
                  setState(() => _refresh++);
                },
                child: const Text('Qo‘sh'),
              ),
            ]),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: rows.map((e) => Chip(label: Text('${e["name"]}'))).toList(),
            ),
            const Divider(height: 20),
          ],
        );
      },
    );
  }
}

class _AddAccountDialog extends StatefulWidget {
  const _AddAccountDialog();

  @override
  State<_AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<_AddAccountDialog> {
  final nameCtrl = TextEditingController();
  final bankCtrl = TextEditingController();
  String kind = 'card';
  String currency = 'UZS';

  @override
  void dispose() {
    nameCtrl.dispose();
    bankCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hisob qo‘shish'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Hisob nomi')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: kind,
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Naqd')),
              DropdownMenuItem(value: 'card', child: Text('Karta')),
            ],
            onChanged: (v)=>setState(()=>kind = v ?? 'card'),
            decoration: const InputDecoration(labelText: 'Turi'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: currency,
            items: const [
              DropdownMenuItem(value: 'UZS', child: Text('UZS')),
              DropdownMenuItem(value: 'USD', child: Text('USD')),
            ],
            onChanged: (v)=>setState(()=>currency = v ?? 'UZS'),
            decoration: const InputDecoration(labelText: 'Valyuta'),
          ),
          const SizedBox(height: 8),
          TextField(controller: bankCtrl, decoration: const InputDecoration(labelText: 'Bank nomi (karta uchun optional)')),
        ]),
      ),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Bekor')),
        FilledButton(
          onPressed: (){
            final name = nameCtrl.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(context, AccountEntity(
              name: name,
              kind: kind,
              currency: currency,
              bankName: bankCtrl.text.trim().isEmpty ? null : bankCtrl.text.trim(),
            ));
          },
          child: const Text('Saqlash'),
        ),
      ],
    );
  }
}

class _OpeningBalanceDialog extends StatefulWidget {
  final AppDb db;
  final DateTime month;
  const _OpeningBalanceDialog({required this.db, required this.month});

  @override
  State<_OpeningBalanceDialog> createState() => _OpeningBalanceDialogState();
}

class _OpeningBalanceDialogState extends State<_OpeningBalanceDialog> {
  final Map<int, TextEditingController> ctrls = {};
  List<Map<String, Object?>> accounts = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    accounts = await widget.db.db.rawQuery('SELECT id,name,currency,kind FROM accounts WHERE is_active=1 ORDER BY name');
    final existing = await widget.db.getOpeningBalances(ym(widget.month));
    final exMap = {for (final r in existing) r['account_id'] as int: ((r['amount'] as num?) ?? 0).toDouble()};
    for (final a in accounts) {
      final id = a['id'] as int;
      ctrls[id] = TextEditingController(text: (exMap[id] ?? 0).toString());
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    for (final c in ctrls.values) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Oy boshi qoldiq • ${ym(widget.month)}'),
      content: SizedBox(
        width: 430,
        child: loading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
          child: Column(
            children: accounts.map((a) {
              final id = a['id'] as int;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: TextField(
                  controller: ctrls[id],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${a['name']} (${a['currency']})',
                    border: const OutlineInputBorder(),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Bekor')),
        FilledButton(
          onPressed: () async {
            for (final a in accounts) {
              final id = a['id'] as int;
              final v = double.tryParse((ctrls[id]?.text ?? '0').replaceAll(',', '')) ?? 0;
              await widget.db.setOpeningBalance(ym(widget.month), id, v);
            }
            if (!mounted) return;
            Navigator.pop(context);
          },
          child: const Text('Saqlash'),
        ),
      ],
    );
  }
}
