part of 'main.dart';

// ═════════════════════════ التحليلات والملخص الذكي ═════════════════════════

String _l(String ar, String en) =>
    AppSettings.instance.lang == 'en' ? en : ar;

const _kMonthsAr = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
];
const _kMonthsEn = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];
String _monthName(int m) =>
    AppSettings.instance.lang == 'en' ? _kMonthsEn[m - 1] : _kMonthsAr[m - 1];

class _Insight {
  final IconData icon;
  final Color color;
  final String text;
  const _Insight(this.icon, this.color, this.text);
}

class _Bucket {
  final String label;
  final int count;
  final Color color;
  const _Bucket(this.label, this.count, this.color);
}

/// عدّ القيم وترتيبها تنازلي.
List<MapEntry<String, int>> _tally(
    Iterable<Report> list, String Function(Report) key) {
  final m = <String, int>{};
  for (final r in list) {
    final k = key(r);
    if (k.trim().isEmpty) continue;
    m[k] = (m[k] ?? 0) + 1;
  }
  final e = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return e;
}

String _pct(int a, int b) => b == 0 ? '0%' : '${(a * 100 / b).round()}%';

/// يطلع الاستنتاجات والتوصيات من البلاغات (قواعد جاهزة، من غير إنترنت).
({List<_Insight> insights, List<String> recs}) _analyze(
    List<Report> list, bool byFactory) {
  final ins = <_Insight>[];
  final recs = <String>[];
  if (list.isEmpty) return (insights: ins, recs: recs);
  final total = list.length;
  final c = _countsOf(list);
  const red = Color(0xFFC62828);
  const orange = Color(0xFFEF6C00);
  const green = Color(0xFF2E7D32);
  const blue = Color(0xFF1565C0);

  // نسبة الإغلاق
  final rate = (c.closed * 100 / total).round();
  ins.add(_Insight(
      Icons.task_alt,
      rate >= 70 ? green : (rate >= 40 ? orange : red),
      _l('اتقفل $rate% من البلاغات (${c.closed} من $total).',
          '$rate% of reports are closed (${c.closed} of $total).')));
  if (rate < 50) {
    recs.add(_l('نسبة الإغلاق منخفضة: حدّد مسؤول ومهلة لكل بلاغ مفتوح وتابعها أسبوعيًا.',
        'Closure rate is low: assign an owner and a deadline to each open report and review weekly.'));
  }

  // أكتر نوع
  final types = _tally(list, (r) => r.type);
  if (types.isNotEmpty) {
    final t = types.first;
    ins.add(_Insight(
        Icons.category_outlined,
        blue,
        _l('أكتر نوع مخالفة: ${OptionStore.ar('type', t.key)} (${t.value} بلاغ، ${_pct(t.value, total)}).',
            'Most common violation type: ${OptionStore.ar('type', t.key)} (${t.value} reports, ${_pct(t.value, total)}).')));
    if (t.value * 100 / total >= 30 && total >= 5) {
      recs.add(_l('نوع "${OptionStore.ar('type', t.key)}" بيتكرر كتير: ابحث عن السبب الجذري وحط إجراء وقائي دائم.',
          '"${OptionStore.ar('type', t.key)}" keeps recurring: find the root cause and set a permanent preventive action.'));
    }
  }

  // أكتر موقع
  final locs = _tally(list, (r) => r.location);
  if (locs.isNotEmpty) {
    final t = locs.first;
    ins.add(_Insight(
        Icons.place_outlined,
        orange,
        _l('أكتر موقع فيه بلاغات: ${OptionStore.ar('location', t.key)} (${t.value} بلاغ، ${_pct(t.value, total)}).',
            'Hottest location: ${OptionStore.ar('location', t.key)} (${t.value} reports, ${_pct(t.value, total)}).')));
    if (t.value * 100 / total >= 30 && total >= 5) {
      recs.add(_l('ركّز الجولات التفتيشية على "${OptionStore.ar('location', t.key)}" لأنه مصدر أكبر حصة من البلاغات.',
          'Focus inspection rounds on "${OptionStore.ar('location', t.key)}", the source of the largest share of reports.'));
    }
  }

  // الخطورة العالية المفتوحة
  final highOpen =
      list.where((r) => r.severity == 'High' && r.status != 'Closed').toList();
  if (highOpen.isNotEmpty) {
    ins.add(_Insight(
        Icons.warning_amber_rounded,
        red,
        _l('فيه ${highOpen.length} بلاغ خطورة عالية لسه مش مقفول.',
            '${highOpen.length} high-severity reports are still not closed.')));
    recs.add(_l('ابدأ بالبلاغات عالية الخطورة المفتوحة (${highOpen.length}) قبل أي حاجة تانية.',
        'Start with the open high-severity reports (${highOpen.length}) before anything else.'));
  }

  // المتأخر
  if (c.overdue > 0) {
    ins.add(_Insight(
        Icons.alarm,
        red,
        _l('${c.overdue} بلاغ عدّى موعد الإغلاق المحدد.',
            '${c.overdue} reports are past their due date.')));
    recs.add(_l('راجع البلاغات المتأخرة (${c.overdue}) وحدّد مواعيد واقعية أو صعّد للمسؤول.',
        'Review the overdue reports (${c.overdue}) and set realistic dates or escalate to the owner.'));
  }

  // أقدم بلاغ مفتوح
  final openList = list.where((r) => r.status != 'Closed').toList();
  if (openList.isNotEmpty) {
    openList.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final days = DateTime.now().difference(openList.first.createdAt).inDays;
    if (days >= 14) {
      ins.add(_Insight(
          Icons.hourglass_bottom,
          orange,
          _l('أقدم بلاغ مفتوح عمره $days يوم.',
              'The oldest open report is $days days old.')));
    }
  }

  // متوسط وقت الإغلاق
  final closedWith =
      list.where((r) => r.status == 'Closed' && r.closedAt != null).toList();
  if (closedWith.isNotEmpty) {
    var sum = 0.0;
    for (final r in closedWith) {
      sum += r.closedAt!.difference(r.createdAt).inHours / 24.0;
    }
    final avg = sum / closedWith.length;
    ins.add(_Insight(
        Icons.timer_outlined,
        green,
        _l('متوسط وقت الإغلاق ${avg.toStringAsFixed(1)} يوم.',
            'Average time to close is ${avg.toStringAsFixed(1)} days.')));
  }

  // الاتجاه: آخر 30 يوم مقابل اللي قبلها
  final now = DateTime.now();
  final last = list
      .where((r) => now.difference(r.createdAt).inDays < 30)
      .length;
  final prev = list.where((r) {
    final d = now.difference(r.createdAt).inDays;
    return d >= 30 && d < 60;
  }).length;
  if (last + prev >= 3) {
    if (prev == 0) {
      ins.add(_Insight(
          Icons.trending_up,
          orange,
          _l('اتسجل $last بلاغ في آخر 30 يوم ومفيش بلاغات في الشهر اللي قبله.',
              '$last reports in the last 30 days and none in the 30 days before.')));
    } else {
      final ch = ((last - prev) * 100 / prev).round();
      final up = ch > 0;
      ins.add(_Insight(
          up ? Icons.trending_up : (ch < 0 ? Icons.trending_down : Icons.trending_flat),
          up ? red : green,
          _l('البلاغات في آخر 30 يوم ${up ? "زادت" : (ch < 0 ? "قلّت" : "ثابتة")} ${ch == 0 ? "" : "${ch.abs()}% "}عن الشهر اللي قبله ($last مقابل $prev).',
              'Reports in the last 30 days ${up ? "rose" : (ch < 0 ? "fell" : "held flat")}${ch == 0 ? "" : " ${ch.abs()}%"} vs the previous 30 days ($last vs $prev).')));
      if (ch >= 25) {
        recs.add(_l('البلاغات في زيادة ملحوظة: اعمل مراجعة سريعة لأسباب الزيادة مع المصانع المعنية.',
            'Reports are clearly rising: run a quick review of the causes with the affected factories.'));
      }
    }
  }

  // الأثر الأكتر
  final imp = <String, int>{};
  for (final r in list) {
    for (final i in r.impacts) {
      imp[i] = (imp[i] ?? 0) + 1;
    }
  }
  if (imp.isNotEmpty) {
    final e = imp.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    ins.add(_Insight(
        Icons.eco_outlined,
        green,
        _l('أكتر أثر بيئي متكرر: ${arOf(kImpacts, e.first.key)} (${e.first.value} بلاغ).',
            'Most frequent impact: ${arOf(kImpacts, e.first.key)} (${e.first.value} reports).')));
  }

  // أكتر مصنع (للمدير)
  if (byFactory) {
    final f = _tally(list.where((r) => r.status != 'Closed'),
        (r) => r.factoryId ?? '');
    if (f.isNotEmpty) {
      final n = FactoryStore.instance.nameOf(f.first.key);
      ins.add(_Insight(
          Icons.factory_outlined,
          orange,
          _l('أكتر مصنع عنده بلاغات مفتوحة: $n (${f.first.value}).',
              'Factory with the most open reports: $n (${f.first.value}).')));
      recs.add(_l('تابع مصنع "$n" مباشرة لأنه الأعلى في البلاغات المفتوحة.',
          'Follow up with "$n" directly, it has the most open reports.'));
    }
  }

  if (recs.isEmpty) {
    recs.add(_l('الوضع مستقر. استمر في المتابعة وسجّل أي ملاحظة جديدة بسرعة.',
        'Things look stable. Keep monitoring and log new findings quickly.'));
  }
  return (insights: ins, recs: recs);
}

// ───────────────────────── الشاشة ─────────────────────────

class AnalyticsTab extends StatefulWidget {
  final List<Report> reports;
  final bool byFactory;
  const AnalyticsTab({super.key, required this.reports, this.byFactory = false});
  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  int _period = 0; // 0 الكل، 1 30 يوم، 2 90 يوم، 3 سنة

  List<Report> get _list {
    if (_period == 0) return widget.reports;
    final days = const [0, 30, 90, 365][_period];
    final now = DateTime.now();
    return widget.reports
        .where((r) => now.difference(r.createdAt).inDays < days)
        .toList();
  }

  Widget _chip(String label, int i, Color fg) {
    final sel = _period == i;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: GestureDetector(
        onTap: () => setState(() => _period = i),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: fg.withValues(alpha: sel ? 0.22 : 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: fg.withValues(alpha: sel ? 0.7 : 0.18)),
          ),
          child: Text(label,
              style: TextStyle(
                  color: fg,
                  fontSize: 13,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
        ),
      ),
    );
  }

  Widget _glow(Color c, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
              colors: [c.withValues(alpha: 0.55), c.withValues(alpha: 0)]),
        ),
      );

  Widget _card(String title, IconData icon, Widget child) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15))),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final seed = AppSettings.instance.seed;
    final list = _list;
    final c = _countsOf(list);
    final rate = c.total == 0 ? 0 : (c.closed * 100 / c.total).round();
    final an = _analyze(list, widget.byFactory);
    final fg = cs.onSurface;

    final sev = [
      for (final o in kSeverities.reversed)
        _Bucket(o.text, list.where((r) => r.severity == o.en).length,
            severityColor(o.en))
    ];
    final stat = [
      for (final o in kStatuses)
        _Bucket(o.text, list.where((r) => r.status == o.en).length,
            statusColor(o.en))
    ];
    List<_Bucket> top(List<MapEntry<String, int>> e, String kind, Color col) => [
          for (final x in e.take(6))
            _Bucket(OptionStore.ar(kind, x.key), x.value, col)
        ];
    final types = top(_tally(list, (r) => r.type), 'type', const Color(0xFF1565C0));
    final locs =
        top(_tally(list, (r) => r.location), 'location', const Color(0xFF00897B));
    final facs = widget.byFactory
        ? [
            for (final x in _tally(list, (r) => r.factoryId ?? '').take(6))
              _Bucket(FactoryStore.instance.nameOf(x.key), x.value,
                  const Color(0xFF6A1B9A))
          ]
        : <_Bucket>[];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // رأس زجاجي
        ClipRect(
          child: Stack(children: [
            PositionedDirectional(
                start: -70, top: -70, child: _glow(seed, 280)),
            PositionedDirectional(
                end: -80, top: 10, child: _glow(const Color(0xFF00897B), 240)),
            SafeArea(
              bottom: false,
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: fg.withValues(alpha: 0.14)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.insights, color: seed),
                        const SizedBox(width: 8),
                        Text(_l('التحليلات', 'Analytics'),
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                          _l('${c.total} بلاغ • نسبة الإغلاق $rate%',
                              '${c.total} reports • $rate% closed'),
                          style: TextStyle(color: fg.withValues(alpha: 0.7))),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          _chip(_l('الكل', 'All'), 0, fg),
                          _chip(_l('30 يوم', '30 days'), 1, fg),
                          _chip(_l('90 يوم', '90 days'), 2, fg),
                          _chip(_l('سنة', 'Year'), 3, fg),
                        ]),
                      ),
                    ]),
              ),
            ),
          ]),
        ),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
                child: Text(
                    _l('مفيش بلاغات في الفترة دي', 'No reports in this period'),
                    style: TextStyle(color: fg.withValues(alpha: 0.6)))),
          )
        else ...[
          // KPI
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(children: [
              _kpi(_l('مفتوح', 'Open'), c.open, statusColor('Open')),
              _kpi(_l('جاري', 'In progress'), c.prog, statusColor('In progress')),
              _kpi(_l('مغلق', 'Closed'), c.closed, statusColor('Closed')),
              _kpi(_l('متأخر', 'Overdue'), c.overdue, const Color(0xFFB71C1C)),
            ]),
          ),
          // الملخص الذكي
          _card(_l('الملخص الذكي', 'Smart summary'), Icons.auto_awesome, Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final i in an.insights)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: i.color.withValues(alpha: 0.15),
                              shape: BoxShape.circle),
                          child: Icon(i.icon, size: 16, color: i.color),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(i.text,
                                    style: const TextStyle(height: 1.4)))),
                      ]),
                ),
              const Divider(height: 22),
              Text(_l('التوصيات', 'Recommendations'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              for (var k = 0; k < an.recs.length; k++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                            radius: 10,
                            backgroundColor: cs.primaryContainer,
                            child: Text('${k + 1}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onPrimaryContainer))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(an.recs[k],
                                style: const TextStyle(height: 1.4))),
                      ]),
                ),
            ],
          )),
          _card(_l('البلاغات شهريًا (آخر 6 شهور)', 'Reports per month (last 6)'),
              Icons.bar_chart, _MonthlyChart(list)),
          _card(_l('حسب الخطورة', 'By severity'), Icons.priority_high,
              _HBars(sev)),
          _card(_l('حسب الحالة', 'By status'), Icons.flag_outlined,
              _HBars(stat)),
          if (types.isNotEmpty)
            _card(_l('حسب نوع المخالفة', 'By violation type'),
                Icons.category_outlined, _HBars(types)),
          if (locs.isNotEmpty)
            _card(_l('حسب الموقع', 'By location'), Icons.place_outlined,
                _HBars(locs)),
          if (facs.isNotEmpty)
            _card(_l('حسب المصنع', 'By factory'), Icons.factory_outlined,
                _HBars(facs)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Text(
                _l('الملخص بيتحسب على الجهاز من بيانات البلاغات نفسها، من غير إنترنت.',
                    'The summary is computed on this device from the report data, offline.'),
                style: TextStyle(
                    fontSize: 12, color: fg.withValues(alpha: 0.5))),
          ),
        ],
      ],
    );
  }

  Widget _kpi(String label, int v, Color col) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: col.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [
            Text('$v',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: col)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: col)),
          ]),
        ),
      );
}

class _HBars extends StatelessWidget {
  final List<_Bucket> items;
  const _HBars(this.items);
  @override
  Widget build(BuildContext context) {
    final mx = items.fold<int>(1, (m, b) => b.count > m ? b.count : m);
    final total = items.fold<int>(0, (m, b) => m + b.count);
    return Column(children: [
      for (final b in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(children: [
            Row(children: [
              Expanded(
                  child: Text(b.label,
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text('${b.count}  (${_pct(b.count, total)})',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: b.count / mx,
                minHeight: 8,
                color: b.color,
                backgroundColor: b.color.withValues(alpha: 0.12),
              ),
            ),
          ]),
        ),
    ]);
  }
}

class _MonthlyChart extends StatelessWidget {
  final List<Report> list;
  const _MonthlyChart(this.list);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = [
      for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i, 1)
    ];
    final created = <int>[];
    final closed = <int>[];
    for (final m in months) {
      created.add(list
          .where((r) => r.createdAt.year == m.year && r.createdAt.month == m.month)
          .length);
      closed.add(list
          .where((r) =>
              r.closedAt != null &&
              r.closedAt!.year == m.year &&
              r.closedAt!.month == m.month)
          .length);
    }
    final cs = Theme.of(context).colorScheme;
    final labels = [for (final m in months) _monthName(m.month)];
    return Column(children: [
      SizedBox(
        height: 170,
        child: CustomPaint(
          size: const Size(double.infinity, 170),
          painter: _BarsPainter(
            created: created,
            closed: closed,
            labels: labels,
            c1: cs.primary,
            c2: const Color(0xFF00897B),
            text: cs.onSurface,
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _dot(cs.primary, _l('تم تسجيلها', 'Reported')),
        const SizedBox(width: 18),
        _dot(const Color(0xFF00897B), _l('تم إغلاقها', 'Closed')),
      ]),
    ]);
  }

  Widget _dot(Color c, String t) => Row(children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(t, style: const TextStyle(fontSize: 12)),
      ]);
}

class _BarsPainter extends CustomPainter {
  final List<int> created;
  final List<int> closed;
  final List<String> labels;
  final Color c1;
  final Color c2;
  final Color text;
  _BarsPainter({
    required this.created,
    required this.closed,
    required this.labels,
    required this.c1,
    required this.c2,
    required this.text,
  });

  void _txt(Canvas canvas, String s, Offset center, double fs, Color col) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: fs, color: col)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    var mx = 1;
    for (final v in [...created, ...closed]) {
      if (v > mx) mx = v;
    }
    final n = created.length;
    final slot = size.width / n;
    const top = 18.0;
    const bottom = 22.0;
    final h = size.height - top - bottom;
    final bw = (slot * 0.28).clamp(6.0, 22.0);
    final base = size.height - bottom;
    canvas.drawLine(Offset(0, base), Offset(size.width, base),
        Paint()..color = text.withValues(alpha: 0.15));
    for (var i = 0; i < n; i++) {
      final cx = slot * i + slot / 2;
      void bar(int v, double x, Color col) {
        final bh = v == 0 ? 0.0 : (h * v / mx).clamp(3.0, h);
        final r = RRect.fromRectAndCorners(
            Rect.fromLTWH(x, base - bh, bw, bh),
            topLeft: const Radius.circular(5),
            topRight: const Radius.circular(5));
        canvas.drawRRect(r, Paint()..color = col);
        if (v > 0) {
          _txt(canvas, '$v', Offset(x + bw / 2, base - bh - 8), 10,
              text.withValues(alpha: 0.8));
        }
      }

      bar(created[i], cx - bw - 1.5, c1);
      bar(closed[i], cx + 1.5, c2);
      _txt(canvas, labels[i], Offset(cx, size.height - 8), 11,
          text.withValues(alpha: 0.65));
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter o) => true;
}
