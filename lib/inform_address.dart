import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'wallet_provider.dart';

class InformAddressPage extends StatelessWidget {
  const InformAddressPage({Key? key}) : super(key: key);

  String _getMappedKey(String bipType) {
    switch (bipType) {
      case WalletProvider.bip44:
        return 'BIP44';
      case WalletProvider.bip49:
        return 'BIP49';
      case WalletProvider.bip84:
        return 'BIP84';
      default:
        return 'BIP44';
    }
  }

  String _truncateAddress(String address, {int prefix = 8, int suffix = 8}) {
    if (address.length <= (prefix + suffix)) {
      return address;
    }
    return '${address.substring(0, prefix)}...${address.substring(address.length - suffix)}';
  }

  List<Map<String, dynamic>> _getReceiveAddresses(WalletProvider walletProv) {
    final data = walletProv.walletData;
    if (data == null) return [];

    final mappedKey = _getMappedKey(walletProv.preferredBipType);
    final bipObj = data['data']?[mappedKey];
    if (bipObj == null) return [];

    final receiveObj = bipObj['receive'];
    if (receiveObj == null) return [];

    final usedArr = receiveObj['used'] as List? ?? [];
    final freshObj = receiveObj['fresh'];

    List<Map<String, dynamic>> allAddresses = [];

    for (var addr in usedArr) {
      final String address = addr['address'] ?? '';
      final bool used = addr['used'] ?? false;
      final int txCount = addr['confirmedTxCount'] ?? 0;
      final String path = addr['path'] ?? 'N/A';

      allAddresses.add({
        "address": address,
        "used": used,
        "txCount": txCount,
        "path": path,
      });
    }

    if (freshObj != null) {
      final String address = freshObj['address'] ?? '';
      final bool used = freshObj['used'] ?? false;
      final int txCount = freshObj['confirmedTxCount'] ?? 0;
      final String path = freshObj['path'] ?? 'N/A';

      allAddresses.add({
        "address": address,
        "used": used,
        "txCount": txCount,
        "path": path,
      });
    }

    return allAddresses;
  }

  List<Map<String, dynamic>> _getChangeAddresses(WalletProvider walletProv) {
    final data = walletProv.walletData;
    if (data == null) return [];

    final mappedKey = _getMappedKey(walletProv.preferredBipType);
    final bipObj = data['data']?[mappedKey];
    if (bipObj == null) return [];

    final changeObj = bipObj['change'];
    if (changeObj == null) return [];

    final usedArr = changeObj['used'] as List? ?? [];
    final freshObj = changeObj['fresh'];

    List<Map<String, dynamic>> allAddresses = [];

    for (var addr in usedArr) {
      final String address = addr['address'] ?? '';
      final bool used = addr['used'] ?? false;
      final int txCount = addr['confirmedTxCount'] ?? 0;
      final String path = addr['path'] ?? 'N/A';

      allAddresses.add({
        "address": address,
        "used": used,
        "txCount": txCount,
        "path": path,
      });
    }

    if (freshObj != null) {
      final String address = freshObj['address'] ?? '';
      final bool used = freshObj['used'] ?? false;
      final int txCount = freshObj['confirmedTxCount'] ?? 0;
      final String path = freshObj['path'] ?? 'N/A';

      allAddresses.add({
        "address": address,
        "used": used,
        "txCount": txCount,
        "path": path,
      });
    }

    return allAddresses;
  }

  Widget _buildAddressItem(
    Map<String, dynamic> addressData,
    int index, {
    required bool isReceiveTab,
  }) {
    final bool isUsed = addressData['used'] as bool;
    final String address = addressData['address'] ?? '';
    final int txCount = addressData['txCount'] ?? 0;
    final String path = addressData['path'] ?? 'N/A';

    late String statusLabel;
    late Color chipColor;
    late Color chipTextColor;

    if (isUsed) {
      statusLabel = "Used";
      chipColor = Colors.grey[300]!;
      chipTextColor = Colors.black54;
    } else {
      if (isReceiveTab) {
        statusLabel = "Receive";
        chipColor = Colors.green[100]!;
        chipTextColor = Colors.green[800]!;
      } else {
        statusLabel = "Change";
        chipColor = Colors.orange[100]!;
        chipTextColor = Colors.orange[800]!;
      }
    }

    final String truncatedAddr = _truncateAddress(address);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Clipboard.setData(ClipboardData(text: address));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${index + 1} $truncatedAddr",
                  style: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'SpaceGrotesk',
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  path,
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'SpaceGrotesk',
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: chipColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      color: chipTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Transactions: $txCount",
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'SpaceGrotesk',
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressesList(
    List<Map<String, dynamic>> addresses, {
    required bool isReceiveTab,
  }) {
    return ListView.builder(
      itemCount: addresses.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return _buildAddressItem(
          addresses[index],
          index,
          isReceiveTab: isReceiveTab,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletProv = Provider.of<WalletProvider>(context, listen: true);

    final receiveAddresses = _getReceiveAddresses(walletProv);
    final changeAddresses = _getChangeAddresses(walletProv);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F4F8),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
          ),
          title: const Text(
            "Addresses",
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              color: Colors.black,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: const Color(0xFFF1F4F8),
          bottom: TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.black,
            splashFactory: NoSplash.splashFactory,
            overlayColor: MaterialStateProperty.all(Colors.transparent),
            tabs: const [
              Tab(text: "Receive"),
              Tab(text: "Change"),
            ],
            onTap: (index) {
              HapticFeedback.lightImpact();
            },
          ),
        ),
        body: TabBarView(
          children: [
            _buildAddressesList(
              receiveAddresses,
              isReceiveTab: true,
            ),
            _buildAddressesList(
              changeAddresses,
              isReceiveTab: false,
            ),
          ],
        ),
      ),
    );
  }
}
