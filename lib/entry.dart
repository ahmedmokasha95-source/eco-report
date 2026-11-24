part of 'main.dart';

// ═════════════════════════ الشاشة الافتتاحية ═════════════════════════

const String kTagline = 'معًا للحفاظ على البيئة';

BoxDecoration _brandGradient() {
  final seed = AppSettings.instance.seed;
  return BoxDecoration(
    gradient: LinearGradient(
      colors: [
        Color.lerp(seed, Colors.black, 0.55)!,
        Color.lerp(seed, Colors.black, 0.2)!,
        seed,
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600));

  late final Animation<double> _logoScale = Tween<double>(begin: 0.3, end: 1)
      .animate(CurvedAnimation(
          parent: _c,
          curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack)));
  late final Animation<double> _logoFade = CurvedAnimation(
      parent: _c, curve: const Interval(0.0, 0.3, curve: Curves.easeOut));
  late final Animation<double> _ring = CurvedAnimation(
      parent: _c, curve: const Interval(0.35, 0.95, curve: Curves.easeOut));
  late final Animation<double> _title = CurvedAnimation(
      parent: _c, curve: const Interval(0.45, 0.8, curve: Curves.easeOut));
  late final Animation<double> _tag = CurvedAnimation(
      parent: _c, curve: const Interval(0.65, 1.0, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _c.forward();
    if (Session.instance.loggedIn) {
      FactoryStore.instance.refresh();
    }
    Future.delayed(const Duration(milliseconds: 3000), _go);
  }

  void _go() {
    if (!mounted) return;
    final Widget next = Session.instance.loggedIn
        ? homeForSession()
        : const FactoryPickerScreen();
    Navigator.of(context).pushReplacement(fadeRoute(next, ms: 700));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seed = AppSettings.instance.seed;
    return Scaffold(
      body: Container(
        decoration: _brandGradient(),
        width: double.infinity,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              return Column(
                children: [
                  const Spacer(flex: 3),
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: ((1 - _ring.value) * 0.5).clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 0.6 + _ring.value * 0.9,
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3),
                              ),
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: _logoFade.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: Container(
                              width: 132,
                              height: 132,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x40000000),
                                    blurRadius: 24,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Icon(Icons.eco_rounded,
                                  size: 78, color: seed),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Opacity(
                    opacity: _title.value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - _title.value) * 24),
                      child: const Text(
                        'رصد المخلفات البيئية',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Opacity(
                    opacity: _tag.value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - _tag.value) * 16),
                      child: const Text(
                        kTagline,
                        style: TextStyle(
                          color: Color(0xCCFFFFFF),
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 4),
                  Opacity(
                    opacity: _tag.value,
                    child: const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 36),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════ اختيار المصنع ═════════════════════════

class FactoryPickerScreen extends StatefulWidget {
  const FactoryPickerScreen({super.key});

  @override
  State<FactoryPickerScreen> createState() => _FactoryPickerScreenState();
}

class _FactoryPickerScreenState extends State<FactoryPickerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500));
  bool _animated = false;

  @override
  void initState() {
    super.initState();
    FactoryStore.instance.addListener(_onStore);
    if (FactoryStore.instance.items.isNotEmpty) {
      _animated = true;
      _c.forward();
    }
    FactoryStore.instance.refresh();
  }

  void _onStore() {
    if (!mounted) return;
    if (!_animated && FactoryStore.instance.items.isNotEmpty) {
      _animated = true;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    FactoryStore.instance.removeListener(_onStore);
    _c.dispose();
    super.dispose();
  }

  void _open(FactoryInfo? f) {
    Navigator.of(context).push(fadeRoute(LoginScreen(factory: f), ms: 550));
  }

  Widget _item(FactoryInfo f, int i) {
    final start = (i * 0.08).clamp(0.0, 0.5);
    final end = (start + 0.5).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
        parent: _c, curve: Interval(start, end, curve: Curves.easeOutCubic));
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) => Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - anim.value) * 40),
          child: Transform.scale(scale: 0.85 + 0.15 * anim.value, child: child),
        ),
      ),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(f),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Hero(
                  tag: 'logo_${f.id}',
                  child: FactoryLogo(factory: f, size: 96),
                ),
                const SizedBox(height: 12),
                Text(
                  f.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: FactoryStore.instance,
        builder: (context, _) {
          final st = FactoryStore.instance;
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                    20, MediaQuery.of(context).padding.top + 24, 20, 28),
                decoration: _brandGradient().copyWith(
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.eco_rounded, color: Colors.white, size: 40),
                    SizedBox(height: 10),
                    Text(
                      'اختر مصنعك',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'اضغط على شعار مصنعك لتسجيل الدخول',
                      style: TextStyle(color: Color(0xCCFFFFFF)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: st.items.isEmpty
                    ? Center(
                        child: st.loading
                            ? const CircularProgressIndicator()
                            : Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.factory_outlined,
                                        size: 56, color: Colors.grey),
                                    const SizedBox(height: 12),
                                    Text(
                                      st.error ??
                                          'لسه مفيش مصانع. المدير يدخل ويضيفها.',
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: st.refresh,
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('إعادة المحاولة'),
                                    ),
                                  ],
                                ),
                              ),
                      )
                    : RefreshIndicator(
                        onRefresh: st.refresh,
                        child: GridView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.92,
                          ),
                          itemCount: st.items.length,
                          itemBuilder: (_, i) => _item(st.items[i], i),
                        ),
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextButton.icon(
                    onPressed: () => _open(null),
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text('دخول المدير العام'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═════════════════════════ تسجيل الدخول ═════════════════════════

class LoginScreen extends StatefulWidget {
  final FactoryInfo? factory;
  const LoginScreen({super.key, required this.factory});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800));
  late final Animation<double> _curve =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  final TextEditingController _user = TextEditingController();
  final TextEditingController _pass = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await Session.instance
        .login(_user.text, _pass.text, widget.factory?.id);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    FactoryStore.instance.refresh();
    Navigator.of(context).pushAndRemoveUntil(
      fadeRoute(homeForSession(), ms: 700),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.factory;
    return Scaffold(
      body: Container(
        decoration: _brandGradient(),
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      f == null
                          ? const FactoryLogo(factory: null, size: 120)
                          : Hero(
                              tag: 'logo_${f.id}',
                              child: FactoryLogo(factory: f, size: 120),
                            ),
                      const SizedBox(height: 14),
                      Text(
                        f?.name ?? 'المدير العام',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 22),
                      AnimatedBuilder(
                        animation: _curve,
                        builder: (context, child) => Opacity(
                          opacity: _curve.value.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, (1 - _curve.value) * 80),
                            child: child,
                          ),
                        ),
                        child: Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _user,
                                  textDirection: TextDirection.ltr,
                                  textInputAction: TextInputAction.next,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  decoration: deco('اسم المستخدم',
                                      icon: Icons.person_outline),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _pass,
                                  obscureText: _hide,
                                  textDirection: TextDirection.ltr,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _submit(),
                                  decoration: InputDecoration(
                                    labelText: 'كلمة المرور',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(_hide
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined),
                                      onPressed: () =>
                                          setState(() => _hide = !_hide),
                                    ),
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                  ),
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.error,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 18),
                                FilledButton(
                                  onPressed: _busy ? null : _submit,
                                  style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(50)),
                                  child: _busy
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2.5),
                                        )
                                      : const Text('دخول',
                                          style: TextStyle(fontSize: 17)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
