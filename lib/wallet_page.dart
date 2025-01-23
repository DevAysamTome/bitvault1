import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// مزودات
import 'wallet_provider.dart';
import 'transactions_provider.dart';
import 'currency_rate_provider.dart';

// صفحات
import 'write_address.dart';
import 'receive_page.dart';
import 'settings_page.dart';
import 'scan_qr_page.dart';
import 'transactions_page.dart';

class WalletPage extends StatefulWidget {
  final String mnemonic;

  const WalletPage({super.key, required this.mnemonic});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  static const backgroundColor = Color(0xFFF1F4F8);

  Timer? _timer;
  bool _isBalanceVisible = true; // للتحكّم في إظهار/إخفاء الرصيد

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final walletProv = Provider.of<WalletProvider>(context, listen: false);

      // 1) جلب بيانات المحفظة لأول مرة
      walletProv.fetchWalletData(mnemonic: widget.mnemonic);

      // 2) مؤقت لتحديث بيانات المحفظة كل 7 دقائق ونصف
      _timer = Timer.periodic(const Duration(seconds: 7), (_) {
        walletProv.fetchWalletData(mnemonic: widget.mnemonic);
      });

      // 3) جلب سعر الصرف
      final rateProv = Provider.of<CurrencyRateProvider>(context, listen: false);
      rateProv.fetchRate(currencySymbol: rateProv.fiatSymbol);

      // 4) جلب سجل المعاملات إن أمكن
      _fetchTransactionsIfPossible();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// جمع العناوين من المسار المفضّل (44/49/84) لـ WalletProvider
  List<String> _getAllAddressesForCurrentBip(WalletProvider walletProv) {
    if (walletProv.walletData == null) return [];
    final preferredKey = walletProv.preferredBipType;
    final dataObj = walletProv.walletData?['data']?[preferredKey];
    if (dataObj == null) return [];

    final List<String> addresses = [];

    // Receive
    final receive = dataObj['receive'];
    if (receive is Map) {
      final usedArr = receive['used'];
      if (usedArr is List) {
        for (var addrInfo in usedArr) {
          final addr = addrInfo['address'];
          if (addr is String) addresses.add(addr);
        }
      }
      final fresh = receive['fresh'];
      if (fresh is Map) {
        final addr = fresh['address'];
        if (addr is String) addresses.add(addr);
      }
    }

    // Change
    final change = dataObj['change'];
    if (change is Map) {
      final usedArr = change['used'];
      if (usedArr is List) {
        for (var addrInfo in usedArr) {
          final addr = addrInfo['address'];
          if (addr is String) addresses.add(addr);
        }
      }
      final fresh = change['fresh'];
      if (fresh is Map) {
        final addr = fresh['address'];
        if (addr is String) addresses.add(addr);
      }
    }

    return addresses;
  }

  /// محاولة جلب سجل المعاملات إن كانت بيانات المحفظة جاهزة
  Future<void> _fetchTransactionsIfPossible() async {
    final walletProv = context.read<WalletProvider>();
    if (walletProv.walletData == null) return;

    final allAddresses = _getAllAddressesForCurrentBip(walletProv);
    if (allAddresses.isEmpty) return;

    final addressesStr = allAddresses.join('|');
    await context.read<TransactionsProvider>().fetchTransactions(addressesStr);
  }

  /// زر الـ QR
  Future<void> _handleQrScan(BuildContext context) async {
    HapticFeedback.lightImpact();
    final scannedResult = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanQrPage()),
    );
    if (scannedResult != null && scannedResult.trim().isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WriteAddressPage(preFilledAddress: scannedResult,mnemonic: widget.mnemonic,),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletProv = context.watch<WalletProvider>();
    final rateProv = context.watch<CurrencyRateProvider>();

    // حساب الرصيد BTC
    final btcValue = walletProv.getBalanceInBTC(walletProv.preferredBipType);
    double? fiatValue;
    if (!rateProv.isLoading && rateProv.rate != null) {
      fiatValue = btcValue * rateProv.rate!;
    }
    final currencySymbol =
        rateProv.fiatSymbol.isNotEmpty ? rateProv.fiatSymbol : "CUR";

    final String fiatText = (fiatValue == null)
        ? "0.00 $currencySymbol"
        : "${fiatValue.toStringAsFixed(2)} $currencySymbol";

    // رصيد BTC أو SAT
    final displayBtcOrSat =
        walletProv.getDisplayBalance(walletProv.preferredBipType);

    // ============= واجهة الرصيد =============
    Widget balanceWidget;
    if (_isBalanceVisible) {
      // الحالة المرئية
      balanceWidget = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: Stack(
              children: [
                Center(
                  child: Text(
                    fiatText,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Positioned(
                  right: 50,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isBalanceVisible = false;
                      });
                    },
                    child: const Icon(
                      Icons.visibility,
                      color: Colors.black54,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 0.5),
          Center(
            child: Text(
              displayBtcOrSat,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      );
    } else {
      // الحالة المخفية
      balanceWidget = SizedBox(
        width: double.infinity,
        child: Stack(
          children: [
            const Center(
              child: Text(
                "****",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            Positioned(
              right: 50,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _isBalanceVisible = true;
                  });
                },
                child: const Icon(
                  Icons.visibility_off,
                  color: Colors.black54,
                  size: 28,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // استخدام WillPopScope لمنع الرجوع للخلف
    return WillPopScope(
      onWillPop: () async => false, // منع الرجوع للخلف
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false, // إزالة سهم الرجوع
          title: const Text(
            "Wallet",
            style: TextStyle(
              fontSize: 20,
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: const SizedBox(),
          actions: [
            IconButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              },
              icon: const Icon(Icons.settings, color: Colors.black87),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                const SizedBox(height: 8),
                const Text(
                  "Your current balance is",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 20),

                // قسم الرصيد
                balanceWidget,
                const SizedBox(height: 24),

                // الأزرار الدائرية
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CircleActionButton(
                      icon: Icons.arrow_upward,
                      label: "Send",
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WriteAddressPage(mnemonic: widget.mnemonic,),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 30),
                    _CircleActionButton(
                      icon: Icons.arrow_downward,
                      label: "Receive",
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReceivePage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 30),
                    _CircleActionButton(
                      icon: Icons.qr_code_2,
                      label: "Scan",
                      onTap: () => _handleQrScan(context),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // قسم المعاملات (آخر 7)
                _buildTransactionsSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // قسم المعاملات
  Widget _buildTransactionsSection(BuildContext context) {
    final txProv = context.watch<TransactionsProvider>();
    final walletProv = context.watch<WalletProvider>();
    final currencyProv = context.watch<CurrencyRateProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // العنوان + زر See all
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Transactions",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TransactionsPage()),
                );
              },
              child: const Text(
                "See all",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // حالة التحميل أو الخطأ أو عرض القائمة
        if (txProv.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (txProv.errorMessage != null)
          Text(
            "Error: ${txProv.errorMessage}",
            style: const TextStyle(fontSize: 16, color: Colors.red),
          )
        else if (txProv.transactionData == null)
          const Text(
            "No transactions loaded yet.",
            style: TextStyle(fontSize: 16, color: Colors.black54),
          )
        else
          _buildLastSevenTxList(walletProv, txProv, currencyProv),
      ],
    );
  }

  // عرض آخر 7 معاملات فقط
  Widget _buildLastSevenTxList(
    WalletProvider walletProv,
    TransactionsProvider txProv,
    CurrencyRateProvider currencyProv,
  ) {
    final txList = txProv.transactionData!.result.transactions;
    if (txList.isEmpty) {
      return const Text(
        "No transactions found for these addresses.",
        style: TextStyle(fontSize: 16, color: Colors.black54),
      );
    }

    final limitedList = txList.take(7).toList();
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: limitedList.length,
      padding: const EdgeInsets.only(bottom: 16),
      itemBuilder: (context, index) {
        final tx = limitedList[index];
        return _TimelineTransactionItem(
          transaction: tx,
          walletProvider: walletProv,
          currencyProvider: currencyProv,
          isFirst: index == 0,
          isLast: index == limitedList.length - 1,
          onTap: () => _showDetailSheet(context, tx, walletProv, currencyProv),
        );
      },
    );
  }

  // BottomSheet لتفاصيل معاملة
  void _showDetailSheet(
    BuildContext context,
    BitcoinTransaction transaction,
    WalletProvider walletProv,
    CurrencyRateProvider currencyProv,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TransactionDetailSheet(
        transaction: transaction,
        walletProvider: walletProv,
        currencyProvider: currencyProv,
        allMyAddresses: _getAllAddressesForCurrentBip(walletProv),
      ),
    );
  }
}

// ======================================================================
// زر دائري (Circle) مع أيقونة وفوقها نص
// ======================================================================
class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CircleActionButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: onTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Icon(
              icon,
              size: 24,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

// ======================================================================
// عنصر يعرض معاملة في الـ Timeline
// ======================================================================
class _TimelineTransactionItem extends StatelessWidget {
  final BitcoinTransaction transaction;
  final WalletProvider walletProvider;
  final CurrencyRateProvider currencyProvider;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _TimelineTransactionItem({
    Key? key,
    required this.transaction,
    required this.walletProvider,
    required this.currencyProvider,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final diff = transaction.balanceDiff;
    final isSent = diff < 0;
    final isConfirmed = transaction.confirmed;

    // لون الدائرة
    Color dotColor;
    if (!isConfirmed) {
      dotColor = Colors.orange;
    } else {
      dotColor = isSent ? Colors.pinkAccent : Colors.green;
    }

    final label = isSent ? "Sent" : "Received";
    final dateStr =
        isConfirmed ? _formatTime(transaction.blockTime) : "Pending...";

    // القيمة الأساسية (سات -> BTC)
    final absValue = diff.abs();
    final mainValue = _formatBTC(absValue);

    // العملة الورقية
    String? displayFiat;
    if (currencyProvider.rate != null && currencyProvider.rate! > 0) {
      final double fiatVal = (absValue / 100000000.0) * currencyProvider.rate!;
      displayFiat =
          "${fiatVal.toStringAsFixed(2)} ${currencyProvider.fiatSymbol}";
    }

    // لون المبلغ
    Color amountColor;
    if (!isConfirmed) {
      amountColor = Colors.orange;
    } else {
      amountColor = isSent ? Colors.red : Colors.green;
    }

    return InkWell(
      onTap: onTap,
      child: Stack(
        children: [
          // الخط العمودي
          Positioned(
            left: 20,
            top: 0,
            bottom: 0,
            child: _VerticalLine(isFirst: isFirst, isLast: isLast),
          ),
          Padding(
            padding:
                const EdgeInsets.only(left: 50, right: 16, top: 16, bottom: 16),
            child: Row(
              children: [
                // النصوص
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                // المبلغ
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      (isSent ? "-" : "+") + mainValue,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: amountColor,
                      ),
                    ),
                    if (displayFiat != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          displayFiat,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // الدائرة
          Positioned(
            left: 10,
            top: 20,
            child: _TimelineDot(color: dotColor),
          ),
        ],
      ),
    );
  }

  String _formatBTC(int sat) {
    if (walletProvider.currentUnit == "SAT") {
      return "$sat SATS";
    } else {
      final btcVal = sat / 100000000.0;
      return "${btcVal.toStringAsFixed(8)} BTC";
    }
  }

  String _formatTime(int blockTime) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      blockTime * 1000,
      isUtc: true,
    ).toLocal();
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year;
    return "$h:$min, $d.$m.$y";
  }
}

// =====================================================================
// الخط العمودي في الـ Timeline
// =====================================================================
class _VerticalLine extends StatelessWidget {
  final bool isFirst;
  final bool isLast;

  const _VerticalLine({
    Key? key,
    required this.isFirst,
    required this.isLast,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        return Column(
          children: [
            if (!isFirst)
              Container(width: 2, height: 20, color: Colors.grey[300]),
            Expanded(
              child: !isLast
                  ? Container(width: 2, color: Colors.grey[300])
                  : const SizedBox(),
            ),
          ],
        );
      },
    );
  }
}

// =====================================================================
// الدائرة الملونة في الـ Timeline
// =====================================================================
class _TimelineDot extends StatelessWidget {
  final Color color;

  const _TimelineDot({Key? key, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
    );
  }
}

// =====================================================================
// BottomSheet لعرض تفاصيل المعاملة
// =====================================================================
class _TransactionDetailSheet extends StatelessWidget {
  final BitcoinTransaction transaction;
  final WalletProvider walletProvider;
  final CurrencyRateProvider currencyProvider;
  final List<String> allMyAddresses;

  const _TransactionDetailSheet({
    Key? key,
    required this.transaction,
    required this.walletProvider,
    required this.currencyProvider,
    required this.allMyAddresses,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final diff = transaction.balanceDiff;
    final isSent = diff < 0;
    final isConfirmed = transaction.confirmed;

    final label = isSent ? 'You sent' : 'You received';
    final absVal = diff.abs();

    // BTC/سات
    final displayBtc = _formatBTC(absVal);

    // العملة الورقية
    String? displayFiat;
    if (currencyProvider.rate != null && currencyProvider.rate! > 0) {
      final double fiatVal = (absVal / 100000000.0) * currencyProvider.rate!;
      displayFiat =
          "${fiatVal.toStringAsFixed(2)} ${currencyProvider.fiatSymbol}";
    }

    final statusText = isConfirmed ? "Confirmed" : "Pending";
    final statusColor = isConfirmed ? Colors.green : Colors.orange;

    // Fee
    final feeSat = _computeFee();
    final displayFeeBtc = _formatBTC(feeSat);
    String? displayFeeFiat;
    if (currencyProvider.rate != null && currencyProvider.rate! > 0) {
      final feeFiatVal = (feeSat / 100000000.0) * currencyProvider.rate!;
      displayFeeFiat =
          "${feeFiatVal.toStringAsFixed(2)} ${currencyProvider.fiatSymbol}";
    }

    final confirmations = isConfirmed ? "6+" : "0";

    final dateLocal = DateTime.fromMillisecondsSinceEpoch(
      transaction.blockTime * 1000,
      isUtc: true,
    ).toLocal();
    final dateStr = _formatDate(dateLocal);

    final mainAddress = isSent
        ? _getExternalAddress(transaction.outputs)
        : _getInternalAddress(transaction.outputs);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // مقبض
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Transaction Detail',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            Text(
              displayBtc,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            if (displayFiat != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  displayFiat,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              statusText,
              style: TextStyle(fontSize: 16, color: statusColor),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DetailItem(title: "When", value: dateStr),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DetailItem(
                    title: "Confirmations",
                    value: confirmations,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DetailItem(
                    title: "Amount",
                    value: displayFiat == null
                        ? displayBtc
                        : "$displayBtc\n($displayFiat)",
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DetailItem(
                    title: "Fee",
                    value: displayFeeFiat == null
                        ? displayFeeBtc
                        : "$displayFeeBtc\n($displayFeeFiat)",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(thickness: 1),
            const SizedBox(height: 16),
            Text(
              isSent ? "Sent to address" : "Received in address",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            if (mainAddress != null)
              _AddressRowFullWithCopy(address: mainAddress, isTx: false),
            const SizedBox(height: 16),
            const Text(
              "Transaction ID",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            _TxidRowFullWithShare(txid: transaction.txid),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  int _computeFee() {
    if (transaction.fee != 0) return transaction.fee;
    int sumIn = 0;
    for (var i in transaction.inputs) {
      sumIn += i.value;
    }
    int sumOut = 0;
    for (var o in transaction.outputs) {
      sumOut += o.value;
    }
    return sumIn - sumOut;
  }

  String? _getExternalAddress(List<Output> outputs) {
    for (var o in outputs) {
      final addr = o.address;
      if (addr.isNotEmpty && !allMyAddresses.contains(addr)) {
        return addr;
      }
    }
    return null;
  }

  String? _getInternalAddress(List<Output> outputs) {
    for (var o in outputs) {
      final addr = o.address;
      if (allMyAddresses.contains(addr)) {
        return addr;
      }
    }
    return null;
  }

  String _formatBTC(int sat) {
    if (walletProvider.currentUnit == "SAT") {
      return "$sat SATS";
    } else {
      final btcVal = sat / 100000000.0;
      return "${btcVal.toStringAsFixed(8)} BTC";
    }
  }

  String _formatDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yyyy = date.year;
    final hh = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return "$hh:$min, $dd.$mm.$yyyy";
  }
}

// ======================================================================
// عنصر لعرض عنوان + قيمة (مثال: When, Confirmations, Amount, Fee)
// ======================================================================
class _DetailItem extends StatelessWidget {
  final String title;
  final String value;

  const _DetailItem({Key? key, required this.title, required this.value})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// عنصر لعرض العنوان Address + زر نسخ + إمكانية فتحه في متصفح mempool
// ======================================================================
class _AddressRowFullWithCopy extends StatelessWidget {
  final String address;
  final bool isTx;

  const _AddressRowFullWithCopy({
    Key? key,
    required this.address,
    this.isTx = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              final url = isTx
                  ? 'https://mempool.space/tx/$address'
                  : 'https://mempool.space/address/$address';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                );
              }
            },
            child: Text(
              address,
              style: const TextStyle(fontSize: 14, color: Colors.blue),
              maxLines: 3,
              overflow: TextOverflow.visible,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () {
            HapticFeedback.lightImpact();
            Clipboard.setData(ClipboardData(text: address));
          },
        ),
      ],
    );
  }
}

// ======================================================================
// عنصر لعرض الـ txid + إمكانية فتحه في المتصفح أو مشاركته
// ======================================================================
class _TxidRowFullWithShare extends StatelessWidget {
  final String txid;

  const _TxidRowFullWithShare({Key? key, required this.txid}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              final url = 'https://mempool.space/tx/$txid';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                );
              }
            },
            child: Text(
              txid,
              style: const TextStyle(fontSize: 14, color: Colors.blue),
              maxLines: 3,
              overflow: TextOverflow.visible,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.share, size: 18),
          onPressed: () {
            HapticFeedback.lightImpact();
            Share.share(txid, subject: 'Transaction ID');
          },
        ),
      ],
    );
  }
}
