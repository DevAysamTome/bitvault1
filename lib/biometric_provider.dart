import 'dart:async';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class BiometricProvider extends ChangeNotifier {
  final LocalAuthentication _auth = LocalAuthentication();
  DateTime? _pausedTime;
  DateTime? _lastAuthenticatedTime;
  bool _authenticated = false;
  bool _enableBiometric = false;
  int _authenticatedCount = 0;
  final int _deadlineInSecs = 0;

  bool get authenticated => _authenticated;

  int get authenticatedCount => _authenticatedCount;

  bool get enableBiometric => _enableBiometric;

  Future<void> authenticate({bool force = false}) async {
    try {
      if (!_authenticated || force) {
        _authenticated = await _auth.authenticate(
          localizedReason: 'Please authenticate to access the app',
          options: AuthenticationOptions(
            biometricOnly: false,
            stickyAuth: true,
          ),
        );

        if (_authenticated) {
          _lastAuthenticatedTime = DateTime.now();
          debugPrint('Authentication successful');
        } else {
          debugPrint('Authentication failed');
        }
        notifyListeners();
      } else {
        debugPrint('Already authenticated, skipping authentication');
      }
    } catch (e) {
      debugPrint('Authentication error: $e');
    }
  }

  void changeBiometricStatus({bool? disable}) {
    if (!_enableBiometric) {
      authenticate();
    }
    debugPrint("disable $disable");
    if (disable != null) {
      if (disable) {
        _enableBiometric = false;
        notifyListeners();
        debugPrint("disable $disable");
      } else {
        _enableBiometric = true;
        notifyListeners();
        debugPrint("disable $disable");
      }
    } else {
      debugPrint("disable fel");
      _enableBiometric = !_enableBiometric;
    }
    notifyListeners();
    debugPrint('_enableBiometric $_enableBiometric');
  }

  void onAppPaused() {
    if (_enableBiometric) {
      if (_authenticatedCount == 0) {
        _pausedTime = DateTime.now();
        debugPrint('App paused at $_pausedTime');
        _authenticatedCount = 1;
        notifyListeners();
      }
    }
  }

  void onAppResumed() {
    debugPrint('onAppResumed _enableBiometric $_enableBiometric');

    if (!_enableBiometric) return;
    if (_pausedTime == null) return;

    final duration = DateTime.now().difference(_pausedTime!);
    debugPrint('App resumed after ${duration.inSeconds} seconds');

    if (duration.inSeconds >= _deadlineInSecs) {
      if (_lastAuthenticatedTime == null ||
          _lastAuthenticatedTime!.isBefore(_pausedTime!)) {
        _authenticated = false;
        _authenticatedCount = 0;
        notifyListeners();
        debugPrint(
            'App was paused for $_deadlineInSecs seconds or more, requiring re-authentication');
        notifyListeners();
      }
    }

    if (duration.inSeconds >= _deadlineInSecs && !_authenticated) {
      debugPrint('Triggering re-authentication');
      authenticate(force: true);
    } else {
      debugPrint('No re-authentication required');
    }
  }
}
