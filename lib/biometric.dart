part of 'main.dart';

// ═════════════════════════ الدخول بالبصمة ═════════════════════════
//
// بعد أول دخول ناجح بالاسم والباسورد، التطبيق بيسأل المستخدم لو عاوز يفعّل
// البصمة. لو وافق، بيتخزن اسم المستخدم والباسورد في التخزين الآمن للجهاز
// (Android Keystore) ومش بيتخزنوا في SharedPreferences. الدخول بعد كده بيتم
// بعد ما نظام الأندرويد يتأكد من البصمة.

class Bio {
  static final LocalAuthentication _auth = LocalAuthentication();
  static const FlutterSecureStorage _store = FlutterSecureStorage();
  static const String _kUser = 'bio_user';
  static const String _kPass = 'bio_pass';

  /// الجهاز بيدعم بصمة/قفل بيومتري ومتسجّل عليه حاجة.
  static Future<bool> available() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      final types = await _auth.getAvailableBiometrics();
      return types.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasSaved() async {
    try {
      final p = await _store.read(key: _kPass);
      return p != null && p.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> savedUser() async {
    try {
      return await _store.read(key: _kUser);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String user, String password) async {
    try {
      await _store.write(key: _kUser, value: user);
      await _store.write(key: _kPass, value: password);
    } catch (_) {}
  }

  static Future<void> forget() async {
    try {
      await _store.delete(key: _kUser);
      await _store.delete(key: _kPass);
    } catch (_) {}
  }

  /// بيطلب البصمة. true لو نجحت.
  static Future<bool> confirm() async {
    try {
      return await _auth.authenticate(
        localizedReason: tr('ادخل بالبصمة'),
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// بيرجّع {'user':..., 'pass':...} بعد نجاح البصمة، أو null.
  static Future<Map<String, String>?> unlock() async {
    if (!await confirm()) return null;
    try {
      final u = await _store.read(key: _kUser);
      final p = await _store.read(key: _kPass);
      if (u == null || p == null || u.isEmpty || p.isEmpty) return null;
      return {'user': u, 'pass': p};
    } catch (_) {
      return null;
    }
  }
}
