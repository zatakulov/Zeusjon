class AccountEntity {
  final int? id;
  final String name;
  final String kind; // cash/card
  final String currency; // UZS/USD
  final String? bankName;
  final int isActive;

  const AccountEntity({
    this.id,
    required this.name,
    required this.kind,
    required this.currency,
    this.bankName,
    this.isActive = 1,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'kind': kind,
        'currency': currency,
        'bank_name': bankName,
        'is_active': isActive,
      };

  factory AccountEntity.fromMap(Map<String, Object?> m) => AccountEntity(
        id: m['id'] as int?,
        name: m['name'] as String,
        kind: m['kind'] as String,
        currency: m['currency'] as String,
        bankName: m['bank_name'] as String?,
        isActive: (m['is_active'] as int?) ?? 1,
      );
}

class TxEntity {
  final int? id;
  final String entryDate; // yyyy-MM-dd
  final String entryType; // income/expense
  final int? incomeTypeId;
  final int? expenseCategoryId;
  final int? tagProjectId;
  final int accountId;
  final String currency;
  final double amount;
  final double? amountUzs;
  final double? fxRate;
  final String? note;

  const TxEntity({
    this.id,
    required this.entryDate,
    required this.entryType,
    this.incomeTypeId,
    this.expenseCategoryId,
    this.tagProjectId,
    required this.accountId,
    required this.currency,
    required this.amount,
    this.amountUzs,
    this.fxRate,
    this.note,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'entry_date': entryDate,
        'entry_type': entryType,
        'income_type_id': incomeTypeId,
        'expense_category_id': expenseCategoryId,
        'tag_project_id': tagProjectId,
        'account_id': accountId,
        'currency': currency,
        'amount': amount,
        'amount_uzs': amountUzs,
        'fx_rate': fxRate,
        'note': note,
      };
}

class DebtEntity {
  final int? id;
  final String entryDate;
  final int personId;
  final String direction; // they_owe_me / i_owe
  final String operation; // berildi/qaytarildi/oldim/qaytardim
  final int accountId;
  final String currency;
  final double amount;
  final double? amountUzs;
  final double? fxRate;
  final String? note;

  const DebtEntity({
    this.id,
    required this.entryDate,
    required this.personId,
    required this.direction,
    required this.operation,
    required this.accountId,
    required this.currency,
    required this.amount,
    this.amountUzs,
    this.fxRate,
    this.note,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'entry_date': entryDate,
        'person_id': personId,
        'direction': direction,
        'operation': operation,
        'account_id': accountId,
        'currency': currency,
        'amount': amount,
        'amount_uzs': amountUzs,
        'fx_rate': fxRate,
        'note': note,
      };
}
