part of 'main.dart';

// ═════════════════════════ شاشة المدير ═════════════════════════

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _tab = 0;
  bool _loading = true;
  bool _syncing = false;
  List<Report> _reports = [];
  DateTime? _seen;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    FactoryStore.instance.refresh();
    _init();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _syncNow());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('admin_seen');
    var seen = raw == null ? null : DateTime.tryParse(raw);
    if (seen == null) {
      seen = DateTime.now();
      await p.setString('admin_seen', seen.toIso8601String());
    }
    _seen = seen;
    await _load();
    _syncNow();
  }

  Future<void> _load() async {
    final r = await ReportStore.load();
    if (!mounted) return;
    setState(() {
      _reports = r;
      _loading = false;
    });
  }

  List<Report> get _fresh {
    final s = _seen;
    if (s == null) return const [];
    final list = _reports.where((r) => r.createdAt.isAfter(s)).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> _syncNow({bool silent = true}) async {
    if (_syncing || SyncService.running) return;
    if (!AppSettings.instance.syncActive) return;
    if (mounted) setState(() => _syncing = true);
    String? msg;
    final before = _fresh.length;
    try {
      await SyncService.sync();
      AppSettings.instance.setLastSync(DateTime.now());
    } on SyncException catch (e) {
      msg = trf('فشلت المزامنة: {0}', [e.message]);
    } catch (_) {
      msg = tr('فشلت المزامنة، راجع الإنترنت');
    }
    if (!mounted) return;
    setState(() => _syncing = false);
    await _load();
    if (!mounted) return;
    final now = _fresh.length;
    if (msg != null) {
      if (!silent) snack(context, msg);
    } else if (now > before) {
      snack(context, trf('وصل {0} بلاغ جديد 🔔', [now - before]));
    } else if (!silent) {
      snack(context, tr('كل حاجة محدّثة ✅'));
    }
  }

  Future<void> _markSeen() async {
    final now = DateTime.now();
    final p = await SharedPreferences.getInstance();
    await p.setString('admin_seen', now.toIso8601String());
    if (mounted) setState(() => _seen = now);
  }

  Future<void> _openFactory(FactoryInfo f) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => FactoryReportsScreen(factory: f)),
    );
    await _load();
  }

  Future<void> _openReport(Report r) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(report: r)),
    );
    await _load();
    _syncNow();
  }

  void _showFresh() {
    final list = _fresh;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        list.isEmpty
                            ? tr('مفيش بلاغات جديدة')
                            : trf('بلاغات جديدة ({0})', [list.length]),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (list.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _markSeen();
                        },
                        child: Text(tr('تعليم الكل كمقروء')),
                      ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final r in list)
                      ListTile(
                        leading: SizedBox(
                          width: 52,
                          height: 52,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _Photo(r.imagePath),
                          ),
                        ),
                        title: Text(
                            '${FactoryStore.instance.nameOf(r.factoryId)} • ${noLabel(r)}'),
                        subtitle: Text(
                          '${OptionStore.ar('location', r.location)} • ${r.reporter.isEmpty ? '—' : r.reporter}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _openReport(r);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _tab,
              children: [
                _AdminDashboard(
                  reports: _reports,
                  freshCount: _fresh.length,
                  syncing: _syncing,
                  onBell: _showFresh,
                  onSync: () => _syncNow(silent: false),
                  onRefresh: () => _syncNow(silent: false),
                  onOpenFactory: _openFactory,
                  onOpenReport: _openReport,
                ),
                const FactoriesAdminTab(),
                const UsersAdminTab(),
                AnalyticsTab(reports: _reports, byFactory: true),
                SettingsTab(
                  syncing: _syncing,
                  onSyncNow: () => _syncNow(silent: false),
                ),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: tr('الداشبورد'),
          ),
          NavigationDestination(
            icon: Icon(Icons.factory_outlined),
            selectedIcon: Icon(Icons.factory),
            label: tr('المصانع'),
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: tr('المستخدمون'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights),
            label: tr('التحليلات'),
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: tr('الإعدادات'),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════ الداشبورد ═════════════════════════

class _CountUp extends StatelessWidget {
  final int value;
  final TextStyle? style;
  const _CountUp(this.value, {this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}', style: style),
    );
  }
}

class _Counts {
  int total = 0;
  int open = 0;
  int prog = 0;
  int closed = 0;
  int overdue = 0;
}

_Counts _countsOf(Iterable<Report> list) {
  final c = _Counts();
  for (final r in list) {
    c.total++;
    if (r.status == 'Open') c.open++;
    if (r.status == 'In progress') c.prog++;
    if (r.status == 'Closed') c.closed++;
    if (isOverdue(r)) c.overdue++;
  }
  return c;
}

class _AdminDashboard extends StatelessWidget {
  final List<Report> reports;
  final int freshCount;
  final bool syncing;
  final VoidCallback onBell;
  final VoidCallback onSync;
  final Future<void> Function() onRefresh;
  final ValueChanged<FactoryInfo> onOpenFactory;
  final ValueChanged<Report> onOpenReport;

  const _AdminDashboard({
    required this.reports,
    required this.freshCount,
    required this.syncing,
    required this.onBell,
    required this.onSync,
    required this.onRefresh,
    required this.onOpenFactory,
    required this.onOpenReport,
  });

  @override
  Widget build(BuildContext context) {
    final all = _countsOf(reports);
    final recent = [...reports]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ListenableBuilder(
      listenable: FactoryStore.instance,
      builder: (context, _) {
        final factories = FactoryStore.instance.items;
        return Column(
          children: [
            _GlassHeader(
              all: all,
              factoryCount: factories.length,
              freshCount: freshCount,
              syncing: syncing,
              onBell: onBell,
              onSync: onSync,
            ),
            // بلاطات المؤشرات بتتداخل مع حافة الهيدر السفلية
            SizedBox(
              height: 96 - 40,
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: 0,
                maxHeight: 96,
                child: Transform.translate(
                  offset: const Offset(0, -40),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Expanded(
                            child: _KpiTile(tr('مفتوح'), all.open,
                                statusColor('Open'), Icons.error_outline)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _KpiTile(tr('جاري'), all.prog,
                                statusColor('In progress'),
                                Icons.timelapse)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _KpiTile(tr('مغلق'), all.closed,
                                statusColor('Closed'),
                                Icons.check_circle_outline)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _KpiTile(tr('متأخر'), all.overdue,
                                const Color(0xFF90A4AE), Icons.schedule)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                  children: [
                    Text(tr('المصانع'),
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (factories.isEmpty)
                      Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          tr('لسه مفيش مصانع. ضيفها من تبويب "المصانع".'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    for (final f in factories)
                      _FactoryCard(
                        factory: f,
                        counts: _countsOf(
                            reports.where((r) => r.factoryId == f.id)),
                        onTap: () => onOpenFactory(f),
                      ),
                    if (recent.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(tr('أحدث البلاغات'),
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      for (final r in recent.take(5))
                        _ReportCard(r: r, onTap: () => onOpenReport(r)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────── ألوان وأدوات الداشبورد الجديد (هيدر زجاجي) ───────────

const Color _kTeal = Color(0xFF00897B);

/// دايرة نسبة الإغلاق (قوس أخضر على حلقة رمادية).
class _RingPainter extends CustomPainter {
  final double value; // 0..1
  final Color track;
  final Color color;
  _RingPainter(this.value, this.track, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const w = 5.0;
    final rect = Rect.fromLTWH(w / 2, w / 2, size.width - w, size.height - w);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = track;
    canvas.drawArc(rect, 0, 6.2831853, false, base);
    if (value > 0) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawArc(rect, -1.5707963, 6.2831853 * value, false, p);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.track != track || old.color != color;
}

class _KpiTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  const _KpiTile(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 6),
          _CountUp(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// الهيدر الزجاجي: دوائر توهج أخضر/تركواز خلف لوحة شفافة بحدود رفيعة.
class _GlassHeader extends StatelessWidget {
  final _Counts all;
  final int factoryCount;
  final int freshCount;
  final bool syncing;
  final VoidCallback onBell;
  final VoidCallback onSync;
  const _GlassHeader({
    required this.all,
    required this.factoryCount,
    required this.freshCount,
    required this.syncing,
    required this.onBell,
    required this.onSync,
  });

  Widget _glow(Color c, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [c.withValues(alpha: 0.55), c.withValues(alpha: 0)],
          ),
        ),
      );

  Widget _roundBtn(Color fg, Widget child, VoidCallback? onTap) => Material(
        color: fg.withValues(alpha: 0.10),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 40, height: 40, child: Center(child: child)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final seed = AppSettings.instance.seed;
    final fg = cs.onSurface;
    final rate = all.total == 0 ? 0 : (all.closed * 100 / all.total).round();
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        PositionedDirectional(
            start: -70, top: -70, child: _glow(seed, 280)),
        PositionedDirectional(
            end: -80, top: 10, child: _glow(_kTeal, 260)),
        Padding(
          padding: EdgeInsets.fromLTRB(
              16, MediaQuery.of(context).padding.top + 12, 16, 56),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: fg.withValues(alpha: 0.16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.dashboard_rounded, color: fg, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr('لوحة المدير العام'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: fg,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _roundBtn(
                      fg,
                      Badge(
                        isLabelVisible: freshCount > 0,
                        label: Text('$freshCount'),
                        child: Icon(Icons.notifications_outlined, color: fg),
                      ),
                      onBell,
                    ),
                    const SizedBox(width: 8),
                    _roundBtn(
                      fg,
                      syncing
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: fg),
                            )
                          : Icon(Icons.cloud_sync, color: fg),
                      syncing ? null : onSync,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CountUp(all.total,
                              style: TextStyle(
                                  color: fg,
                                  fontSize: 44,
                                  height: 1.05,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            trf('بلاغ في {0} مصنع', [factoryCount]),
                            style: TextStyle(
                                color: cs.onSurfaceVariant, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: fg.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: fg.withValues(alpha: 0.18)),
                      ),
                      child: Column(
                        children: [
                          Text('$rate%',
                              style: TextStyle(
                                  color: fg,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                          Text(tr('نسبة الإغلاق'),
                              style: TextStyle(
                                  color: cs.onSurfaceVariant, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FactoryCard extends StatelessWidget {
  final FactoryInfo factory;
  final _Counts counts;
  final VoidCallback onTap;
  const _FactoryCard(
      {required this.factory, required this.counts, required this.onTap});

  Widget _dotText(String text, Color c) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 8, color: c),
            const SizedBox(width: 4),
            Text(text, style: TextStyle(fontSize: 12, color: c)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rate = counts.total == 0 ? 0.0 : counts.closed / counts.total;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      elevation: 0,
      color: cs.surfaceContainerHigh,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              FactoryLogo(factory: factory, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(factory.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    if (counts.total == 0)
                      Text(tr('لسه مفيش بلاغات'),
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant))
                    else
                      Wrap(
                        children: [
                          _dotText(trf('{0} مفتوح', [counts.open]),
                              statusColor('Open')),
                          _dotText(trf('{0} جاري', [counts.prog]),
                              statusColor('In progress')),
                          _dotText(trf('{0} مغلق', [counts.closed]),
                              statusColor('Closed')),
                          if (counts.overdue > 0)
                            _dotText(trf('{0} متأخر', [counts.overdue]),
                                const Color(0xFFE57373)),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: rate),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => SizedBox(
                  width: 54,
                  height: 54,
                  child: CustomPaint(
                    painter: _RingPainter(
                        v, cs.onSurface.withValues(alpha: 0.12),
                        statusColor('Closed')),
                    child: Center(
                      child: Text(
                        counts.total == 0 ? '–' : '${(v * 100).round()}%',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
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

// ═════════════════════════ بلاغات مصنع (للمدير) ═════════════════════════

class FactoryReportsScreen extends StatefulWidget {
  final FactoryInfo factory;
  const FactoryReportsScreen({super.key, required this.factory});

  @override
  State<FactoryReportsScreen> createState() => _FactoryReportsScreenState();
}

class _FactoryReportsScreenState extends State<FactoryReportsScreen> {
  List<Report> _all = [];
  String? _status;
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    Session.instance.viewFactoryId = null;
    super.dispose();
  }

  Future<void> _load() async {
    final r = await ReportStore.load();
    if (!mounted) return;
    setState(() {
      _all = r.where((x) => x.factoryId == widget.factory.id).toList();
      _loading = false;
    });
  }

  List<Report> get _filtered =>
      _all.where((r) => _status == null || r.status == _status).toList();

  Future<void> _sync() async {
    if (_syncing || SyncService.running) return;
    setState(() => _syncing = true);
    try {
      await SyncService.sync();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _syncing = false);
    await _load();
  }

  Future<void> _openNew() async {
    Session.instance.viewFactoryId = widget.factory.id;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NewReportScreen()),
    );
    await _load();
    _sync();
  }

  Future<void> _openDetails(Report r) async {
    Session.instance.viewFactoryId = widget.factory.id;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(report: r)),
    );
    await _load();
    _sync();
  }

  Future<void> _export(String kind) async {
    final title = trf('سجل المخالفات البيئية - {0}', [widget.factory.name]);
    if (kind == 'pdf') {
      await exportPdf(context, _filtered, title);
    } else {
      await exportCsv(context, _filtered);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _countsOf(_all);
    final list = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            FactoryLogo(factory: widget.factory, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.factory.name, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          _syncing
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  tooltip: tr('مزامنة'),
                  onPressed: _sync,
                  icon: const Icon(Icons.cloud_sync)),
          PopupMenuButton<String>(
            tooltip: tr('تصدير'),
            icon: const Icon(Icons.ios_share),
            onSelected: _export,
            itemBuilder: (_) => [
              PopupMenuItem(value: 'pdf', child: Text(tr('تصدير PDF (بالصور)'))),
              PopupMenuItem(value: 'csv', child: Text(tr('تصدير Excel / CSV'))),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNew,
        icon: const Icon(Icons.add_a_photo),
        label: Text(tr('تسجيل مخالفة')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppSettings.instance.seed,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      _Stat(tr('الإجمالي'), c.total),
                      _Stat(tr('مفتوح'), c.open),
                      _Stat(tr('جاري'), c.prog),
                      _Stat(tr('مغلق'), c.closed),
                      _Stat(tr('متأخر'), c.overdue),
                    ],
                  ),
                ),
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(tr('الكل')),
                          selected: _status == null,
                          onSelected: (_) => setState(() => _status = null),
                        ),
                      ),
                      for (final s in kStatuses)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(s.text),
                            selected: _status == s.en,
                            onSelected: (_) => setState(
                                () => _status = _status == s.en ? null : s.en),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: list.isEmpty
                      ? Center(child: Text(tr('مفيش بلاغات هنا.')))
                      : RefreshIndicator(
                          onRefresh: _sync,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 96),
                            itemCount: list.length,
                            itemBuilder: (_, i) =>
                                AppSettings.instance.cardStyle == 1
                                    ? _LargeCard(
                                        r: list[i],
                                        onTap: () => _openDetails(list[i]))
                                    : _ReportCard(
                                        r: list[i],
                                        onTap: () => _openDetails(list[i])),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

// ═════════════════════════ إدارة المصانع ═════════════════════════

class FactoriesAdminTab extends StatelessWidget {
  const FactoriesAdminTab({super.key});

  Future<void> _edit(BuildContext context, FactoryInfo? f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _FactoryForm(factory: f),
    );
    if (ok == true) await FactoryStore.instance.refresh();
  }

  Future<void> _delete(BuildContext context, FactoryInfo f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('حذف المصنع')),
        content: Text(trf('هتحذف "{0}". لو عليه بلاغات مش هيتحذف.', [f.name])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('إلغاء'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('حذف'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AdminApi.deleteFactory(f.id);
      await FactoryStore.instance.refresh();
    } on SyncException catch (e) {
      if (context.mounted) snack(context, e.message);
    } catch (_) {
      if (context.mounted) snack(context, tr('فشل الحذف'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('المصانع'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add_business),
        label: Text(tr('إضافة مصنع')),
      ),
      body: ListenableBuilder(
        listenable: FactoryStore.instance,
        builder: (context, _) {
          final items = FactoryStore.instance.items;
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  tr('لسه مفيش مصانع.\nاضغط "إضافة مصنع" واكتب الاسم وارفع الشعار.'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: FactoryStore.instance.refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 96),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final f = items[i];
                return Card(
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    leading: FactoryLogo(factory: f, size: 52),
                    title: Text(f.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: tr('تعديل'),
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _edit(context, f),
                        ),
                        IconButton(
                          tooltip: tr('حذف'),
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(context, f),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _FactoryForm extends StatefulWidget {
  final FactoryInfo? factory;
  const _FactoryForm({required this.factory});

  @override
  State<_FactoryForm> createState() => _FactoryFormState();
}

class _FactoryFormState extends State<_FactoryForm> {
  late final TextEditingController _name =
      TextEditingController(text: widget.factory?.name ?? '');
  XFile? _logo;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final f = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 600, imageQuality: 85);
    if (f != null) setState(() => _logo = f);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = tr('اكتب اسم المصنع'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String? url;
      if (_logo != null) url = await AdminApi.uploadLogo(_logo!);
      await AdminApi.saveFactory(
          id: widget.factory?.id, name: name, logoUrl: url);
      if (mounted) Navigator.pop(context, true);
    } on SyncException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = tr('مقدرناش نوصل للسيرفر');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.factory == null ? tr('إضافة مصنع') : tr('تعديل المصنع')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _busy ? null : _pick,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: cs.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: _logo != null
                    ? Image.file(File(_logo!.path), fit: BoxFit.contain)
                    : (widget.factory?.logoUrl != null
                        ? FactoryLogo(factory: widget.factory, size: 110)
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  size: 34, color: cs.primary),
                              const SizedBox(height: 4),
                              Text(tr('الشعار'),
                                  style: TextStyle(fontSize: 12)),
                            ],
                          )),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              decoration: deco(tr('اسم المصنع'), icon: Icons.factory_outlined),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!,
                    style: TextStyle(
                        color: cs.error, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: Text(tr('إلغاء'))),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(tr('حفظ')),
        ),
      ],
    );
  }
}

// ═════════════════════════ إدارة المستخدمين ═════════════════════════

class UsersAdminTab extends StatefulWidget {
  const UsersAdminTab({super.key});

  @override
  State<UsersAdminTab> createState() => _UsersAdminTabState();
}

class _UsersAdminTabState extends State<UsersAdminTab> {
  List<AppUser> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final u = await AdminApi.listUsers();
      if (!mounted) return;
      setState(() {
        _users = u;
        _loading = false;
      });
    } on SyncException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = tr('تعذّر تحميل المستخدمين');
      });
    }
  }

  Future<void> _add() async {
    if (FactoryStore.instance.items.isEmpty) {
      snack(context, tr('ضيف مصنع الأول من تبويب المصانع'));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _UserForm(),
    );
    if (ok == true) {
      if (mounted) snack(context, tr('تم إنشاء الحساب ✅'));
      _load();
    }
  }

  Future<void> _reset(AppUser u) async {
    final pw = await askText(context, trf('باسورد جديد لـ {0}', [u.username]));
    if (pw == null || pw.trim().isEmpty) return;
    try {
      await AdminApi.resetPassword(u.id, pw.trim());
      if (mounted) snack(context, tr('تم تغيير الباسورد ✅'));
    } on SyncException catch (e) {
      if (mounted) snack(context, e.message);
    }
  }

  Future<void> _delete(AppUser u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('حذف الحساب')),
        content: Text(trf('هتحذف حساب "{0}". بلاغاته القديمة هتفضل.', [u.username])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('إلغاء'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('حذف'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AdminApi.deleteUser(u.id);
      _load();
    } on SyncException catch (e) {
      if (mounted) snack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('المستخدمون')),
        actions: [
          IconButton(
              tooltip: tr('تحديث'),
              onPressed: _load,
              icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(tr('إضافة مبلّغ')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: Text(tr('إعادة المحاولة')),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 96),
                  itemCount: _users.length,
                  itemBuilder: (_, i) {
                    final u = _users[i];
                    final isAdmin = u.role == 'admin';
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(isAdmin
                              ? Icons.admin_panel_settings
                              : Icons.person),
                        ),
                        title: Text(
                          u.fullName.isEmpty ? u.username : u.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          isAdmin
                              ? trf('مدير عام • {0}', [u.username])
                              : '${FactoryStore.instance.nameOf(u.factoryId)} • ${u.username}',
                        ),
                        trailing: isAdmin
                            ? null
                            : PopupMenuButton<String>(
                                onSelected: (v) =>
                                    v == 'pw' ? _reset(u) : _delete(u),
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                      value: 'pw',
                                      child: Text(tr('تغيير الباسورد'))),
                                  PopupMenuItem(
                                      value: 'del', child: Text(tr('حذف الحساب'))),
                                ],
                              ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _UserForm extends StatefulWidget {
  const _UserForm();

  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _user = TextEditingController();
  final TextEditingController _pass = TextEditingController();
  String? _factoryId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_factoryId == null) {
      setState(() => _error = tr('اختار المصنع'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AdminApi.createUser(
        username: _user.text.trim().toLowerCase(),
        password: _pass.text,
        fullName: _name.text.trim(),
        factoryId: _factoryId!,
      );
      if (mounted) Navigator.pop(context, true);
    } on SyncException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = tr('مقدرناش نوصل للسيرفر');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(tr('إضافة مبلّغ')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              decoration: deco(tr('الاسم'), icon: Icons.badge_outlined),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _user,
              textDirection: TextDirection.ltr,
              autocorrect: false,
              decoration: deco(tr('اسم المستخدم (إنجليزي)'),
                  icon: Icons.person_outline),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _pass,
              textDirection: TextDirection.ltr,
              decoration:
                  deco(tr('الباسورد (٦ حروف على الأقل)'), icon: Icons.lock_outline),
            ),
            const SizedBox(height: 14),
            Text(tr('المصنع'), style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final f in FactoryStore.instance.items)
                  ChoiceChip(
                    label: Text(f.name),
                    selected: _factoryId == f.id,
                    onSelected: (_) => setState(() => _factoryId = f.id),
                  ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!,
                    style: TextStyle(
                        color: cs.error, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: Text(tr('إلغاء'))),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(tr('إنشاء')),
        ),
      ],
    );
  }
}
