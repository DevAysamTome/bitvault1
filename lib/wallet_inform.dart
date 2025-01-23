import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'wallet_provider.dart';
import 'backup_mnemonic.dart';
import 'inform_address.dart';

class WalletInformPage extends StatefulWidget {
  const WalletInformPage({super.key});

  @override
  State<WalletInformPage> createState() => _WalletInformPageState();
}

class _WalletInformPageState extends State<WalletInformPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      if (walletProvider.lastMnemonic != null &&
          walletProvider.lastMnemonic!.isNotEmpty) {
        walletProvider.fetchWalletData(
          mnemonic: walletProvider.lastMnemonic!,
          passphrase: '',
        );
      }
    });
  }

  int getTotalTransactions(Map<String, dynamic> data) {
    int totalTxCount = 0;

    void accumulateUsedList(List? usedList) {
      if (usedList == null) return;
      for (var addr in usedList) {
        if (addr is Map && addr['totalTxCount'] != null) {
          final num val = addr['totalTxCount'];
          totalTxCount += val.toInt();
        }
      }
    }

    void accumulateFreshAddr(Map? fresh) {
      if (fresh == null) return;
      if (fresh['totalTxCount'] != null) {
        final num val = fresh['totalTxCount'];
        totalTxCount += val.toInt();
      }
    }

    if (data['receive'] is Map) {
      final receive = data['receive'] as Map;
      if (receive['used'] is List) accumulateUsedList(receive['used']);
      if (receive['fresh'] is Map) accumulateFreshAddr(receive['fresh']);
    }

    if (data['change'] is Map) {
      final change = data['change'] as Map;
      if (change['used'] is List) accumulateUsedList(change['used']);
      if (change['fresh'] is Map) accumulateFreshAddr(change['fresh']);
    }

    return totalTxCount;
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = Provider.of<WalletProvider>(context, listen: true);

    final String currentBipKey = walletProvider.preferredBipType;
    final Map<String, dynamic>? bipData =
        walletProvider.walletData?['data']?[currentBipKey];

    final String bipDescription =
        (bipData != null && bipData['description'] != null)
            ? bipData['description']
            : 'Unknown type';

    final String bipDerivationPath =
        (bipData != null && bipData['derivationPath'] != null)
            ? bipData['derivationPath']
            : 'N/A';

    final int transactionCount =
        (bipData != null) ? getTotalTransactions(bipData) : 0;

    final String mnemonic = walletProvider.lastMnemonic ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1F4F8),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Wallet Information',
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            color: Colors.black,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: const Color(0xFFF1F4F8),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              margin: const EdgeInsets.only(bottom: 12.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Type',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    bipDescription,
                    style: const TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16.0),
              margin: const EdgeInsets.only(bottom: 12.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Derivation Path',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    bipDerivationPath,
                    style: const TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16.0),
              margin: const EdgeInsets.only(bottom: 12.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Transactions Count',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    '$transactionCount',
                    style: const TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16.0),
              margin: const EdgeInsets.only(bottom: 12.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InformAddressPage(),
                    ),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Show addresses',
                      style: TextStyle(
                        color: Colors.black,
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 16,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3949AB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      textStyle: const TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BackupMnemonicPage(
                            mnemonic: mnemonic,
                          ),
                        ),
                      );
                    },
                    child: const Text('Export/Backup'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
