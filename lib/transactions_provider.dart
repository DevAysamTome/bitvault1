import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TransactionsProvider with ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  TransactionActivityResponse? _transactionData;
  TransactionActivityResponse? get transactionData => _transactionData;

  Future<void> fetchTransactions(String addresses) async {
    final url = 'https://generate-wallet.vercel.app/api/activity';
    final body = jsonEncode({
      'addresses': addresses,
    });

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final response = await http.post(
        Uri.parse(url),
        body: body,
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body) as Map<String, dynamic>;

        _transactionData = TransactionActivityResponse.fromJson(decodedData);
        _errorMessage = null;
      } else {
        _transactionData = null;
        _errorMessage = 'فشل في جلب البيانات. رمز الاستجابة: ${response.statusCode}';
      }
    } catch (error) {
      _transactionData = null;
      _errorMessage = 'حدث خطأ: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

// ----------------------------------------------------------
//                     Models
// ----------------------------------------------------------

class TransactionActivityResponse {
  final String status;
  final String message;
  final String timestamp;
  final int transactionsCount;
  final int scanDurationMs;
  final TransactionsResult result;

  TransactionActivityResponse({
    required this.status,
    required this.message,
    required this.timestamp,
    required this.transactionsCount,
    required this.scanDurationMs,
    required this.result,
  });

  factory TransactionActivityResponse.fromJson(Map<String, dynamic> json) {
    return TransactionActivityResponse(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      timestamp: json['timestamp'] ?? '',
      transactionsCount: json['transactionsCount'] ?? 0,
      scanDurationMs: json['scanDurationMs'] ?? 0,
      result: TransactionsResult.fromJson(json['result'] ?? {}),
    );
  }
}

class TransactionsResult {
  final List<String> addresses;
  final List<BitcoinTransaction> transactions;

  TransactionsResult({
    required this.addresses,
    required this.transactions,
  });

  factory TransactionsResult.fromJson(Map<String, dynamic> json) {
    final addressesList = (json['addresses'] as List<dynamic>?)
            ?.map((address) => address.toString())
            .toList() ??
        [];
    final transactionsList = (json['transactions'] as List<dynamic>?)
            ?.map((trans) => BitcoinTransaction.fromJson(trans))
            .toList() ??
        [];

    return TransactionsResult(
      addresses: addressesList,
      transactions: transactionsList,
    );
  }
}

class BitcoinTransaction {
  final String txid;
  final int height;
  final int blockTime;
  final bool confirmed;
  final bool isRBF;
  final String rawHex;
  final List<Input> inputs;
  final List<Output> outputs;
  final int balanceDiff;
  final bool isLastTransaction;
  final int fee;

  BitcoinTransaction({
    required this.txid,
    required this.height,
    required this.blockTime,
    required this.confirmed,
    required this.isRBF,
    required this.rawHex,
    required this.inputs,
    required this.outputs,
    required this.balanceDiff,
    required this.isLastTransaction,
    required this.fee,
  });

  factory BitcoinTransaction.fromJson(Map<String, dynamic> json) {
    final inputsList = (json['inputs'] as List<dynamic>?)
            ?.map((input) => Input.fromJson(input))
            .toList() ??
        [];
    final outputsList = (json['outputs'] as List<dynamic>?)
            ?.map((output) => Output.fromJson(output))
            .toList() ??
        [];

    return BitcoinTransaction(
      txid: json['txid'] ?? '',
      height: json['height'] ?? 0,
      blockTime: json['blockTime'] ?? 0,
      confirmed: json['confirmed'] ?? false,
      isRBF: json['isRBF'] ?? false,
      rawHex: json['rawHex'] ?? '',
      inputs: inputsList,
      outputs: outputsList,
      balanceDiff: json['balance_diff'] ?? 0,
      isLastTransaction: json['isLastTransaction'] ?? false,
      fee: json['fee'] ?? 0,
    );
  }
}

class Input {
  final int index;
  final String prevTxid;
  final int prevVout;
  final String address;
  final int value;

  Input({
    required this.index,
    required this.prevTxid,
    required this.prevVout,
    required this.address,
    required this.value,
  });

  factory Input.fromJson(Map<String, dynamic> json) {
    return Input(
      index: json['index'] ?? 0,
      prevTxid: json['prevTxid'] ?? '',
      prevVout: json['prevVout'] ?? 0,
      address: json['address'] ?? '',
      value: json['value'] ?? 0,
    );
  }
}

class Output {
  final int index;
  final String address;
  final int value;

  Output({
    required this.index,
    required this.address,
    required this.value,
  });

  factory Output.fromJson(Map<String, dynamic> json) {
    return Output(
      index: json['index'] ?? 0,
      address: json['address'] ?? '',
      value: json['value'] ?? 0,
    );
  }
}
