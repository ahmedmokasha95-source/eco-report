part of 'main.dart';

// ═════════════════════════ الجلسة (تسجيل الدخول) ═════════════════════════

class Session extends ChangeNotifier {
  Session._();
  static final Session instance = Session._();

  String? token;
  String? refreshToken;
  String? userId;
  String? factoryId; // مصنع المبلّغ
  String? viewFactoryId; // المصنع المفتوح حالياً عند المدير
  String username = '';
  String fullName = '';
  String role = '';
  DateTime? expiresAt;

  bool get loggedIn => token != null && userId != null;
  bool get isAdmin => role == 'admin';
  String? get activeFactoryId => isAdmin ? viewFactoryId : factoryId;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      token = p.getString('ses_token');
      refreshToken = p.getString('ses_refresh');
      userId = p.getString('ses_uid');
      factoryId = p.getString('ses_factory');
      username = p.getString('ses_username') ?? '';
      fullName = p.getString('ses_fullname') ?? '';
      role = p.getString('ses_role') ?? '';
      final e = p.getString('ses_exp');
      expiresAt = e == null ? null : DateTime.tryParse(e);
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      Future<void> put(String k, String? v) async {
        if (v == null) {
          await p.remove(k);
        } else {
          await p.setString(k, v);
        }
      }

      await put('ses_token', token);
      await put('ses_refresh', refreshToken);
      await put('ses_uid', userId);
      await put('ses_factory', factoryId);
      await put('ses_username', username);
      await put('ses_fullname', fullName);
      await put('ses_role', role);
      await put('ses_exp', expiresAt?.toIso8601String());
    } catch (_) {}
  }

  /// بيرجّع null لو الدخول نجح، وغير كده رسالة الخطأ.
  Future<String?> login(
      String user, String password, String? pickedFactoryId) async {
    final s = AppSettings.instance;
    final base = s.baseUrl;
    final key = s.serverKey.trim();
    if (base.isEmpty || key.isEmpty || base.contains('PUT-YOUR')) {
      return tr('رابط السيرفر مش متظبط في التطبيق');
    }
    final u = user.trim().toLowerCase();
    if (u.isEmpty || password.isEmpty) return tr('اكتب اسم المستخدم والباسورد');
    try {
      final res = await http
          .post(
            Uri.parse('$base/auth/v1/token?grant_type=password'),
            headers: {'apikey': key, 'Content-Type': 'application/json'},
            body: jsonEncode({'email': '$u@$kUserDomain', 'password': password}),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 400 || res.statusCode == 401) {
        return tr('اسم المستخدم أو الباسورد غلط');
      }
      if (res.statusCode != 200) return trf('فشل الدخول (كود {0})', [res.statusCode]);
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final tok = j['access_token'] as String;
      final uid = (j['user'] as Map)['id'] as String;

      final pr = await http
          .get(
            Uri.parse(
                '$base/rest/v1/profiles?id=eq.$uid&select=username,full_name,role,factory_id'),
            headers: {'apikey': key, 'Authorization': 'Bearer $tok'},
          )
          .timeout(const Duration(seconds: 30));
      if (pr.statusCode != 200) {
        return trf('تعذّر تحميل بيانات الحساب (كود {0})', [pr.statusCode]);
      }
      final rows = jsonDecode(utf8.decode(pr.bodyBytes)) as List;
      if (rows.isEmpty) return tr('الحساب ده غير مفعّل. كلّم المدير');
      final p = rows.first as Map<String, dynamic>;
      final r = (p['role'] ?? 'reporter') as String;
      final fid = p['factory_id'] as String?;
      if (r != 'admin') {
        if (fid == null) return tr('الحساب مش مربوط بمصنع. كلّم المدير');
        if (pickedFactoryId != null && fid != pickedFactoryId) {
          return tr('الحساب ده مش تابع للمصنع اللي اخترته');
        }
      }

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('store_owner') != uid) {
        await ReportStore.saveAll([]);
        await prefs.setString('store_owner', uid);
      }

      token = tok;
      refreshToken = j['refresh_token'] as String?;
      userId = uid;
      role = r;
      factoryId = fid;
      viewFactoryId = null;
      username = (p['username'] ?? u) as String;
      fullName = (p['full_name'] ?? '') as String;
      final secs = (j['expires_in'] as num?)?.toInt() ?? 3600;
      expiresAt = DateTime.now().add(Duration(seconds: secs));
      await _persist();

      AppSettings.instance.setSyncEnabled(true);
      AppSettings.instance
          .setReporterName(fullName.isEmpty ? username : fullName);
      notifyListeners();
      return null;
    } catch (_) {
      return tr('مقدرناش نوصل للسيرفر. راجع الإنترنت');
    }
  }

  Future<void> clear() async {
    token = null;
    refreshToken = null;
    userId = null;
    factoryId = null;
    viewFactoryId = null;
    username = '';
    fullName = '';
    role = '';
    expiresAt = null;
    await _persist();
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove('store_owner');
    } catch (_) {}
    notifyListeners();
  }

  /// بيجدّد التوكن لو قرّب يخلص. false = الجلسة انتهت فعلاً.
  static Future<bool> ensureFresh() async {
    final s = Session.instance;
    if (!s.loggedIn) return true;
    final exp = s.expiresAt;
    if (exp != null &&
        exp.isAfter(DateTime.now().add(const Duration(minutes: 2)))) {
      return true;
    }
    final rt = s.refreshToken;
    if (rt == null) return false;
    try {
      final res = await http
          .post(
            Uri.parse(
                '${AppSettings.instance.baseUrl}/auth/v1/token?grant_type=refresh_token'),
            headers: {
              'apikey': AppSettings.instance.serverKey.trim(),
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'refresh_token': rt}),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        s.token = j['access_token'] as String;
        s.refreshToken = (j['refresh_token'] as String?) ?? rt;
        final secs = (j['expires_in'] as num?)?.toInt() ?? 3600;
        s.expiresAt = DateTime.now().add(Duration(seconds: secs));
        await s._persist();
        return true;
      }
      if (res.statusCode == 400 || res.statusCode == 401) return false;
      return true;
    } catch (_) {
      return true; // مفيش نت: سيب الطلبات تفشل لوحدها
    }
  }
}

// ═════════════════════════ المصانع ═════════════════════════

class FactoryInfo {
  final String id;
  final String name;
  final String? logoUrl;
  const FactoryInfo(this.id, this.name, this.logoUrl);

  factory FactoryInfo.fromJson(Map<String, dynamic> j) => FactoryInfo(
        j['id'] as String,
        (j['name'] ?? '') as String,
        j['logo_url'] as String?,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'logo_url': logoUrl};
}

class FactoryStore extends ChangeNotifier {
  FactoryStore._();
  static final FactoryStore instance = FactoryStore._();

  List<FactoryInfo> items = [];
  bool loading = false;
  String? error;

  FactoryInfo? byId(String? id) {
    if (id == null) return null;
    for (final f in items) {
      if (f.id == id) return f;
    }
    return null;
  }

  String nameOf(String? id) => byId(id)?.name ?? '—';

  Future<void> loadCache() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('factories_cache');
      if (raw == null) return;
      items = (jsonDecode(raw) as List)
          .map((e) => FactoryInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}
  }

  Future<void> refresh() async {
    final s = AppSettings.instance;
    if (s.baseUrl.isEmpty || s.serverKey.trim().isEmpty) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await http
          .get(
            Uri.parse('${s.baseUrl}/rest/v1/factories?select=*&order=created_at.asc'),
            headers: SyncService._headers(),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        items = (jsonDecode(utf8.decode(res.bodyBytes)) as List)
            .map((e) => FactoryInfo.fromJson(e as Map<String, dynamic>))
            .toList();
        try {
          final p = await SharedPreferences.getInstance();
          await p.setString('factories_cache',
              jsonEncode(items.map((f) => f.toJson()).toList()));
        } catch (_) {}
      } else {
        error = trf('تعذّر تحميل المصانع (كود {0})', [res.statusCode]);
      }
    } catch (_) {
      error = tr('مقدرناش نوصل للسيرفر. راجع الإنترنت');
    }
    loading = false;
    notifyListeners();
  }
}

// ═════════════════════════ طلبات المدير ═════════════════════════

class AppUser {
  final String id;
  final String username;
  final String fullName;
  final String role;
  final String? factoryId;
  const AppUser(this.id, this.username, this.fullName, this.role, this.factoryId);

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        j['id'] as String,
        (j['username'] ?? '') as String,
        (j['full_name'] ?? '') as String,
        (j['role'] ?? 'reporter') as String,
        j['factory_id'] as String?,
      );
}

class AdminApi {
  static const Duration _t = Duration(seconds: 30);

  static String get _base => AppSettings.instance.baseUrl;

  static Future<Map<String, dynamic>> _fn(Map<String, dynamic> body) async {
    await Session.ensureFresh();
    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$_base/functions/v1/manage-users'),
            headers: SyncService._headers({'Content-Type': 'application/json'}),
            body: jsonEncode(body),
          )
          .timeout(_t);
    } catch (_) {
      throw SyncException(tr('مقدرناش نوصل للسيرفر. راجع الإنترنت'));
    }
    if (res.statusCode == 404) {
      throw SyncException(tr('دالة manage-users مش منشورة في Supabase لسه'));
    }
    Object? j;
    try {
      j = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {}
    if (res.statusCode >= 200 && res.statusCode < 300 && j is Map<String, dynamic>) {
      return j;
    }
    if (j is Map && j['error'] != null) {
      throw SyncException(j['error'].toString());
    }
    throw SyncException(trf('فشل الطلب (كود {0})', [res.statusCode]));
  }

  static Future<List<AppUser>> listUsers() async {
    final j = await _fn({'action': 'list'});
    return ((j['users'] as List?) ?? const [])
        .map((e) => AppUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> createUser({
    required String username,
    required String password,
    required String fullName,
    required String factoryId,
  }) async {
    await _fn({
      'action': 'create',
      'username': username,
      'password': password,
      'full_name': fullName,
      'factory_id': factoryId,
    });
  }

  static Future<void> resetPassword(String id, String password) async {
    await _fn({'action': 'reset_password', 'id': id, 'password': password});
  }

  static Future<void> deleteUser(String id) async {
    await _fn({'action': 'delete', 'id': id});
  }

  static Future<String> uploadLogo(XFile f) async {
    await Session.ensureFresh();
    final bytes = await f.readAsBytes();
    final png = f.path.toLowerCase().endsWith('.png');
    final name =
        'logo_${DateTime.now().millisecondsSinceEpoch}.${png ? 'png' : 'jpg'}';
    final res = await http
        .post(
          Uri.parse('$_base/storage/v1/object/factory-logos/$name'),
          headers: SyncService._headers(
              {'Content-Type': png ? 'image/png' : 'image/jpeg'}),
          body: bytes,
        )
        .timeout(const Duration(seconds: 90));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return '$_base/storage/v1/object/public/factory-logos/$name';
    }
    throw SyncException(trf('فشل رفع الشعار (كود {0}). تأكد إنك شغّلت سكربت v2', [res.statusCode]));
  }

  static Future<void> saveFactory(
      {String? id, required String name, String? logoUrl}) async {
    await Session.ensureFresh();
    final http.Response res;
    if (id == null) {
      res = await http
          .post(
            Uri.parse('$_base/rest/v1/factories'),
            headers: SyncService._headers(
                {'Content-Type': 'application/json', 'Prefer': 'return=minimal'}),
            body: jsonEncode({'name': name, 'logo_url': logoUrl}),
          )
          .timeout(_t);
    } else {
      res = await http
          .patch(
            Uri.parse('$_base/rest/v1/factories?id=eq.$id'),
            headers: SyncService._headers(
                {'Content-Type': 'application/json', 'Prefer': 'return=minimal'}),
            body: jsonEncode({'name': name, if (logoUrl != null) 'logo_url': logoUrl}),
          )
          .timeout(_t);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SyncException(trf('فشل حفظ المصنع (كود {0})', [res.statusCode]));
    }
  }

  static Future<void> deleteFactory(String id) async {
    await Session.ensureFresh();
    final res = await http
        .delete(
          Uri.parse('$_base/rest/v1/factories?id=eq.$id'),
          headers: SyncService._headers({'Prefer': 'return=minimal'}),
        )
        .timeout(_t);
    if (res.statusCode == 409) {
      throw SyncException(tr('مينفعش تحذف مصنع عليه بلاغات'));
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SyncException(trf('فشل الحذف (كود {0})', [res.statusCode]));
    }
  }
}

// ═════════════════════════ أدوات مشتركة ═════════════════════════

Route<T> fadeRoute<T>(Widget page, {int ms = 500}) {
  return PageRouteBuilder<T>(
    transitionDuration: Duration(milliseconds: ms),
    reverseTransitionDuration: Duration(milliseconds: ms),
    pageBuilder: (context, animation, secondary) => page,
    transitionsBuilder: (context, animation, secondary, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}

Widget homeForSession() =>
    Session.instance.isAdmin ? const AdminShell() : const AppShell();

class FactoryLogo extends StatelessWidget {
  final FactoryInfo? factory;
  final double size;
  const FactoryLogo({super.key, required this.factory, this.size = 72});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = factory?.logoUrl;
    final fallback = Icon(Icons.factory_rounded,
        size: size * 0.5, color: cs.primary);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.26),
        boxShadow: const [
          BoxShadow(color: Color(0x26000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: url == null
          ? fallback
          : ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.2),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => fallback,
                loadingBuilder: (c, child, p) => p == null
                    ? child
                    : const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
              ),
            ),
    );
  }
}

Future<void> logoutFlow(BuildContext context) async {
  final list = await ReportStore.load();
  final pending = list.where((r) => !r.remote || r.dirty).length;
  if (!context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('تسجيل الخروج')),
      content: Text(pending > 0
          ? trf('فيه {0} بلاغ لسه ماتبعتش للسيرفر وهيتمسح لو خرجت. متأكد؟', [pending])
          : tr('هتخرج من حسابك. متأكد؟')),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('إلغاء'))),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('خروج'))),
      ],
    ),
  );
  if (ok != true) return;
  await Session.instance.clear();
  await ReportStore.saveAll([]);
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    fadeRoute(const FactoryPickerScreen()),
    (route) => false,
  );
}
