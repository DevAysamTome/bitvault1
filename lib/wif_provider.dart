import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// مزوّد مسؤول عن التعامل مع الـ WIF واستدعاء الـ API
class WifProvider extends ChangeNotifier {
  /// حقول للاحتفاظ بالبيانات
  /// يمكنك حفظ أكثر من عنوان (bip44, bip49, bip84) أو حفظ ما يهمّك فقط
  String? bip44Address;
  String? bip49Address;
  String? bip84Address;

  bool? isCompressed;
  String? keyUsed;

  /// أي حقل إضافي قد تحتاجه لاحقًا
  Map<String, dynamic>? fullResponse;

  /// لاستعمالات واجهتك: إذا أردت عرض عنوان "رئيسي" واحد، تختار مثلاً bip84Address
  String? get mainAddress => bip84Address;

  Future<void> fetchWifInfo(String wif) async {
    try {
      final uri = Uri.parse('https://generate-wallet.vercel.app/api/wif');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'wif': wif}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        debugPrint('=== Raw WIF response ===');
        debugPrint(data.toString());

        // التحقق من النجاح
        if (data['status'] == 'success') {
          // خزّن الاستجابة الكاملة في حال أردت المزيد
          fullResponse = data;

          final result = data['result'];
          if (result != null && result['wifResults'] is List) {
            final wifArr = result['wifResults'] as List;
            if (wifArr.isNotEmpty) {
              final firstObj = wifArr[0];

              // استخراج بعض الحقول التي قد تهمك
              keyUsed = firstObj['keyUsed'];
              isCompressed = firstObj['isCompressed'];

              // هنا يوجد كائن addresses يحوي bip44 / bip49 / bip84
              final addressesMap = firstObj['addresses'];
              if (addressesMap is Map) {
                final bip44Map = addressesMap['bip44'];
                final bip49Map = addressesMap['bip49'];
                final bip84Map = addressesMap['bip84'];

                if (bip44Map is Map) {
                  bip44Address = bip44Map['address'];
                }
                if (bip49Map is Map) {
                  bip49Address = bip49Map['address'];
                }
                if (bip84Map is Map) {
                  bip84Address = bip84Map['address'];
                }
              }

              notifyListeners();
              return; // نجحنا وعبّأنا كل شيء
            }
          }
          debugPrint("No valid wifResults found in the response.");
        } else {
          debugPrint("API returned non-success status: ${data['status']}");
          debugPrint("Message: ${data['message']}");
        }
      } else {
        debugPrint(
            'Failed to fetch WIF info. HTTP status: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('Error while fetching WIF info: $error');
    }

    // في حال الفشل، نجعل القيم فارغة
    bip44Address = null;
    bip49Address = null;
    bip84Address = null;
    isCompressed = null;
    keyUsed = null;
    fullResponse = null;
    notifyListeners();
  }
}
