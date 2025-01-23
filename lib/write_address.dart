import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'scan_qr_page.dart';
import 'send_bitcoin.dart';

class WriteAddressPage extends StatefulWidget {
  final String? preFilledAddress;
  final String mnemonic;

  const WriteAddressPage({
    Key? key,
    this.preFilledAddress,
    required this.mnemonic,
  }) : super(key: key);

  @override
  State<WriteAddressPage> createState() => _WriteAddressPageState();
}

class _WriteAddressPageState extends State<WriteAddressPage> {
  String _address = '';
  bool _isValidAddress = false;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    if (widget.preFilledAddress != null &&
        widget.preFilledAddress!.trim().isNotEmpty) {
      _address = widget.preFilledAddress!.trim();
      validateAddress(_address);
    }
  }

  void validateAddress(String address) {
    address = address.trim();
    if (address.isEmpty) {
      _isValidAddress = false;
      _showError = false;
      return;
    }

    if (address.startsWith('1')) {
      if (address.length >= 26 && address.length <= 35) {
        _isValidAddress = true;
        _showError = false;
      } else {
        _isValidAddress = false;
        _showError = true;
      }
    } else if (address.startsWith('3')) {
      if (address.length >= 26 && address.length <= 35) {
        _isValidAddress = true;
        _showError = false;
      } else {
        _isValidAddress = false;
        _showError = true;
      }
    } else if (address.startsWith('bc1q')) {
      if (address.length >= 42 && address.length <= 62) {
        _isValidAddress = true;
        _showError = false;
      } else {
        _isValidAddress = false;
        _showError = true;
      }
    } else if (address.startsWith('bc1p')) {
      if (address.length >= 42 && address.length <= 62) {
        _isValidAddress = true;
        _showError = false;
      } else {
        _isValidAddress = false;
        _showError = true;
      }
    } else {
      _isValidAddress = false;
      _showError = true;
    }
  }

  Future<void> _pasteAddress() async {
    HapticFeedback.lightImpact();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.trim().isNotEmpty) {
      setState(() {
        _address = data.text!.trim();
        validateAddress(_address);
      });
    } else {
      setState(() {
        _address = '';
        _isValidAddress = false;
        _showError = true;
      });
    }
  }

  Future<void> _goToScanQrPage() async {
    HapticFeedback.lightImpact();
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const ScanQrPage()),
    );
    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        _address = result.trim();
        validateAddress(_address);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF1F4F8);

    Color borderColor;
    if (_address.isEmpty) {
      borderColor = Colors.grey;
    } else if (_isValidAddress) {
      borderColor = const Color(0xFF3949AB);
    } else {
      borderColor = Colors.red;
    }

    Widget topText = _isValidAddress && _address.isNotEmpty
        ? Text(
            "Address: $_address",
            style: const TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          )
        : const Text(
            "Enter or scan the recipient's address",
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black87,
            ),
          );

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        centerTitle: true,
        title: const Text(
          'Send bitcoin',
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0).copyWith(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              topText,
              const SizedBox(height: 20),
              Container(
                height: 2,
                width: double.infinity,
                color: borderColor,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _pasteAddress,
                    child: Text(
                      "Paste text address",
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "or",
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _goToScanQrPage,
                    child: Text(
                      "Scan QR Code",
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              if (_showError && !_isValidAddress)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    "Invalid address!",
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.red,
                    ),
                  ),
                ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  onPressed: _isValidAddress && _address.isNotEmpty
                      ? () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SendBitcoinPage(
                                address: _address,
                                mnemonic: widget.mnemonic,
                              ),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isValidAddress && _address.isNotEmpty
                        ? const Color(0xFF3949AB)
                        : Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 1,
                  ),
                  child: const Text(
                    'CONTINUE',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
