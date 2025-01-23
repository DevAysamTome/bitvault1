import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import 'wallet_provider.dart';
import 'wallet_page.dart';

class CreateWalletPage extends StatefulWidget {
  const CreateWalletPage({super.key});

  @override
  State<CreateWalletPage> createState() => _CreateWalletPageState();
}

class _CreateWalletPageState extends State<CreateWalletPage> {
  bool _showMnemonic = false;
  bool _isLoading = false;
  int? _selectedIndex;
  String _mnemonic = "";
  bool _isObscured = true;
  bool _copied = false;
  String? _apiError;

  final List<PathItem> paths = [
    PathItem(
      title: "Native SegWit (BIP84)",
      subtitle: "Recommended",
      icon: Icons.lock_outline_rounded,
      bipType: WalletProvider.bip84,
    ),
    PathItem(
      title: "SegWit (BIP49)",
      subtitle: "More privacy",
      icon: Icons.security_rounded,
      bipType: WalletProvider.bip49,
    ),
    PathItem(
      title: "Legacy (BIP44)",
      subtitle: "Higher Integration",
      icon: Icons.history_edu_rounded,
      bipType: WalletProvider.bip44,
    ),
  ];

  Future<void> _fetchMnemonicFromApiAndStore(String walletType) async {
    setState(() {
      _apiError = null;
    });

    final url = Uri.parse('https://generate-wallet.vercel.app/api/scan');
    final requestBody = {
      "mnemonic": "",
      "passphrase": null,
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw Exception("API returned status code: ${response.statusCode}");
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || !decoded.containsKey('result')) {
        throw Exception("Key 'result' not found in API response.");
      }

      final result = decoded['result'];
      if (result is! Map<String, dynamic> || !result.containsKey('mnemonic')) {
        throw Exception("Key 'mnemonic' not found in 'result'.");
      }

      final mnemonic = result['mnemonic'];

      // تخزين في Supabase (إن أحببت)
      final supabase = Supabase.instance.client;
      final insertedRows = await supabase.from('wallet').insert({
        'walletMnemonic': mnemonic,
        'walletInfo': decoded,
        'walletType': walletType,
        'walleTotalBalance': 0,
      }).select();

      if (insertedRows.isEmpty) {
        throw Exception(
            "Insert returned empty or invalid data. Possibly an error occurred.");
      }

      setState(() {
        _mnemonic = mnemonic as String;
      });
    } catch (e) {
      setState(() {
        _apiError = e.toString();
      });
    }
  }

  void _onSelectPath(int index) {
    setState(() {
      _selectedIndex = index;
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _onContinueStep1() async {
    if (_selectedIndex == null) return;

    setState(() {
      _isLoading = true;
    });
    HapticFeedback.lightImpact();

    final selectedBipType = paths[_selectedIndex!].bipType;
    final selectedPathTitle = paths[_selectedIndex!].title;

    await _fetchMnemonicFromApiAndStore(selectedPathTitle);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (_apiError == null && _mnemonic.isNotEmpty) {
      setState(() {
        _showMnemonic = true;
      });

      // أهم خطوة: نحدد في المزود أي مسار اخترناه
      final walletProvider = context.read<WalletProvider>();
      walletProvider.setPreferredBipType(selectedBipType);
    } else {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Error: $_apiError",
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onContinueStep2() {
    HapticFeedback.lightImpact();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WalletPage(mnemonic: _mnemonic),
      ),
    );
  }

  void _toggleMnemonic() {
    setState(() {
      _isObscured = !_isObscured;
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _copyMnemonic() async {
    if (_mnemonic.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _mnemonic));
    HapticFeedback.lightImpact();
    setState(() => _copied = true);

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F4F8),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF1F4F8),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Create Wallet',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _showMnemonic
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: _buildStep1SelectPath(),
            secondChild: _buildStep2Mnemonic(),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        child: SizedBox(
          height: 50,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: !_showMnemonic
                ? (_isLoading || _selectedIndex == null
                    ? null
                    : _onContinueStep1)
                : _onContinueStep2,
            style: ElevatedButton.styleFrom(
              backgroundColor: !_showMnemonic
                  ? (_selectedIndex == null
                      ? Colors.grey
                      : const Color(0xFF3949AB))
                  : const Color(0xFF3949AB),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isLoading && !_showMnemonic
                ? Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(2.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF3949AB),
                        ),
                      ),
                    ),
                  )
                : Text(
                    !_showMnemonic ? "CONTINUE" : "DONE",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1SelectPath() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Select a derivation path:",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: paths.length,
          itemBuilder: (context, index) {
            final item = paths[index];
            final isSelected = (index == _selectedIndex);

            return GestureDetector(
              onTap: () => _onSelectPath(index),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF3949AB) : Colors.grey,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      item.icon,
                      color: isSelected ? const Color(0xFF3949AB) : Colors.grey,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: item.subtitle == "Recommended"
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.check,
                          color: Color(0xFF3949AB),
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStep2Mnemonic() {
    const mainColor = Color(0xFF3949AB);

    final splittedWords = _mnemonic.split(' ');
    List<Widget> columns = [];
    for (int col = 0; col < 3; col++) {
      List<Widget> columnItems = [];
      for (int row = 0; row < 4; row++) {
        int index = col * 4 + row;
        if (index < splittedWords.length) {
          final word = splittedWords[index];
          columnItems.add(
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              child: Text(
                "${index + 1}. $word",
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.2,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Your Secret Recovery Phrase",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
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
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: columns,
                  ),
                ),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            InkWell(
              onTap: _toggleMnemonic,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  // استبدال withOpacity(0.1) بـ withValues(alpha: 0.1)
                  color: mainColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _isObscured ? Icons.visibility : Icons.visibility_off,
                  color: mainColor,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: _copyMnemonic,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  // استبدال withOpacity(0.1) بـ withValues(alpha: 0.1)
                  color: mainColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.copy,
                  color: mainColor,
                  size: 20,
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
        const SizedBox(height: 12),
        const Text(
          "Keep this phrase somewhere safe. Do NOT share it with anyone.\n"
          "It can recover your wallet if you lose this device.",
          style: TextStyle(
            fontSize: 13,
            color: Colors.black54,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class PathItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String bipType;

  PathItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.bipType,
  });
}
