import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// استيراد الـ WalletProvider (الذي يملك currentUnit و setUnit)
import 'wallet_provider.dart';

class BitcoinUnitPage extends StatefulWidget {
  const BitcoinUnitPage({super.key});

  @override
  State<BitcoinUnitPage> createState() => _BitcoinUnitPageState();
}

class _BitcoinUnitPageState extends State<BitcoinUnitPage> {
  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF1F4F8);

    // نقرأ الـ Provider
    final walletProvider = context.watch<WalletProvider>();
    // الوحدة الحالية (BTC أو SAT)
    final currentUnit = walletProvider.currentUnit;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Bitcoin Unit',
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            // خيار Bitcoin (BTC)
            _buildUnitItem(
              label: "Bitcoin (BTC)",
              unitValue: "BTC",
              isSelected: currentUnit == "BTC",
            ),
            // خيار Satoshi (SAT)
            _buildUnitItem(
              label: "Satoshi (SAT)",
              unitValue: "SAT",
              isSelected: currentUnit == "SAT",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitItem({
    required String label,
    required String unitValue,
    required bool isSelected,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            // عند الاختيار، نقوم بتحديث الـ Provider
            context.read<WalletProvider>().setUnit(unitValue);

            // يمكننا العودة مباشرةً لـ SettingsPage إن أردت:
            Navigator.pop(context);
          },
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // الأيقونة
                Image.asset(
                  'assets/image/bitcoin-910307_1280.png',
                  width: 24,
                  height: 24,
                ),
                const SizedBox(width: 8),

                // النص (label)
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                ),

                // إن كانت هذه الخيار المختار، نعرض علامة صح
                if (isSelected)
                  const Icon(
                    Icons.check,
                    color: Colors.black,
                  ),
              ],
            ),
          ),
        ),
        Container(
          height: 1,
          color: const Color(0xFFE6E6E9),
        ),
      ],
    );
  }
}
