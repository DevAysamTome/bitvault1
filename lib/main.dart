import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// مزوّدات
import 'biometric_provider.dart';
import 'wallet_provider.dart';
import 'transactions_provider.dart';
import 'currency_rate_provider.dart';

// الاستيرادات المتبقية
import 'import_page.dart';

// صفحة الإنشاء الجديدة
import 'create_wallet_page.dart'; // تأكّد من موقع الملف

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // إعداد Supabase
  await Supabase.initialize(
    url: 'https://qcmsxzllyzfhclqgyhht.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFjbXN4emxseXpmaGNscWd5aGh0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjY2ODQ0MDgsImV4cCI6MjA0MjI2MDQwOH0.oD8X47kKCUsusT3w7kJiTwU6yaq1Ws8rESeIJL8MdUE',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WalletProvider>(
          create: (context) => WalletProvider(),
        ),
        ChangeNotifierProvider<TransactionsProvider>(
          create: (context) => TransactionsProvider(),
        ),
        ChangeNotifierProvider<CurrencyRateProvider>(
          create: (context) => CurrencyRateProvider(),
        ),
        ChangeNotifierProvider<BiometricProvider>(
          create: (context) => BiometricProvider(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BitVault Screen',
      theme: ThemeData(
        textTheme: const TextTheme(
          bodyLarge: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 16,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 14,
          ),
          headlineLarge: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 24,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 20,
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // الانتقال لصفحة WalletScreen بعد 5 ثوانٍ
    Future.delayed(const Duration(seconds: 5), () {
      Navigator.pushReplacement(
        // ignore: use_build_context_synchronously
        context,
        MaterialPageRoute(builder: (context) => const WalletScreen()),
        // MaterialPageRoute(builder: (context) => const BiometricScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = const Color(0xFFF1F4F8);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Lottie.asset(
          'assets/image/Animation-1731274801114.json',
          width: 200,
          height: 200,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

// 
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with WidgetsBindingObserver {
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
    final biometricState =
        Provider.of<BiometricProvider>(context, listen: false);

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
    final backgroundColor = const Color(0xFFF1F4F8);
    // لون استيراد أو إنشاء محفظة
    final primaryColor = const Color(0xFF3949AB);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/image/Animation-1731274801114.json',
              width: 200,
              height: 200,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'Empowering you to securely store, manage, and access your Bitcoin anytime, anywhere—without compromising on privacy or safety.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontFamily: 'SpaceGrotesk',
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
      // تم تغيير الـ padding السفلي إلى 40 لجعل الكونتينر مرتفعًا عن الأسفل بمقدار 40 بكسل
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateWalletPage(),
                      ),
                    );
                  },
                  child: Container(
                    color: Colors.white,
                    height: 60,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.add_circle_outline, color: Colors.black),
                        SizedBox(width: 8),
                        Text(
                          'Create Wallet',
                          style: TextStyle(
                            color: Colors.black,
                            fontFamily: 'SpaceGrotesk',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ImportPage(),
                      ),
                    );
                  },
                  child: Container(
                    color: primaryColor,
                    height: 60,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.arrow_downward, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Import Wallet',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'SpaceGrotesk',
                          ),
                        ),
                      ],
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
