import 'dart:convert';
import 'package:bitvault/wallet_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'biometric_provider.dart';
import 'currency_rate_provider.dart';
import 'wallet_provider.dart';

class SendBitcoinPage extends StatefulWidget {
  final String address;
  final String mnemonic;

  const SendBitcoinPage({
    Key? key,
    required this.address,
    required this.mnemonic,
  }) : super(key: key);

  @override
  State<SendBitcoinPage> createState() => _SendBitcoinPageState();
}

class _SendBitcoinPageState extends State<SendBitcoinPage> {
  // (1) Input fields
  final TextEditingController _cryptoController = TextEditingController();
  final TextEditingController _fiatController = TextEditingController();

  /// Indicates which field is active (BTC/SAT or fiat).
  bool _isCryptoFieldActive = false;

  /// Prevents infinite conversion loops between fields.
  bool _isConverting = false;

  /// Determines whether to show red color for invalid ranges.
  bool _cryptoInvalid = false;
  bool _fiatInvalid = false;

  // (2) Summary screen data
  bool _showSummary = false;
  int _draftVsize = 0;
  int _draftNetAmount = 0; // net amount after the draft fee
  String _utxosUsedString = "";
  String _changeAddressDraft = "";

  /// Selected fee key from the recommended fees map.
  String _selectedFeeKey = "fastestFee";

  final Map<String, int> _recommendedFees = {
    "fastestFee": 0,
    "economyFee": 0,
    "minimumFee": 0,
  };

  // Holds the fresh change address for the transaction.
  String _freshChangeAddress = '';

  @override
  void initState() {
    super.initState();

    // Initialize input fields to "0".
    _cryptoController.text = "0";
    _fiatController.text = "0";

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);

      final Map<String, String> bipTypeMapping = {
        WalletProvider.bip44: 'BIP44',
        WalletProvider.bip49: 'BIP49',
        WalletProvider.bip84: 'BIP84',
      };

      final mappedKey = bipTypeMapping[walletProvider.preferredBipType];
      final data = walletProvider.walletData?["data"];
      if (data == null || mappedKey == null) return;
      final bipData = data[mappedKey];
      if (bipData == null) return;

      // Save the fresh change address
      final changeFresh = bipData["change"]?["fresh"];
      if (changeFresh is Map && changeFresh["address"] is String) {
        _freshChangeAddress = changeFresh["address"] as String;
      }
    });
  }

  @override
  void dispose() {
    _cryptoController.dispose();
    _fiatController.dispose();
    super.dispose();
  }

  // Utility functions ---------------------------------------------------------

  double _toDouble(String? val) {
    if (val == null || val.isEmpty) return 0.0;
    return double.tryParse(val) ?? 0.0;
  }

  bool _isOutOfRange(double val, double minVal, double maxVal) {
    return (val < minVal || val > maxVal);
  }

  String _fiatDisplaySymbol(String fiat) {
    switch (fiat.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'ILS':
        return '₪';
      case 'JPY':
        return '¥';
      default:
        return fiat;
    }
  }

  String _shortenAddress(String address) {
    if (address.length <= 14) return address;
    final first8 = address.substring(0, 8);
    final last6 = address.substring(address.length - 6);
    return '$first8...$last6';
  }

  /// Builds a string of UTXOs in the format:
  /// "hash,pos,value,wif,addr|hash2,pos2,value2,wif2,addr2"
  String _buildUtxosString(Map<String, dynamic> bipData) {
    final result = <String>[];

    void processUtxos(List<dynamic> utxos) {
      for (final u in utxos) {
        final txHash = u["tx_hash"];
        final txPos = u["tx_pos"];
        final value = u["value"];
        final wif = u["wif"];
        final addr = u["address"];

        if (txHash == null ||
            txPos == null ||
            value == null ||
            wif == null ||
            addr == null) {
          continue;
        }
        final utxoStr = "$txHash,$txPos,$value,$wif,$addr";
        result.add(utxoStr);
      }
    }

    final receiveUsed = bipData["receive"]?["used"];
    if (receiveUsed is List) {
      for (var item in receiveUsed) {
        final utxos = item["utxos"];
        if (utxos is List) processUtxos(utxos);
      }
    }
    final receiveFresh = bipData["receive"]?["fresh"];
    if (receiveFresh is Map && receiveFresh["utxos"] is List) {
      processUtxos(receiveFresh["utxos"]);
    }
    final changeUsed = bipData["change"]?["used"];
    if (changeUsed is List) {
      for (var item in changeUsed) {
        final utxos = item["utxos"];
        if (utxos is List) processUtxos(utxos);
      }
    }
    final changeFresh = bipData["change"]?["fresh"];
    if (changeFresh is Map && changeFresh["utxos"] is List) {
      processUtxos(changeFresh["utxos"]);
    }

    return result.join("|");
  }

  Widget _buildRowItem(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, color: Colors.black54),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 16, color: Colors.black),
        ),
      ],
    );
  }

  String _formatBTC(double btc) {
    final str = btc.toStringAsFixed(8);
    return str.replaceAll(RegExp(r'\.?0+$'), '');
  }

  // Build ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1F4F8),
        elevation: 0,
        leading: IconButton(
          style: ButtonStyle(
            overlayColor: MaterialStateProperty.resolveWith(
              (states) => Colors.transparent,
            ),
          ),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            HapticFeedback.lightImpact();
            if (_showSummary) {
              setState(() => _showSummary = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _showSummary ? 'Summary' : 'Enter Amount',
          style: const TextStyle(fontSize: 18, color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _showSummary ? _buildSummaryView() : _buildEnterAmountView(),
      ),
    );
  }

  // (A) First screen: Enter amount --------------------------------------------

  Widget _buildEnterAmountView() {
    final walletProvider = Provider.of<WalletProvider>(context);
    final currencyProvider = Provider.of<CurrencyRateProvider>(context);

    final double? btcRate = currencyProvider.rate;
    final fiatSymbol = currencyProvider.fiatSymbol;

    final shortAddr = _shortenAddress(widget.address);

    final availableToSendText =
        walletProvider.getDisplayBalance(walletProvider.preferredBipType);
    final userBalanceInSat =
        walletProvider.getBalanceInSatoshi(walletProvider.preferredBipType);
    final userBalanceInBTC =
        walletProvider.getBalanceInBTC(walletProvider.preferredBipType);

    // Min and max constraints
    const minSat = 546;
    final minBTC = minSat / 100000000;
    final maxSat = userBalanceInSat;
    final maxBTC = userBalanceInBTC;

    double? minFiat, maxFiat;
    if (btcRate != null) {
      minFiat = minBTC * btcRate;
      maxFiat = maxBTC * btcRate;
    }

    final cryptoFormatters = [
      FilteringTextInputFormatter.allow(RegExp(r'^[0-9]*\.?[0-9]*$')),
    ];
    final fiatFormatters = [
      FilteringTextInputFormatter.allow(RegExp(r'^[0-9]*\.?[0-9]*$')),
    ];

    return Column(
      key: const ValueKey('EnterAmountView'),
      children: [
        // Recipient address display
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 1.0),
          child: Row(
            children: [
              const Text(
                'To: ',
                style: TextStyle(color: Colors.black54, fontSize: 16),
              ),
              Expanded(
                child: Text(
                  shortAddr,
                  style: const TextStyle(color: Colors.black54, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // BTC/SAT and Fiat fields
        Expanded(
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _isCryptoFieldActive
                  ? Column(
                      key: const ValueKey('cryptoFirst'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCryptoField(
                          walletProvider,
                          btcRate,
                          cryptoFormatters,
                          minSat,
                          maxSat,
                          minBTC,
                          maxBTC,
                          minFiat,
                          maxFiat,
                        ),
                        const SizedBox(height: 20),
                        _buildFiatField(
                          walletProvider,
                          btcRate,
                          fiatSymbol,
                          fiatFormatters,
                          minBTC,
                          maxBTC,
                        ),
                      ],
                    )
                  : Column(
                      key: const ValueKey('fiatFirst'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildFiatField(
                          walletProvider,
                          btcRate,
                          fiatSymbol,
                          fiatFormatters,
                          minBTC,
                          maxBTC,
                        ),
                        const SizedBox(height: 20),
                        _buildCryptoField(
                          walletProvider,
                          btcRate,
                          cryptoFormatters,
                          minSat,
                          maxSat,
                          minBTC,
                          maxBTC,
                          minFiat,
                          maxFiat,
                        ),
                      ],
                    ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Available + Max
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Available To Send',
                    style: TextStyle(color: Colors.black45, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    availableToSendText,
                    style: const TextStyle(color: Colors.black, fontSize: 14),
                  ),
                ],
              ),
              TextButton(
                style: ButtonStyle(
                  overlayColor: MaterialStateProperty.resolveWith(
                    (states) => Colors.transparent,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _handleMaxButton(walletProvider, btcRate);
                },
                child: const Text(
                  'Max',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Next button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                splashFactory: NoSplash.splashFactory,
                backgroundColor: const Color(0xFF3949AB),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onPressed: _onNext,
              child: const Text(
                'Next',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  void _onNext() async {
    HapticFeedback.lightImpact();
    if (_cryptoInvalid || _fiatInvalid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid amount. Please adjust your values.'),
        ),
      );
      return;
    }
    await _generateDraft();
  }

  // (B) Generate draft transaction to get vsize -------------------------------

  Future<void> _generateDraft() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);

    final Map<String, String> bipTypeMapping = {
      WalletProvider.bip44: 'BIP44',
      WalletProvider.bip49: 'BIP49',
      WalletProvider.bip84: 'BIP84',
    };

    final mappedKey = bipTypeMapping[walletProvider.preferredBipType];
    final data = walletProvider.walletData?["data"];
    if (data == null || mappedKey == null) {
      return;
    }

    final bipData = data[mappedKey];
    if (bipData == null) {
      return;
    }

    final utxosString = _buildUtxosString(bipData);
    final receiver = widget.address;

    final typedVal = _toDouble(_cryptoController.text);
    final walletUnit = walletProvider.currentUnit; // "SAT" or "BTC"

    int amountInSat;
    if (walletUnit == "SAT") {
      amountInSat = typedVal.round();
    } else {
      amountInSat = (typedVal * 100000000).round();
    }

    if (amountInSat <= 0) {
      return;
    }

    // Use 1 sat for the draft fee
    const int draftFee = 1;
    final int finalAmountInSat = amountInSat - draftFee;
    if (finalAmountInSat <= 0) {
      return;
    }

    String changeAddr = _freshChangeAddress;
    if (changeAddr.isEmpty) {
      final changeFreshObj = bipData["change"]?["fresh"];
      if (changeFreshObj is Map && changeFreshObj["address"] is String) {
        changeAddr = changeFreshObj["address"];
      }
    }
    if (changeAddr.isEmpty) {
      return;
    }

    final bodyMap = {
      "utxos": utxosString,
      "receivers": receiver,
      "amounts": "$finalAmountInSat",
      "fee": "$draftFee",
      "rbf": "true",
      "broadcast": "false",
      "changeAddress": changeAddr,
    };

    const url = "https://generate-wallet.vercel.app/api/send";
    final headers = {"Content-Type": "application/json"};

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(bodyMap),
    );

    if (!mounted) return;

    if (response.statusCode == 200) {
      final jsonResp = jsonDecode(response.body);
      _draftVsize = jsonResp["vsize"] ?? 0;
      _draftNetAmount = finalAmountInSat;
      _utxosUsedString = utxosString;
      _changeAddressDraft = changeAddr;

      setState(() => _showSummary = true);

      // Fetch recommended fees after switching to summary
      await _fetchRecommendedFees();
      if (!mounted) return;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Draft Error: ${response.body}")),
      );
    }
  }

  // (C) Summary screen --------------------------------------------------------

  Widget _buildSummaryView() {
    final currencyProvider = Provider.of<CurrencyRateProvider>(context);
    final userFiatRate = currencyProvider.rate ?? 0;
    final userFiatSymbol = currencyProvider.fiatSymbol;

    final chosenRate = _recommendedFees[_selectedFeeKey] ?? 0;
    final newFee = _draftVsize * chosenRate;
    final diffFee = newFee - 1;
    final finalAmount = _draftNetAmount - diffFee;
    final insufficient = finalAmount <= 0;

    final finalAmountBTC = finalAmount / 100000000.0;
    final finalFiat = finalAmountBTC * userFiatRate;

    final newFeeBTC = newFee / 100000000.0;
    final newFeeFiat = newFeeBTC * userFiatRate;

    final shortAddr = _shortenAddress(widget.address);

    return Container(
      key: const ValueKey('SummaryView'),
      color: const Color(0xFFF1F4F8),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Amount
          Text(
            _formatBTC(finalAmountBTC),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          Text(
            "${_fiatDisplaySymbol(userFiatSymbol)}${finalFiat.toStringAsFixed(2)}",
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),

          const SizedBox(height: 20),

          // Main card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildRowItem("To", shortAddr),
                const Divider(),
                _buildRowItem("Network", "Bitcoin"),
                const Divider(),

                // Network fee + icon
                InkWell(
                  onTap: _showFeeOptionsBottomSheet,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Text(
                            "Network fee",
                            style: TextStyle(fontSize: 16, color: Colors.black54),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.edit,
                            size: 18,
                            color: Colors.black45,
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "${_fiatDisplaySymbol(userFiatSymbol)}${newFeeFiat.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            "$newFee sats",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Send button
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                splashFactory: NoSplash.splashFactory,
                backgroundColor:
                    insufficient ? Colors.grey : const Color(0xFF3949AB),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onPressed: insufficient
                  ? null
                  : () async {
                      HapticFeedback.lightImpact();
                      await _broadcastTx(chosenRate);
                    },
              child: const Text(
                'Send',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // (D) BottomSheet for fee options -------------------------------------------

  void _showFeeOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      // Improved design for the bottom sheet:
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(18),
        ),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return Container(
          height: 330,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(18),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Select Fee Rate (sat/vByte)",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    _buildFeeOptionTile("fastestFee", "30 m"),
                    _buildFeeOptionTile("economyFee", "4 h"),
                    _buildFeeOptionTile("minimumFee", "12 h"),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeeOptionTile(String key, String label) {
    final rate = _recommendedFees[key] ?? 0;
    return RadioListTile<String>(
      title: Text("Less Than $label ($rate sat/vByte)"),
      value: key,
      groupValue: _selectedFeeKey,
      onChanged: (val) {
        if (val == null) return;
        Navigator.pop(context); 
        setState(() {
          _selectedFeeKey = val;
        });
      },
    );
  }

  // (E) Broadcast Transaction -------------------------------------------------

  Future<void> _broadcastTx(int chosenFeeRate) async {
    final newFee = _draftVsize * chosenFeeRate;
    final diffFee = newFee - 1;
    final finalAmount = _draftNetAmount - diffFee;
    if (finalAmount <= 0) {
      return;
    }

    final bodyMap = {
      "utxos": _utxosUsedString,
      "receivers": widget.address,
      "amounts": "$finalAmount",
      "fee": "$newFee",
      "rbf": "true",
      "broadcast": "true",
      "changeAddress": _changeAddressDraft,
    };

    final biometricState = Provider.of<BiometricProvider>(context, listen: false);
    if (biometricState.enableBiometric) {
      biometricState.authenticate(force: true).then((value) async {
        const url = "https://generate-wallet.vercel.app/api/send";
        final headers = {"Content-Type": "application/json"};

        final response = await http.post(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(bodyMap),
        );

        if (!mounted) return;

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Transaction broadcasted successfully!"),
            ),
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WalletPage(mnemonic: widget.mnemonic),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Broadcast Error: ${response.body}")),
          );
        }
      });
    } else {
      const url = "https://generate-wallet.vercel.app/api/send";
      final headers = {"Content-Type": "application/json"};

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(bodyMap),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Transaction broadcasted successfully!"),
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WalletPage(mnemonic: widget.mnemonic),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Broadcast Error: ${response.body}")),
        );
      }
    }
  }

  // (F) Fetch recommended fees from mempool.space -----------------------------

  Future<void> _fetchRecommendedFees() async {
    try {
      final url = Uri.parse("https://mempool.space/api/v1/fees/recommended");
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        _recommendedFees["fastestFee"] = data["fastestFee"] ?? 0;
        _recommendedFees["economyFee"] = data["economyFee"] ?? 0;
        _recommendedFees["minimumFee"] = data["minimumFee"] ?? 0;
        setState(() {});
      }
    } catch (e) {
      debugPrint("fetchRecommendedFees error: $e");
    }
  }

  // (G) Max button handler ----------------------------------------------------

  void _handleMaxButton(WalletProvider walletProvider, double? btcRate) {
    final userBalanceInSat =
        walletProvider.getBalanceInSatoshi(walletProvider.preferredBipType);
    final userBalanceInBTC =
        walletProvider.getBalanceInBTC(walletProvider.preferredBipType);

    if (_isCryptoFieldActive) {
      if (walletProvider.currentUnit == "SAT") {
        _cryptoController.text = userBalanceInSat.toString();
        if (btcRate != null) {
          final satInBTC = userBalanceInSat / 100000000.0;
          _fiatController.text = satInBTC.toStringAsFixed(2);
        }
      } else {
        _cryptoController.text = userBalanceInBTC.toStringAsFixed(8);
        if (btcRate != null) {
          _fiatController.text =
              (userBalanceInBTC * btcRate).toStringAsFixed(2);
        }
      }
      setState(() {
        _cryptoInvalid = false;
        _fiatInvalid = false;
      });
    } else {
      if (btcRate != null) {
        final fiatVal = userBalanceInBTC * btcRate;
        _fiatController.text = fiatVal.toStringAsFixed(2);

        if (walletProvider.currentUnit == "SAT") {
          final satVal = (userBalanceInBTC * 100000000).round();
          _cryptoController.text = satVal.toString();
        } else {
          _cryptoController.text = userBalanceInBTC.toStringAsFixed(8);
        }
      }
      setState(() {
        _cryptoInvalid = false;
        _fiatInvalid = false;
      });
    }
  }

  // (H) Building the crypto field ---------------------------------------------

  Widget _buildCryptoField(
    WalletProvider wProvider,
    double? btcRate,
    List<TextInputFormatter> formatters,
    int minSat,
    int maxSat,
    double minBTC,
    double maxBTC,
    double? minFiat,
    double? maxFiat,
  ) {
    final isSat = (wProvider.currentUnit == "SAT");
    final suffixText = isSat ? "SATS" : "BTC";

    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _isCryptoFieldActive = true);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: TextField(
              controller: _cryptoController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: formatters,
              readOnly: !_isCryptoFieldActive,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                border: InputBorder.none,
              ),
              style: TextStyle(
                fontSize: 36,
                color: _cryptoInvalid
                    ? Colors.red
                    : (_isCryptoFieldActive ? Colors.black : Colors.black45),
              ),
              onChanged: (val) {
                if (_isConverting) return;
                _isConverting = true;

                final typedVal = _toDouble(val);
                double minVal, maxValC;

                if (isSat) {
                  minVal = minSat.toDouble();
                  maxValC = maxSat.toDouble();
                } else {
                  minVal = minBTC;
                  maxValC = maxBTC;
                }

                final isOutside = _isOutOfRange(typedVal, minVal, maxValC);
                if (isOutside && typedVal != 0) {
                  setState(() => _cryptoInvalid = true);
                } else {
                  setState(() => _cryptoInvalid = false);

                  if (btcRate != null) {
                    double inBTC = typedVal;
                    if (isSat) {
                      inBTC = typedVal / 100000000.0; // SAT → BTC
                    }
                    final fiatVal = inBTC * btcRate;

                    if (minFiat != null && maxFiat != null && typedVal != 0) {
                      if (fiatVal < minFiat || fiatVal > maxFiat) {
                        _fiatInvalid = true;
                      } else {
                        _fiatInvalid = false;
                      }
                    }
                    _fiatController.text =
                        typedVal == 0 ? "0" : fiatVal.toStringAsFixed(2);
                  } else {
                    if (typedVal == 0) _fiatController.text = "0";
                  }
                }
                _isConverting = false;
              },
            ),
          ),
          const SizedBox(width: 8),
          Text(
            suffixText,
            style: TextStyle(
              fontSize: 16,
              color: _cryptoInvalid
                  ? Colors.red
                  : (_isCryptoFieldActive ? Colors.black : Colors.black45),
            ),
          ),
        ],
      ),
    );
  }

  // (I) Building the fiat field -----------------------------------------------

  Widget _buildFiatField(
    WalletProvider wProvider,
    double? btcRate,
    String fiatSymbol,
    List<TextInputFormatter> formatters,
    double minBTC,
    double maxBTC,
  ) {
    final displaySymbol = _fiatDisplaySymbol(fiatSymbol);
    final suffixText = fiatSymbol.toUpperCase();

    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _isCryptoFieldActive = false);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: TextField(
              controller: _fiatController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: formatters,
              readOnly: _isCryptoFieldActive,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: "$displaySymbol 0.00",
              ),
              style: TextStyle(
                fontSize: 36,
                color: _fiatInvalid
                    ? Colors.red
                    : (!_isCryptoFieldActive ? Colors.black : Colors.black45),
              ),
              onChanged: (val) {
                if (_isConverting) return;
                _isConverting = true;

                final typedFiat = _toDouble(val);
                if (btcRate == null || btcRate <= 0) {
                  _fiatInvalid = false;
                  _isConverting = false;
                  if (typedFiat == 0) {
                    _cryptoController.text = "0";
                  }
                  return;
                }

                final typedBTC = typedFiat / btcRate;
                final isOutside = _isOutOfRange(typedBTC, minBTC, maxBTC);
                if (isOutside && typedFiat != 0) {
                  setState(() => _fiatInvalid = true);
                } else {
                  setState(() => _fiatInvalid = false);

                  if (wProvider.currentUnit == "SAT") {
                    final satVal = typedBTC * 100000000;
                    final satInt = satVal.round();
                    _cryptoController.text =
                        typedFiat == 0 ? "0" : satInt.toString();

                    final userMaxSat = wProvider.getBalanceInSatoshi(
                      wProvider.preferredBipType,
                    );
                    if (satInt < 546 || satInt > userMaxSat) {
                      _cryptoInvalid = true;
                    } else {
                      _cryptoInvalid = false;
                    }
                  } else {
                    if (typedFiat == 0) {
                      _cryptoController.text = "0";
                    } else {
                      _cryptoController.text =
                          typedBTC.toStringAsFixed(8);
                    }
                    if ((typedBTC < minBTC && typedBTC != 0) ||
                        (typedBTC > maxBTC)) {
                      _cryptoInvalid = true;
                    } else {
                      _cryptoInvalid = false;
                    }
                  }
                }
                _isConverting = false;
              },
            ),
          ),
          const SizedBox(width: 8),
          Text(
            suffixText,
            style: TextStyle(
              fontSize: 16,
              color: _fiatInvalid
                  ? Colors.red
                  : (!_isCryptoFieldActive ? Colors.black : Colors.black45),
            ),
          ),
        ],
      ),
    );
  }
}
