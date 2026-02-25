import 'package:intl/intl.dart';

final _f = NumberFormat('#,##0.##', 'en_US');

String money(num v, {String suffix = " so‘m"}) => '${_f.format(v)}$suffix';
String plainNum(num v) => _f.format(v);

String ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
String ym(DateTime d) => DateFormat('yyyy-MM').format(DateTime(d.year, d.month, 1));

bool isAllowedDate(DateTime d) => !d.isBefore(DateTime(2026, 1, 1));
