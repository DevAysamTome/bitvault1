import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
// نستورد حزمة flutter_svg لعرض SVG
import 'package:flutter_svg/flutter_svg.dart';

class BackupMnemonicPage extends StatefulWidget {
  final String mnemonic;

  const BackupMnemonicPage({
    super.key,
    required this.mnemonic,
  });

  @override
  State<BackupMnemonicPage> createState() => _BackupMnemonicPageState();
}

class _BackupMnemonicPageState extends State<BackupMnemonicPage> {
  bool _isObscured = true; // لإخفاء/إظهار العبارة
  bool _copied = false;    // لإظهار "Copied!" عند النسخ

  /// قلب حالة الإظهار/الإخفاء
  void _toggleVisibility() {
    setState(() {
      _isObscured = !_isObscured;
    });
    HapticFeedback.lightImpact();
  }

  /// نسخ العبارة إلى الحافظة
  Future<void> _copyMnemonic() async {
    if (widget.mnemonic.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: widget.mnemonic));
    HapticFeedback.lightImpact();
    setState(() => _copied = true);

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    const mainColor = Color(0xFF3949AB);

    // تقسيم العبارة السرية إلى كلمات
    final splittedWords = widget.mnemonic.split(' ');

    // إعداد الأعمدة (كل عمود يحوي 4 كلمات عادةً)
    List<Widget> columns = [];
    for (int col = 0; col < 3; col++) {
      List<Widget> columnItems = [];
      for (int row = 0; row < 4; row++) {
        int index = col * 4 + row;
        if (index < splittedWords.length) {
          final word = splittedWords[index];
          columnItems.add(
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: Text(
                "${index + 1}. $word",
                style: const TextStyle(
                  fontSize: 16,  // حجم النص
                  color: Colors.black87,
                  height: 1.3,
                ),
              ),
            ),
          );
        }
      }
      columns.add(
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: columnItems,
          ),
        ),
      );
    }

    return Scaffold(
      // شريط علوي مع زر إغلاق وعنوان
      appBar: AppBar(
        title: const Text(
          'Wallet Export',
          style: TextStyle(
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: const Color(0xFFF1F4F8),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF1F4F8),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // (1) شريط تنبيه بارتفاع 50 بلون 0xFF3949AB
            Container(
              height: 50,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: mainColor,
                borderRadius: BorderRadius.circular(8),
              ),
              // لضبط المسافات الجانبية الداخلية حتى لا تلتصق الأيقونة والنص بالحافة
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // نعرض الـ SVG بدل أيقونة Flutter الافتراضية
                  SvgPicture.asset(
                    'assets/image/danger-circle-svgrepo-com.svg',
                    height: 20,
                    width: 20,
                    // استبدلنا color بـ colorFilter لتفادي التحذير
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // النص
                  const Expanded(
                    child: Text(
                      "Never share the information below",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,   // تكبير النص
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            // (2) نص توجيهي
            const Text(
              "Scan this QR code to import your wallet in another application",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // (3) رمز الـ QR - يمتد لعرض الصفحة
            Container(
              width: double.infinity,           // يجعل العنصر بعرض الشاشة
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  // استبدلنا withOpacity(0.6) بـ withValues(alpha: 0.6)
                  color: mainColor.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final double side = constraints.maxWidth;

                  // إذا أردت حذف التحذير حول "PrettyQr" كمكتبة مهملة
                  // يمكنك إضافة سطر قبل "PrettyQr(" مثل:
                  // // ignore: deprecated_member_use
                  // ignore: deprecated_member_use
                  return PrettyQr(
                    data: widget.mnemonic,
                    size: side,             // يستعمل نفس عرض العنصر
                    roundEdges: false,
                    errorCorrectLevel: QrErrorCorrectLevel.M,
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // (4) عنوان إنشاء نسخة احتياطية يدوياً
            const Text(
              "Create a manual backup",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),

            const Text(
              "Write down and securely store these words. Use them to restore your wallet at a later time",
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // (5) صندوق العبارة السرية
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: mainColor, width: 1.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRect(
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: columns,
                      ),
                    ),
                    // التعتيم عند الإخفاء
                    if (_isObscured)
                      Positioned.fill(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // (6) أزرار الإظهار/الإخفاء + النسخ + تنبيه النسخ
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: _toggleVisibility,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      // استبدلنا withOpacity(0.1) بـ withValues(alpha: 0.1)
                      color: mainColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isObscured ? Icons.visibility : Icons.visibility_off,
                      color: mainColor,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                InkWell(
                  onTap: _copyMnemonic,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      // استبدلنا withOpacity(0.1) بـ withValues(alpha: 0.1)
                      color: mainColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.copy,
                      color: mainColor,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_copied)
                  const Text(
                    "Copied!",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
