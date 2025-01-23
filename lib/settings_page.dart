import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // <-- لإطلاق الروابط

// الصفحات الأخرى
import 'biometric_provider.dart';
import 'wallet_inform.dart';
import 'security_page.dart';
import 'bitcoin_unit_page.dart';
import 'currency_page.dart';

// المزودات
import 'currency_rate_provider.dart';
import 'wallet_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // تأجيل استدعاء _initUpdates لما بعد اكتمال أول بناء للواجهة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initUpdates();
    });
  }

  /// جلب البيانات قبل عرض الصفحة (جلب معلومات المحفظة + تحديث العملة من Supabase)
  Future<void> _initUpdates() async {
    setState(() => _isLoading = true);

    final walletProv = Provider.of<WalletProvider>(context, listen: false);
    final currencyProv = Provider.of<CurrencyRateProvider>(context, listen: false);

    // 1) تحديث بيانات المحفظة إن وُجد mnemonic
    if (walletProv.lastMnemonic != null) {
      await walletProv.fetchWalletData(mnemonic: walletProv.lastMnemonic!);
    }

    // 2) جلب رابط العلم (flagUrl) بناءً على fiatSymbol
    if (currencyProv.fiatSymbol.isNotEmpty) {
      try {
        final supabase = Supabase.instance.client;
        final response = await supabase
            .from('curricanes')
            .select()
            .eq('currency_name', currencyProv.fiatSymbol.toUpperCase())
            .maybeSingle();

        if (response != null) {
          final flagUrl = response['currency_flag'] ?? '';
          await currencyProv.fetchRate(
            currencySymbol: currencyProv.fiatSymbol,
            flagUrl: flagUrl.toString(),
          );
        } else {
          await currencyProv.fetchRate(
            currencySymbol: currencyProv.fiatSymbol,
            flagUrl: null,
          );
        }
      } catch (_) {
        // تجاهل الخطأ أو التعامل معه
      }
    }

    setState(() => _isLoading = false);
  }

  /// فتح رابط خارجي
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // لا يمكن الفتح - تم إزالة أي طباعة إلى الـ console
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      // الخلفية العامة بلون 0xFFF1F4F8
      backgroundColor: const Color(0xFFF1F4F8),
      body: Column(
        children: [
          // ========= الهيدر العلوي بلون 0xFFF1F4F8 =========
          _buildHeader(),

          // ========= باقي الإعدادات =========
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // قسم Account
                    _buildSectionTitle("Account"),
                    _buildSettingsItemNoBackground(
                      title: "Wallet",
                      subtitle: "Manage your wallet details",
                      iconData: Icons.account_balance_wallet_rounded,
                      onTap: () => _navigateTo(const WalletInformPage()),
                    ),
                    _buildSettingsItemNoBackground(
                      title: "Security",
                      subtitle: "Passwords & biometrics",
                      iconData: Icons.security_rounded,
                      onTap: () => _navigateTo(const SecurityPage()),
                    ),

                    // قسم Preferences
                    const SizedBox(height: 24),
                    _buildSectionTitle("Preferences"),
                    // ملاحظة: نُبقي شكل أيقونة العملة كما هو (دائري)
                    _buildCurrencyItem(context),
                    // ملاحظة: نُبقي شكل أيقونة البتكوين كما هو (دائري)
                    _buildBitcoinUnitItem(context),

                    // قسم More
                    const SizedBox(height: 24),
                    _buildSectionTitle("More"),
                    _buildSettingsItemNoBackground(
                      title: "Privacy Policies",
                      subtitle: "Read policies & disclaimers",
                      iconData: Icons.privacy_tip_rounded,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _openUrl("https://bitvault.help/privacypolicy");
                      },
                    ),
                    _buildSettingsItemNoBackground(
                      title: "Contact Us",
                      subtitle: "Get help or send feedback",
                      iconData: Icons.contact_support_rounded,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _openUrl("https://bitvault.help/support");
                      },
                    ),

                    // قسم Danger Zone
                    const SizedBox(height: 24),
                    _buildSectionTitle("Danger Zone"),
                    _buildRemoveWalletItem(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// هيدر علوي بلون 0xFFF1F4F8 مع كتابة "Settings"
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 140,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F4F8),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Text(
            "Settings",
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ),
    );
  }

  /// عنوان قسم
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
        ),
      ),
    );
  }

  /// عنصر إعداد (نص + أيقونة) بدون خلفية
  /// تم تغيير شكل الأيقونة إلى شكل "مربع بزاوية دائرية" بدل الدائرة
  Widget _buildSettingsItemNoBackground({
    required String title,
    required String subtitle,
    required IconData iconData,
    VoidCallback? onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap != null
              ? () {
            HapticFeedback.lightImpact();
            onTap();
          }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                // هنا غيّرنا الشكل إلى مربع بحواف دائرية بدلاً من الدائرة
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    iconData,
                    size: 24,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.black38,
                ),
              ],
            ),
          ),
        ),
        Container(height: 1, color: Colors.grey.shade300),
      ],
    );
  }

  /// عنصر مخصص للعملة - نحتفظ بشكل الأيقونة الدائري
  Widget _buildCurrencyItem(BuildContext context) {
    final currencyRateProv = context.watch<CurrencyRateProvider>();
    final symbol = currencyRateProv.fiatSymbol; // مثال "USD"
    final flagUrl = currencyRateProv.fiatFlagUrl ?? '';

    return Column(
      children: [
        InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _navigateTo(const CurrencyPage());
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                // هنا نُبقي الشكل دائري كما هو
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.black12,
                    shape: BoxShape.circle,
                  ),
                  child: flagUrl.isNotEmpty
                      ? ClipOval(
                    child: Image.network(
                      flagUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, _, __) => const Icon(
                        Icons.flag,
                        color: Colors.black54,
                      ),
                    ),
                  )
                      : const Icon(Icons.flag, color: Colors.black54),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Currency",
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        symbol,
                        style: const TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.black38,
                ),
              ],
            ),
          ),
        ),
        Container(height: 1, color: Colors.grey.shade300),
      ],
    );
  }

  /// عنصر خاص بوحدة البتكوين (BTC أو SAT) - نحتفظ بشكل الأيقونة الدائري
  Widget _buildBitcoinUnitItem(BuildContext context) {
    final walletProv = context.watch<WalletProvider>();
    final unit = walletProv.currentUnit; // "BTC" أو "SAT"

    // يمكن التلاعب بالأيقونة إن احتجنا، لكنه محدد بالسؤال أن يبقى
    final iconWidget = unit == "BTC"
        ? Image.asset(
      'assets/image/bitcoin-910307_1280.png',
      width: 24,
      height: 24,
    )
        : Image.asset(
      'assets/image/bitcoin-910307_1280.png',
      width: 24,
      height: 24,
    );

    return Column(
      children: [
        InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _navigateTo(const BitcoinUnitPage());
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                // هنا نُبقي الشكل دائري كما هو
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.black12,
                    shape: BoxShape.circle,
                  ),
                  child: iconWidget,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Bitcoin Unit",
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        unit == "BTC" ? "Bitcoin" : "Satoshi",
                        style: const TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.black38,
                ),
              ],
            ),
          ),
        ),
        Container(height: 1, color: Colors.grey.shade300),
      ],
    );
  }

  /// عنصر Remove Wallet
  /// تم تغيير شكل الأيقونة إلى مربع بحواف دائرية بدلاً من الدائرة
  Widget _buildRemoveWalletItem(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            HapticFeedback.heavyImpact();
            _showRemoveWalletWarning(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    "Remove Wallet",
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(height: 1, color: Colors.grey.shade300),
      ],
    );
  }

  /// نافذة تحذير لإزالة المحفظة (بتصميم جديد + فراغ 40 بكسل في الأسفل)
  void _showRemoveWalletWarning(BuildContext context) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true, // للسماح بسحب النافذة لأعلى
      backgroundColor: Colors.transparent, // نجعل الخلفية شفافة
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6, // ارتفاع افتراضي أكبر
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Container(
              // خلفية بنفس لون الصفحة الرئيسية
              decoration: const BoxDecoration(
                color: Color(0xFFF1F4F8),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: SingleChildScrollView(
                controller: controller,
                // هام: أضفنا 40 من الأسفل لترك فراغ تحت الأزرار
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
                child: Column(
                  children: [
                    /// أيقونة تحذير كبيرة باللون الأحمر
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 16),

                    /// العنوان الكبير
                    const Text(
                      "Remove Wallet?",
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 16),

                    /// النص التوضيحي (بحجم أكبر قليلا)
                    const Text(
                      "You are about to reset your wallet data. Make sure you have backed up your secret phrase.\n\n"
                          "If you remove your wallet, all local data will be lost. You can restore your wallet using your secret phrase later.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 32),

                    /// زرّان (Cancel / Remove) مع فراغ 40 من الأسفل
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black87,
                              side: const BorderSide(color: Colors.black12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              "Cancel",
                              style: TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final biometricState = Provider.of<BiometricProvider>(
                                context,
                                listen: false,
                              );
                              if (biometricState.enableBiometric) {
                                biometricState.authenticate(force: true).then((value) {
                                  biometricState.changeBiometricStatus(disable: true);
                                  Navigator.pop(ctx, true);
                                });
                              } else {
                                Navigator.pop(ctx, true);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              "Remove",
                              style: TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((confirmed) {
      if (confirmed == true) {
        // إذا اختار المستخدم "Remove" (نعم)
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    });
  }

  /// دالة انتقال (سحب من اليمين)
  void _navigateTo(Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => page,
        transitionsBuilder: (_, anim, __, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          final tween =
          Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeInOut));
          return SlideTransition(
            position: anim.drive(tween),
            child: child,
          );
        },
      ),
    );
  }
}
