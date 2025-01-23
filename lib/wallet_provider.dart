import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WalletProvider extends ChangeNotifier {
  // ----------------------------------------
  // 1) أنواع الـ BIP
  // ----------------------------------------
  static const String bip44 = 'BIP44';
  static const String bip49 = 'BIP49';
  static const String bip84 = 'BIP84';

  // الوضع الافتراضي: BIP44
  String _preferredBipType = bip44;
  String get preferredBipType => _preferredBipType;

  void setPreferredBipType(String newType) {
    _preferredBipType = newType;
    notifyListeners();
  }

  // ----------------------------------------
  // 2) الوحدة الحالية (BTC أو SAT)
  // ----------------------------------------
  String _currentUnit = "BTC";
  String get currentUnit => _currentUnit;

  void setUnit(String newUnit) {
    _currentUnit = newUnit; // "BTC" or "SAT"
    notifyListeners();
  }

  // ----------------------------------------
  // 3) بيانات المحفظة من الـ API
  // ----------------------------------------
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Map<String, dynamic>? _walletData;
  Map<String, dynamic>? get walletData => _walletData;

  String? _apiStatus;
  String? get apiStatus => _apiStatus;

  String? _apiMessage;
  String? get apiMessage => _apiMessage;

  String? _apiTimestamp;
  String? get apiTimestamp => _apiTimestamp;

  // الحقول الجديدة (إن أردت حفظها)
  String? _apiPrimaryType;
  String? get apiPrimaryType => _apiPrimaryType;

  int? _apiScanDurationMs;
  int? get apiScanDurationMs => _apiScanDurationMs;

  // نخزن الـ mnemonic المستخدم حالياً كي نستعمله لاحقاً في التحديث كل 7 ثوانٍ
  String? _lastMnemonic;
  String? get lastMnemonic => _lastMnemonic;

  Future<void> fetchWalletData({
    required String mnemonic,
    String passphrase = '',
  }) async {
    _isLoading = true;
    notifyListeners();

    // نخزن العبارة السرية محلياً
    _lastMnemonic = mnemonic;

    try {
      final uri = Uri.parse('https://generate-wallet.vercel.app/api/scan');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "mnemonic": mnemonic,
          "passphrase": passphrase.isEmpty ? null : passphrase,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResp = json.decode(response.body);

        _apiStatus = jsonResp['status'];
        _apiMessage = jsonResp['message'];
        _apiTimestamp = jsonResp['timestamp'];

        // الحقول الإضافية الجديدة
        _apiPrimaryType = jsonResp['primaryType'];
        _apiScanDurationMs = jsonResp['scanDurationMs'];

        // تخزين البيانات الرئيسية
        _walletData = jsonResp['result'];

        // ـــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــ
        // فقط لطباعة معلومات كل المسارات التي يعيدها السيرفر إن كانت متوفرة
        // تم حذف الطباعة إلى الـ console منعاً لأي مخرجات
        // ـــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــ
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      // تم حذف أي طباعة للخطأ إلى الـ console
    }

    _isLoading = false;
    notifyListeners();
  }

  // ----------------------------------------
  // 4) دوال الرصيد
  // ----------------------------------------
  /// انتبه هنا أنّه بدلًا من 'bip44_legacy' سنتعامل مع 'BIP44' وهكذا
  final Map<String, String> _bipTypeMapping = {
    bip44: 'BIP44',
    bip49: 'BIP49',
    bip84: 'BIP84',
  };

  int getBalanceInSatoshi(String bipType) {
    if (_walletData == null) return 0;

    final mappedKey = _bipTypeMapping[bipType];
    final dataObj = _walletData?['data']?[mappedKey];
    if (dataObj == null) return 0;

    int totalSat = 0;

    // ----- receive -----
    final receive = dataObj['receive'];
    if (receive is Map) {
      final usedArr = receive['used'];
      if (usedArr is List) {
        for (var addr in usedArr) {
          final bal = addr['totalBalance'];
          if (bal is int) totalSat += bal;
        }
      }
      final fresh = receive['fresh'];
      if (fresh is Map) {
        final bal = fresh['totalBalance'];
        if (bal is int) totalSat += bal;
      }
    }

    // ----- change -----
    final change = dataObj['change'];
    if (change is Map) {
      final usedArr = change['used'];
      if (usedArr is List) {
        for (var addr in usedArr) {
          final bal = addr['totalBalance'];
          if (bal is int) totalSat += bal;
        }
      }
      final fresh = change['fresh'];
      if (fresh is Map) {
        final bal = fresh['totalBalance'];
        if (bal is int) totalSat += bal;
      }
    }

    return totalSat;
  }

  double getBalanceInBTC(String bipType) {
    final satoshi = getBalanceInSatoshi(bipType);
    return satoshi / 100000000.0;
  }

  String getDisplayBalance(String bipType) {
    if (_walletData == null) {
      return _currentUnit == "BTC" ? "0.00000000 BTC" : "0 SATS";
    }

    if (_currentUnit == "BTC") {
      final btcValue = getBalanceInBTC(bipType);
      return "${btcValue.toStringAsFixed(8)} BTC";
    } else {
      final satValue = getBalanceInSatoshi(bipType);
      return "$satValue SATS";
    }
  }

  // ----------------------------------------
  // 5) بعض الدوال المساعدة
  // ----------------------------------------
  Map<String, dynamic>? get currentBipStats => null;

  String? get currentFreshAddress {
    if (_walletData == null) return null;

    final mappedKey = _bipTypeMapping[_preferredBipType];
    final dataObj = _walletData?['data']?[mappedKey];
    if (dataObj == null) return null;

    final freshAddr = dataObj['receive']?['fresh']?['address'];
    if (freshAddr is String) return freshAddr;
    return null;
  }

  get errorMessage => null;
}
