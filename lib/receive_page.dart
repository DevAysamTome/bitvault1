import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:share_plus/share_plus.dart';

import 'wallet_provider.dart';

class ReceivePage extends StatefulWidget {
  const ReceivePage({super.key});

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> {
  bool _showCopied = false;
  String? _address;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    // تأجيل عملية جلب البيانات بعد اكتمال أول إطار بناء للواجهة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateAddress();
    });
  }

  /// تحديث بيانات المحفظة وجلب العنوان الحالي من المسار المختار
  Future<void> _updateAddress() async {
    setState(() => _isUpdating = true);

    final walletProvider = context.read<WalletProvider>();
    final lastMnemonic = walletProvider.lastMnemonic;

    // جلب بيانات المحفظة إن وُجِد mnemonic
    if (lastMnemonic != null && lastMnemonic.isNotEmpty) {
      await walletProvider.fetchWalletData(mnemonic: lastMnemonic);
    }

    // الحصول على عنوان الاستقبال (freshAddress)
    final fetchedAddress = walletProvider.currentFreshAddress;
    _address =
        (fetchedAddress != null && fetchedAddress.isNotEmpty) ? fetchedAddress : null;

    setState(() => _isUpdating = false);
  }

  Future<void> _onAddressTap() async {
    if (_address == null || _address!.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _address!));
    HapticFeedback.lightImpact();

    setState(() => _showCopied = true);

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _showCopied = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasAddress = _address != null && _address!.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1F4F8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        centerTitle: true,
        title: const Text(
          'Receive',
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: _isUpdating
            ? const Center(child: CircularProgressIndicator())
            : (hasAddress
                ? _buildWithAddress(context, _address!)
                : _buildNoAddress(context)),
      ),
    );
  }

  Widget _buildWithAddress(BuildContext context, String address) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // رمز QR
        Center(
          // ignore: deprecated_member_use
          child: PrettyQr(
            data: address,
            size: 240,
            roundEdges: true,
            elementColor: Colors.black,
          ),
        ),
        const SizedBox(height: 20),

        // العنوان أو "copied"
        GestureDetector(
          onTap: _onAddressTap,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _showCopied
                ? const Text(
                    "copied",
                    key: ValueKey('copiedText'),
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  )
                : Text(
                    address,
                    key: const ValueKey('addressText'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0057FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: () {
                Share.share(address, subject: "My BTC Address");
                HapticFeedback.lightImpact();
              },
              child: const Text(
                'Share...',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoAddress(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.error_outline, size: 60, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "No fresh address available!",
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Please fetch wallet data or check the BIP path.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
