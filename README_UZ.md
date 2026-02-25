# Shaxsiy Byudjet Mobil Ilovasi (Flutter V2 - Kengaytirilgan paket)

Bu paket sizning Excel shabloningizni Android ilovaga aylantirish uchun **kengaytirilgan Flutter loyiha skeleti**:

## Qo‘shilgan funksiyalar (V2)
- ✅ SQLite saqlash (sqflite) uchun tayyor baza qatlami
- ✅ Dinamik ro‘yxatlar (daromad turi, xarajat turkumi, tag/loyiha, shaxslar)
- ✅ Ko‘p hisoblar: naqd (UZS/USD) + bir nechta bank kartalari
- ✅ Tranzaksiyalar, qarzlar, oy boshidagi qoldiq
- ✅ USD -> UZS normalizatsiya
- ✅ Hisobot servis (oylik/yillik/tag)
- ✅ CBU kurs auto-update uchun servis skeleti (http)
- ✅ Diagrammalar uchun `fl_chart` widget skeleti
- ✅ CSV/JSON eksport
- ✅ Backup / Restore (JSON)
- ✅ PIN + biometrik himoya skeleti
- ✅ 2026-yildan oldin sana kiritishni bloklash

## Muhim
- Bu paket **to‘liq tayyor arxitektura + kod skeleti**, lekin sizning qurilmangizda Flutter SDK bilan build qilish kerak.
- Bu muhitda APK compile qilinmadi.
- CBU kurs auto endpoint parser qismi real endpoint formatiga qarab moslanadi (servis ichida TODO belgisi bor).

## Ishga tushirish
1. Flutter SDK o‘rnating
2. Terminal:
   - `cd shaxsiy_byudjet_flutter_v2`
   - `flutter pub get`
   - `flutter run`
3. Android build:
   - `flutter build apk --release`

## Tavsiya etiladigan keyingi qadam
- UI polish
- Sync (Google Drive / Firebase optional)
- Recurring transactions
- Notification reminders
