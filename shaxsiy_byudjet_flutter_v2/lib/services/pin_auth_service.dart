import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinAuthService {
  static const _pinKey = 'pin_code';
  static const _pinEnabledKey = 'pin_enabled';
  final LocalAuthentication _localAuth = LocalAuthentication();
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get prefs => _prefs ?? (throw StateError('Prefs init qilinmagan'));

  Future<bool> isPinEnabled() async => prefs.getBool(_pinEnabledKey) ?? false;

  Future<void> setPin(String pin, {bool enable = true}) async {
    await prefs.setString(_pinKey, pin);
    await prefs.setBool(_pinEnabledKey, enable);
  }

  Future<void> disablePin() async {
    await prefs.setBool(_pinEnabledKey, false);
  }

  Future<bool> verifyPin(String pin) async {
    final saved = prefs.getString(_pinKey);
    return saved != null && saved == pin;
  }

  Future<bool> tryBiometric() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      if (!canCheck || !supported) return false;
      return _localAuth.authenticate(
        localizedReason: 'Shaxsiy byudjet ilovasini ochish',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: false),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> tryUnlockWithBiometricOrPin(BuildContext context) async {
    final bio = await tryBiometric();
    if (bio) return true;
    if (!context.mounted) return false;
    final pin = await _showPinDialog(context, title: 'PIN kiriting');
    if (pin == null) return false;
    return verifyPin(pin);
  }

  Future<String?> _showPinDialog(BuildContext context, {required String title}) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          decoration: const InputDecoration(labelText: 'PIN (4-6 raqam)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Bekor')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> setupPinFlow(BuildContext context) async {
    final pin1 = await _showPinDialog(context, title: 'Yangi PIN kiriting');
    if (pin1 == null || pin1.length < 4) return;
    if (!context.mounted) return;
    final pin2 = await _showPinDialog(context, title: 'PINni qayta kiriting');
    if (pin2 == null || pin1 != pin2) return;
    await setPin(pin1, enable: true);
  }
}
