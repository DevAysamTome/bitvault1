import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CurrencyRateProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  double? _rate;
  double? get rate => _rate;

  // عملة افتراضية
  String _fiatSymbol = "USD";
  String get fiatSymbol => _fiatSymbol;

  // رابط العلم الافتراضي
  String? _fiatFlagUrl =
      "https://firebasestorage.googleapis.com/v0/b/modernnewwallet.appspot.com/o/cms_uploads%2Fcurrenices%2F1693049562797000%2Fus.png?alt=media&token=f19d64b5-2ea2-43b4-afe9-1f69337c87b4";
  String? get fiatFlagUrl => _fiatFlagUrl;

  Future<void> fetchRate({
    required String currencySymbol,
    String? flagUrl,
  }) async {
    _fiatSymbol = currencySymbol;

    if (flagUrl != null && flagUrl.isNotEmpty) {
      _fiatFlagUrl = flagUrl;
    }

    _rate = null;
    _isLoading = true;
    notifyListeners();

    try {
      final url = Uri.parse(
          "https://api.coinbase.com/v2/prices/btc-$currencySymbol/spot");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final parsed = data['data'];
        if (parsed != null && parsed['amount'] != null) {
          final amountStr = parsed['amount'].toString();
          final double? amountDouble = double.tryParse(amountStr);
          if (amountDouble != null) {
            _rate = amountDouble;
          }
        }
      }
      // لا نطبع شيئًا في حال عدم نجاح الطلب
      // يمكن هنا التعامل بصمت أو إطلاق Exception حسب الحاجة
    } catch (e) {
      // أيضًا لا نطبع أي شيء في حال الخطأ
      // يمكن إطلاق Exception أو تجاهل الخطأ بحسب ما يلزم التطبيق
    }

    _isLoading = false;
    notifyListeners();
  }
}
