import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/entities.dart';

class AppDb {
  Database? _db;
  Database get db {
    final d = _db;
    if (d == null) throw StateError('DB init qilinmagan');
    return d;
  }

  Future<void> init() async {
    final path = p.join(await getDatabasesPath(), 'budget_app_v2.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await _createSchema(db);
        await _seedDefaults(db);
      },
    );
  }

  Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('PRAGMA foreign_keys = ON');

    await db.execute('''
      CREATE TABLE lists_income_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE lists_expense_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE lists_tags_projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE persons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL UNIQUE,
        phone TEXT,
        note TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        kind TEXT NOT NULL CHECK(kind IN ('cash','card')),
        currency TEXT NOT NULL CHECK(currency IN ('UZS','USD')),
        bank_name TEXT,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE fx_rates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rate_date TEXT NOT NULL,
        base_currency TEXT NOT NULL DEFAULT 'USD',
        quote_currency TEXT NOT NULL DEFAULT 'UZS',
        rate REAL NOT NULL CHECK(rate > 0),
        source TEXT NOT NULL DEFAULT 'manual',
        UNIQUE(rate_date, base_currency, quote_currency)
      )
    ''');
    await db.execute('''
      CREATE TABLE opening_balances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        month_key TEXT NOT NULL,
        account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
        amount REAL NOT NULL DEFAULT 0,
        UNIQUE(month_key, account_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_date TEXT NOT NULL,
        entry_type TEXT NOT NULL CHECK(entry_type IN ('income','expense')),
        income_type_id INTEGER REFERENCES lists_income_types(id),
        expense_category_id INTEGER REFERENCES lists_expense_categories(id),
        tag_project_id INTEGER REFERENCES lists_tags_projects(id),
        account_id INTEGER NOT NULL REFERENCES accounts(id),
        currency TEXT NOT NULL CHECK(currency IN ('UZS','USD')),
        amount REAL NOT NULL CHECK(amount > 0),
        amount_uzs REAL,
        fx_rate REAL,
        note TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('CREATE INDEX idx_tx_date ON transactions(entry_date)');
    await db.execute('CREATE INDEX idx_tx_tag ON transactions(tag_project_id)');
    await db.execute('''
      CREATE TABLE debt_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_date TEXT NOT NULL,
        person_id INTEGER NOT NULL REFERENCES persons(id),
        direction TEXT NOT NULL CHECK(direction IN ('they_owe_me','i_owe')),
        operation TEXT NOT NULL,
        account_id INTEGER NOT NULL REFERENCES accounts(id),
        currency TEXT NOT NULL CHECK(currency IN ('UZS','USD')),
        amount REAL NOT NULL CHECK(amount > 0),
        amount_uzs REAL,
        fx_rate REAL,
        note TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<void> _seedDefaults(DatabaseExecutor db) async {
    for (final v in ['Ish haqi', 'Qarz', 'Boshqa']) {
      await db.insert('lists_income_types', {'name': v});
    }
    for (final v in ['Oziq-ovqat', 'Transport', 'Kommunal', 'Ijara', 'Sog‘liq', 'Ta’lim', 'Ko‘ngilochar', 'Boshqa']) {
      await db.insert('lists_expense_categories', {'name': v});
    }
    for (final v in ['Shaxsiy', 'Uy xarajatlari', 'Loyiha A', 'Safar']) {
      await db.insert('lists_tags_projects', {'name': v});
    }
    for (final v in ['Ali', 'Vali']) {
      await db.insert('persons', {'full_name': v});
    }
    await db.insert('accounts', {'name': 'Naqd UZS', 'kind': 'cash', 'currency': 'UZS'});
    await db.insert('accounts', {'name': 'Naqd USD', 'kind': 'cash', 'currency': 'USD'});
    await db.insert('accounts', {'name': 'Uzcard NBU', 'kind': 'card', 'currency': 'UZS', 'bank_name': 'NBU'});
    await db.insert('accounts', {'name': 'Humo Ipak', 'kind': 'card', 'currency': 'UZS', 'bank_name': 'Ipak'});
  }

  // ---------- Generic lookups ----------
  Future<List<Map<String, Object?>>> listLookup(String table, {String nameCol = 'name'}) async {
    final nameExpr = table == 'persons' ? 'full_name as name' : '$nameCol as name';
    return db.rawQuery('SELECT id, $nameExpr FROM $table ORDER BY 2');
  }

  Future<int> addLookup(String table, String value) async {
    if (value.trim().isEmpty) return 0;
    return db.insert(
      table,
      table == 'persons' ? {'full_name': value.trim()} : {'name': value.trim()},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // ---------- Accounts ----------
  Future<List<AccountEntity>> getAccounts() async {
    final rows = await db.query('accounts', where: 'is_active=1', orderBy: 'name');
    return rows.map(AccountEntity.fromMap).toList();
  }

  Future<int> addAccount(AccountEntity a) async {
    return db.insert('accounts', a.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // ---------- FX ----------
  Future<void> upsertFxRate(String date, double rate, {String source = 'manual'}) async {
    await db.insert(
      'fx_rates',
      {'rate_date': date, 'rate': rate, 'source': source},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<double?> getFxRateOnOrBefore(String date) async {
    final rows = await db.rawQuery('''
      SELECT rate FROM fx_rates
      WHERE rate_date <= ?
      ORDER BY rate_date DESC
      LIMIT 1
    ''', [date]);
    if (rows.isEmpty) return null;
    return (rows.first['rate'] as num).toDouble();
  }

  // ---------- Opening balances ----------
  Future<void> setOpeningBalance(String monthKey, int accountId, double amount) async {
    await db.insert(
      'opening_balances',
      {'month_key': monthKey, 'account_id': accountId, 'amount': amount},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> getOpeningBalances(String monthKey) {
    return db.rawQuery('''
      SELECT ob.account_id, ob.amount, a.name, a.currency, a.kind
      FROM opening_balances ob
      JOIN accounts a ON a.id = ob.account_id
      WHERE ob.month_key = ?
      ORDER BY a.name
    ''', [monthKey]);
  }

  // ---------- Transactions ----------
  Future<int> addTransaction(TxEntity t) async {
    // application-level validation for 2026+
    if (DateTime.parse(t.entryDate).isBefore(DateTime(2026, 1, 1))) {
      throw Exception('Sana 2026-01-01 dan oldin bo‘lishi mumkin emas');
    }
    return db.insert('transactions', t.toMap());
  }

  Future<List<Map<String, Object?>>> getTransactionsByMonth(String monthKey) async {
    return db.rawQuery('''
      SELECT t.*, 
             a.name as account_name,
             li.name as income_type_name,
             le.name as expense_category_name,
             lt.name as tag_name
      FROM transactions t
      JOIN accounts a ON a.id = t.account_id
      LEFT JOIN lists_income_types li ON li.id = t.income_type_id
      LEFT JOIN lists_expense_categories le ON le.id = t.expense_category_id
      LEFT JOIN lists_tags_projects lt ON lt.id = t.tag_project_id
      WHERE substr(t.entry_date,1,7)=?
      ORDER BY t.entry_date DESC, t.id DESC
    ''', [monthKey]);
  }

  // ---------- Debts ----------
  Future<int> addDebt(DebtEntity d) async {
    if (DateTime.parse(d.entryDate).isBefore(DateTime(2026, 1, 1))) {
      throw Exception('Sana 2026-01-01 dan oldin bo‘lishi mumkin emas');
    }
    return db.insert('debt_entries', d.toMap());
  }

  Future<List<Map<String, Object?>>> debtOutstanding(String direction) async {
    if (direction == 'they_owe_me') {
      return db.rawQuery('''
        SELECT p.full_name as person,
               SUM(CASE 
                     WHEN de.operation='berildi' THEN COALESCE(de.amount_uzs,0)
                     WHEN de.operation='qaytarildi' THEN -COALESCE(de.amount_uzs,0)
                     ELSE 0 END) as balance_uzs
        FROM debt_entries de
        JOIN persons p ON p.id = de.person_id
        WHERE de.direction='they_owe_me'
        GROUP BY de.person_id
        HAVING ABS(balance_uzs) > 0.0001
        ORDER BY p.full_name
      ''');
    }
    return db.rawQuery('''
      SELECT p.full_name as person,
             SUM(CASE 
                   WHEN de.operation='oldim' THEN COALESCE(de.amount_uzs,0)
                   WHEN de.operation='qaytardim' THEN -COALESCE(de.amount_uzs,0)
                   ELSE 0 END) as balance_uzs
      FROM debt_entries de
      JOIN persons p ON p.id = de.person_id
      WHERE de.direction='i_owe'
      GROUP BY de.person_id
      HAVING ABS(balance_uzs) > 0.0001
      ORDER BY p.full_name
    ''');
  }

  // ---------- Reports ----------
  Future<Map<String, double>> monthlyTotals(String monthKey) async {
    final rows = await db.rawQuery('''
      SELECT entry_type, SUM(COALESCE(amount_uzs,0)) as s
      FROM transactions
      WHERE substr(entry_date,1,7)=?
      GROUP BY entry_type
    ''', [monthKey]);

    double income = 0, expense = 0;
    for (final r in rows) {
      if (r['entry_type'] == 'income') {
        income = ((r['s'] as num?) ?? 0).toDouble();
      } else if (r['entry_type'] == 'expense') {
        expense = ((r['s'] as num?) ?? 0).toDouble();
      }
    }
    return {'income': income, 'expense': expense, 'net': income - expense};
  }

  Future<List<Map<String, Object?>>> expenseShareByCategory(String monthKey) async {
    return db.rawQuery('''
      SELECT COALESCE(le.name, 'Boshqa') as label, SUM(COALESCE(t.amount_uzs,0)) as amount
      FROM transactions t
      LEFT JOIN lists_expense_categories le ON le.id=t.expense_category_id
      WHERE substr(t.entry_date,1,7)=? AND t.entry_type='expense'
      GROUP BY COALESCE(le.name,'Boshqa')
      ORDER BY amount DESC
    ''', [monthKey]);
  }

  Future<List<Map<String, Object?>>> incomeShareByType(String monthKey) async {
    return db.rawQuery('''
      SELECT COALESCE(li.name, 'Boshqa') as label, SUM(COALESCE(t.amount_uzs,0)) as amount
      FROM transactions t
      LEFT JOIN lists_income_types li ON li.id=t.income_type_id
      WHERE substr(t.entry_date,1,7)=? AND t.entry_type='income'
      GROUP BY COALESCE(li.name,'Boshqa')
      ORDER BY amount DESC
    ''', [monthKey]);
  }

  Future<List<Map<String, Object?>>> tagSummary(String startMonth, String endMonth) async {
    return db.rawQuery('''
      SELECT COALESCE(lt.name, 'Tag berilmagan') as tag_name,
             SUM(CASE WHEN t.entry_type='income' THEN COALESCE(t.amount_uzs,0) ELSE 0 END) as income,
             SUM(CASE WHEN t.entry_type='expense' THEN COALESCE(t.amount_uzs,0) ELSE 0 END) as expense,
             SUM(CASE WHEN t.entry_type='income' THEN COALESCE(t.amount_uzs,0) ELSE -COALESCE(t.amount_uzs,0) END) as net
      FROM transactions t
      LEFT JOIN lists_tags_projects lt ON lt.id=t.tag_project_id
      WHERE substr(t.entry_date,1,7) >= ? AND substr(t.entry_date,1,7) <= ?
      GROUP BY COALESCE(lt.name,'Tag berilmagan')
      ORDER BY expense DESC, income DESC
    ''', [startMonth, endMonth]);
  }

  Future<List<Map<String, Object?>>> yearMonthlyLines(int year) async {
    return db.rawQuery('''
      WITH months(m) AS (
        VALUES ('01'),('02'),('03'),('04'),('05'),('06'),
               ('07'),('08'),('09'),('10'),('11'),('12')
      )
      SELECT m as month,
             COALESCE(SUM(CASE WHEN t.entry_type='income' THEN COALESCE(t.amount_uzs,0) END),0) as income,
             COALESCE(SUM(CASE WHEN t.entry_type='expense' THEN COALESCE(t.amount_uzs,0) END),0) as expense
      FROM months
      LEFT JOIN transactions t ON substr(t.entry_date,1,4)=? AND substr(t.entry_date,6,2)=m
      GROUP BY m
      ORDER BY m
    ''', ['$year']);
  }

  // ---------- Backup/Restore ----------
  Future<Map<String, Object?>> exportAllAsJson() async {
    final tables = [
      'lists_income_types',
      'lists_expense_categories',
      'lists_tags_projects',
      'persons',
      'accounts',
      'fx_rates',
      'opening_balances',
      'transactions',
      'debt_entries',
    ];
    final out = <String, Object?>{};
    for (final t in tables) {
      out[t] = await db.query(t);
    }
    return out;
  }

  Future<void> restoreFromJson(Map<String, dynamic> data) async {
    await db.transaction((txn) async {
      for (final t in [
        'debt_entries','transactions','opening_balances','fx_rates',
        'accounts','persons','lists_tags_projects','lists_expense_categories','lists_income_types'
      ]) {
        await txn.delete(t);
      }
      for (final entry in data.entries) {
        final rows = (entry.value as List).cast<Map>();
        for (final row in rows) {
          await txn.insert(entry.key, Map<String, Object?>.from(row));
        }
      }
    });
  }
}
