import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'biometric_provider.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key}); // استخدمنا super parameter بدلاً من (key: key)

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final biometricState = Provider.of<BiometricProvider>(context, listen: false);
    if (state == AppLifecycleState.paused) {
      biometricState.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      if (biometricState.authenticatedCount == 1) {
        debugPrint(biometricState.authenticatedCount.toString());
        biometricState.onAppResumed();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final biometricState = Provider.of<BiometricProvider>(context, listen: false);

    return Scaffold(
      /// لون الخلفية
      backgroundColor: const Color(0xFFF1F4F8),

      /// شريط علوي (AppBar)
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1F4F8),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: true,
        title: const Text(
          'Security',
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            color: Color(0xFF333333),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      /// محتوى الصفحة
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          physics: const BouncingScrollPhysics(),
          children: [
            /// قسم (Biometrics)
            _buildSectionHeader(
              icon: Icons.security_rounded,
              title: 'Biometrics',
              subtitle: 'Enhance your security using biometrics',
            ),

            /// عنصر التبديل (FaceID) مع تصميم جديد
            _buildToggleItem(
              icon: Icons.face_rounded,
              title: 'Use Face ID',
              description:
                  'Enable Face ID to confirm your identity before transactions or unlocking the wallet.',
              value: biometricState.enableBiometric,
              onChanged: (val) {
                setState(() {
                  biometricState.changeBiometricStatus();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  /// عنصر عنوان قسم رئيسي (Section Header) بتصميم جديد
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            /// هنا استبدلنا withOpacity(0.05) بـ withValues(alpha: 0.05)
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          /// أيقونة كبيرة لتمثيل القسم
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              /// استبدلنا withOpacity(0.1) بـ withValues(alpha: 0.1)
              color: const Color(0xFF3949AB).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: const Color(0xFF3949AB),
              size: 28,
            ),
          ),
          const SizedBox(width: 12),

          /// النصوص (العنوان + الوصف)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// عنصر يحتوي على عنوان + وصف + أيقونة + مفتاح سويتش
  Widget _buildToggleItem({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? description,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            /// استبدلنا withOpacity(0.04) بـ withValues(alpha: 0.04)
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          /// أيقونة في صندوق صغير
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              /// استبدلنا withOpacity(0.15) بـ withValues(alpha: 0.15)
              color: const Color(0xFF3949AB).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: const Color(0xFF3949AB),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          /// النصوص: عنوان + وصف
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// العنوان
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),

                /// الوصف إن وجد
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),

          /// مفتاح التبديل (سويتش)
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF3949AB),
            /// استبدلنا withOpacity(0.3) بـ withValues(alpha: 0.3)
            activeTrackColor: const Color(0xFF3949AB).withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
