import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/app_db.dart';

class FxRateService {
  final AppDb db;
  FxRateService(this.db);

  /// Eslatma:
  /// CBU endpoint formati vaqt o'tishi bilan o'zgarishi mumkin.
  /// Shu sabab parser TODO qilingan. Qo'lda kurs kiritish doimo fallback.
  Future<int> fetchAndStoreRecentUsdRates() async {
    // TODO: real CBU endpointni moslab qo'ying.
    // Misol uchun JSON array format kelsa parse qilib `db.upsertFxRate(...)` chaqiriladi.
    // Hozir skelet sifatida 0 qaytaradi.
    return 0;
  }

  Future<void> setManualRate(String ymd, double rate) async {
    await db.upsertFxRate(ymd, rate, source: 'manual');
  }

  Future<double?> getRateOnOrBefore(String ymd) => db.getFxRateOnOrBefore(ymd);
}
