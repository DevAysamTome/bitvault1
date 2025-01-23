import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback and Clipboard
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'wallet_provider.dart';
import 'transactions_provider.dart';
import 'currency_rate_provider.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({Key? key}) : super(key: key);

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchTransactionsIfPossible();
    });
  }

  /// Collect all addresses for the currently selected BIP type (BIP44/49/84).
  List<String> _getAllAddressesForCurrentBip(WalletProvider walletProv) {
    if (walletProv.walletData == null) return [];
    final preferredKey = walletProv.preferredBipType;
    final dataObj = walletProv.walletData?['data']?[preferredKey];
    if (dataObj == null) return [];

    final List<String> addresses = [];

    // receive
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

    // change
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

  /// Fetch the transaction history if wallet data and addresses are available.
  Future<void> _fetchTransactionsIfPossible() async {
    final walletProv = context.read<WalletProvider>();
    if (walletProv.walletData == null) return;

    final allAddresses = _getAllAddressesForCurrentBip(walletProv);
    if (allAddresses.isEmpty) {
      return;
    }

    final addressesStr = allAddresses.join('|');
    await context.read<TransactionsProvider>().fetchTransactions(addressesStr);
  }

  @override
  Widget build(BuildContext context) {
    final walletProv = context.watch<WalletProvider>();
    final txProv = context.watch<TransactionsProvider>();
    final currencyProv = context.watch<CurrencyRateProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1F4F8),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Transactions',
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _buildTransactionsSection(walletProv, txProv, currencyProv),
    );
  }

  Widget _buildTransactionsSection(
    WalletProvider walletProv,
    TransactionsProvider txProv,
    CurrencyRateProvider currencyProv,
  ) {
    if (txProv.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (txProv.errorMessage != null) {
      return Center(
        child: Text(
          'Error: ${txProv.errorMessage}',
          style: const TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 16),
        ),
      );
    }
    if (txProv.transactionData == null) {
      return const Center(
        child: Text(
          'No transactions loaded yet.',
          style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 16),
        ),
      );
    }

    final txList = txProv.transactionData!.result.transactions;
    if (txList.isEmpty) {
      return const Center(
        child: Text(
          'No transactions found for these addresses.',
          style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: txList.length,
      itemBuilder: (context, index) {
        final tx = txList[index];
        return _TimelineTransactionItem(
          transaction: tx,
          walletProvider: walletProv,
          currencyProvider: currencyProv,
          isFirst: index == 0,
          isLast: index == txList.length - 1,
          onTap: () => _showDetailSheet(context, tx, walletProv, currencyProv),
        );
      },
    );
  }

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
      builder: (ctx) => _TransactionDetailSheet(
        transaction: transaction,
        walletProvider: walletProv,
        currencyProvider: currencyProv,
        allMyAddresses: _getAllAddressesForCurrentBip(walletProv),
      ),
    );
  }
}

class _TimelineTransactionItem extends StatelessWidget {
  const _TimelineTransactionItem({
    Key? key,
    required this.transaction,
    required this.walletProvider,
    required this.currencyProvider,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  }) : super(key: key);

  final BitcoinTransaction transaction;
  final WalletProvider walletProvider;
  final CurrencyRateProvider currencyProvider;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final diff = transaction.balanceDiff;
    final isSent = diff < 0;
    final isConfirmed = transaction.confirmed;

    Color dotColor;
    if (!isConfirmed) {
      dotColor = Colors.orange;
    } else {
      dotColor = isSent ? Colors.pinkAccent : Colors.green;
    }

    final label = isSent ? "Sent" : "Receive";
    final dateStr = isConfirmed ? _timeString(transaction.blockTime) : "Pending...";
    final absValue = diff.abs();
    final mainValue = _formatBTC(absValue);

    String? displayFiat;
    if (currencyProvider.rate != null && currencyProvider.rate! > 0) {
      final fiatVal = (absValue / 100000000.0) * currencyProvider.rate!;
      displayFiat =
          "${fiatVal.toStringAsFixed(2)} ${currencyProvider.fiatSymbol}";
    }

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
          Positioned(
            left: 20,
            top: 0,
            bottom: 0,
            child: _VerticalLine(
              isFirst: isFirst,
              isLast: isLast,
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.only(left: 50, right: 16, top: 16, bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      (isSent ? '-' : '+') + mainValue,
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
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
                            fontFamily: 'SpaceGrotesk',
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
          Positioned(
            left: 10,
            top: 20,
            child: _TimelineDot(color: dotColor),
          ),
        ],
      ),
    );
  }

  String _formatBTC(int satoshis) {
    if (walletProvider.currentUnit == "SAT") {
      return "$satoshis SATS";
    } else {
      final btcVal = satoshis / 100000000.0;
      return "${btcVal.toStringAsFixed(8)} BTC";
    }
  }

  String _timeString(int blockTime) {
    final date =
        DateTime.fromMillisecondsSinceEpoch(blockTime * 1000, isUtc: true)
            .toLocal();
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final mon = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return "$h:$min, $day.$mon.$year";
  }
}

class _VerticalLine extends StatelessWidget {
  const _VerticalLine({
    Key? key,
    required this.isFirst,
    required this.isLast,
  }) : super(key: key);

  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        return Column(
          children: [
            if (!isFirst)
              Container(
                width: 2,
                height: 20,
                color: Colors.grey[300],
              ),
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
        border: Border.all(
          color: color,
          width: 2,
        ),
      ),
    );
  }
}

class _TransactionDetailSheet extends StatelessWidget {
  const _TransactionDetailSheet({
    Key? key,
    required this.transaction,
    required this.walletProvider,
    required this.currencyProvider,
    required this.allMyAddresses,
  }) : super(key: key);

  final BitcoinTransaction transaction;
  final WalletProvider walletProvider;
  final CurrencyRateProvider currencyProvider;
  final List<String> allMyAddresses;

  @override
  Widget build(BuildContext context) {
    final diff = transaction.balanceDiff;
    final isSent = diff < 0;
    final isConfirmed = transaction.confirmed;

    final label = isSent ? 'You sent' : 'You received';

    final absVal = diff.abs();
    final displayBtc = _formatBTC(absVal);

    String? displayFiat;
    if (currencyProvider.rate != null && currencyProvider.rate! > 0) {
      final fiatVal = (absVal / 100000000.0) * currencyProvider.rate!;
      displayFiat =
          "${fiatVal.toStringAsFixed(2)} ${currencyProvider.fiatSymbol}";
    }

    final statusText = isConfirmed ? "Confirmed" : "Pending";
    final statusColor = isConfirmed ? Colors.green : Colors.orange;

    final feeSat = _computeFee(transaction);
    final displayFeeBtc = _formatBTC(feeSat);
    String? displayFeeFiat;
    if (currencyProvider.rate != null && currencyProvider.rate! > 0) {
      final fiatVal = (feeSat / 100000000.0) * currencyProvider.rate!;
      displayFeeFiat =
          "${fiatVal.toStringAsFixed(2)} ${currencyProvider.fiatSymbol}";
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
                fontFamily: 'SpaceGrotesk',
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            Text(
              displayBtc,
              style: const TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (displayFiat != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  displayFiat,
                  style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              statusText,
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 16,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DetailItem(title: "When", value: dateStr),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child:
                      _DetailItem(title: "Confirmations", value: confirmations),
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
              style: const TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            if (mainAddress != null)
              _AddressRowFullWithCopy(address: mainAddress, isTx: false),
            const SizedBox(height: 16),
            const Text(
              "Transaction ID",
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            _TxidRowFullWithShare(txid: transaction.txid),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  int _computeFee(BitcoinTransaction tx) {
    if (tx.fee != 0) return tx.fee;
    int sumIn = 0;
    for (var i in tx.inputs) {
      sumIn += i.value;
    }
    int sumOut = 0;
    for (var o in tx.outputs) {
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

class _DetailItem extends StatelessWidget {
  final String title;
  final String value;

  const _DetailItem({
    Key? key,
    required this.title,
    required this.value,
  }) : super(key: key);

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
            style: const TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'SpaceGrotesk',
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              final url = isTx
                  ? 'https://mempool.space/tx/$address'
                  : 'https://mempool.space/address/$address';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url),
                    mode: LaunchMode.externalApplication);
              }
            },
            child: Text(
              address,
              style: const TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 14,
                color: Colors.blue,
              ),
              maxLines: 3,
              overflow: TextOverflow.visible,
              softWrap: true,
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

class _TxidRowFullWithShare extends StatelessWidget {
  final String txid;

  const _TxidRowFullWithShare({Key? key, required this.txid}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              final url = 'https://mempool.space/tx/$txid';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url),
                    mode: LaunchMode.externalApplication);
              }
            },
            child: Text(
              txid,
              style: const TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 14,
                color: Colors.blue,
              ),
              maxLines: 3,
              overflow: TextOverflow.visible,
              softWrap: true,
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
