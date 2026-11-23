import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' show PdfColors, PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show PdfGoogleFonts;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OptionStore.load();
  runApp(const EcoReportApp());
}

const String kUserAgent = 'com.ecoreport.eco_report';

// ═════════════════════════ القوائم والاختيارات ═════════════════════════

/// اختيار بقيمتين: الإنجليزي (بيتخزن وبيتصدّر زي الشيت) والعربي (بيظهر في التطبيق).
class Opt {
  final String en;
  final String ar;
  const Opt(this.en, this.ar);
  String get label => en == ar ? ar : '$ar  ·  $en';
}

const List<Opt> kStatuses = [
  Opt('Open', 'مفتوح'),
  Opt('In progress', 'جاري المعالجة'),
  Opt('Closed', 'مغلق'),
];

const List<Opt> kSeverities = [
  Opt('Low', 'منخفضة'),
  Opt('Medium', 'متوسطة'),
  Opt('High', 'عالية'),
];

const List<Opt> kImpacts = [
  Opt('Soil', 'تربة'),
  Opt('Water', 'مياه'),
  Opt('Air', 'هواء'),
  Opt('Health & safety', 'صحة وسلامة'),
];

String arOf(List<Opt> list, String en) {
  for (final o in list) {
    if (o.en == en) return o.ar;
  }
  return en;
}

Color statusColor(String s) {
  if (s == 'Closed') return const Color(0xFF2E7D32);
  if (s == 'In progress') return const Color(0xFFEF6C00);
  return const Color(0xFFC62828);
}

Color severityColor(String s) {
  if (s == 'High') return const Color(0xFFC62828);
  if (s == 'Medium') return const Color(0xFFEF6C00);
  return const Color(0xFF2E7D32);
}

class OptionStore {
  static const List<String> kinds = ['location', 'type', 'resp'];
  static const String _prefix = 'custom_opts_';

  static const Map<String, List<Opt>> _defaults = {
    'location': [
      Opt('Quarry', 'المحجر'),
      Opt('Crusher', 'الكسارة'),
      Opt('Raw mill building', 'مبنى طاحونة الخام'),
      Opt('Kiln & preheater', 'الفرن والمبادل الحراري'),
      Opt('Clinker cooler & storage', 'مبرد وصومعة الكلنكر'),
      Opt('Coal mill', 'طاحونة الفحم'),
      Opt('Alternative fuels (AFR) area', 'منطقة الوقود البديل'),
      Opt('Cement mill building', 'مبنى طاحونة الأسمنت'),
      Opt('Cement silos', 'صوامع الأسمنت'),
      Opt('Packing building', 'مبنى التعبئة'),
      Opt('Truck loading area', 'منطقة تحميل الشاحنات'),
      Opt('Workshop', 'الورشة'),
      Opt('Hazardous waste warehouse', 'مخزن المخلفات الخطرة'),
      Opt('Scrap yard', 'ساحة الخردة'),
      Opt('General warehouse', 'المخزن العام'),
      Opt('Laboratory', 'المعمل'),
      Opt('Electrical substation', 'محطة الكهرباء'),
      Opt('Wastewater treatment', 'محطة معالجة المياه'),
      Opt('Roads & yards', 'الطرق والساحات'),
      Opt('Offices', 'المباني الإدارية'),
      Opt('Canteen & rest areas', 'الكافتيريا وأماكن الراحة'),
    ],
    'type': [
      Opt('Hazardous waste', 'مخلفات خطرة'),
      Opt('Non-hazardous waste', 'مخلفات غير خطرة'),
      Opt('Used oil / grease', 'زيوت وشحومات مستعملة'),
      Opt('Oil / chemical spill or leak', 'تسرب زيوت أو كيماويات'),
      Opt('Construction & demolition waste', 'مخلفات بناء وهدم'),
      Opt('Scrap metal', 'خردة معادن'),
      Opt('Dust emission', 'انبعاثات أتربة'),
      Opt('Wastewater / water pollution', 'صرف / تلوث مياه'),
      Opt('Waste burning', 'حرق مخلفات'),
      Opt('Medical waste', 'مخلفات طبية'),
      Opt('Electronic waste', 'مخلفات إلكترونية'),
      Opt('Animal waste', 'مخلفات حيوانية'),
      Opt('Waste segregation violation', 'مخالفة فرز المخلفات'),
      Opt('Storage / labelling violation', 'مخالفة تخزين أو ملصقات'),
      Opt('Poor housekeeping', 'سوء نظافة وتنظيم'),
      Opt('Noise', 'ضوضاء'),
    ],
    'resp': [
      Opt('Mechanical maintenance', 'الصيانة الميكانيكية'),
      Opt('Electrical maintenance', 'الصيانة الكهربائية'),
      Opt('Production', 'الإنتاج'),
      Opt('Quarry', 'المحجر'),
      Opt('Packing', 'التعبئة'),
      Opt('Inspection', 'الفحص'),
      Opt('Quality', 'الجودة'),
      Opt('Laboratory', 'المعمل'),
      Opt('Logistics', 'اللوجستيات'),
      Opt('Warehouse', 'المخازن'),
      Opt('Civil', 'الأعمال المدنية'),
      Opt('Safety', 'السلامة'),
      Opt('Environment', 'البيئة'),
      Opt('Contractor', 'مقاول'),
      Opt('Administration', 'الإدارة'),
    ],
  };

  static final Map<String, List<String>> _custom = {
    'location': <String>[],
    'type': <String>[],
    'resp': <String>[],
  };

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    for (final k in kinds) {
      _custom[k] = p.getStringList('$_prefix$k') ?? <String>[];
    }
  }

  static List<Opt> list(String kind) => [
        ..._defaults[kind]!,
        ..._custom[kind]!.map((s) => Opt(s, s)),
      ];

  static String ar(String kind, String value) => arOf(list(kind), value);

  /// يضيف اختيار جديد ويرجّع قيمته (أو القيمة الموجودة لو مكرر).
  static Future<String?> add(String kind, String text) async {
    final t = text.trim();
    if (t.isEmpty) return null;
    for (final o in list(kind)) {
      if (o.en.toLowerCase() == t.toLowerCase() ||
          o.ar.toLowerCase() == t.toLowerCase()) {
        return o.en;
      }
    }
    _custom[kind]!.add(t);
    final p = await SharedPreferences.getInstance();
    await p.setStringList('$_prefix$kind', _custom[kind]!);
    return t;
  }
}

// ═════════════════════════ النموذج ═════════════════════════

class Report {
  final String id;
  int no;
  DateTime createdAt;
  String location;
  String type;
  String responsibility;
  String severity;
  String description;
  List<String> impacts;
  String reporter;
  String imagePath;
  String? closedImagePath;
  String status;
  String correctiveAction;
  DateTime? dueDate;
  DateTime? closedAt;
  double? lat;
  double? lng;

  Report({
    required this.id,
    required this.no,
    required this.createdAt,
    required this.location,
    required this.type,
    required this.imagePath,
    this.responsibility = '',
    this.severity = 'Medium',
    this.description = '',
    List<String>? impacts,
    this.reporter = '',
    this.closedImagePath,
    this.status = 'Open',
    this.correctiveAction = '',
    this.dueDate,
    this.closedAt,
    this.lat,
    this.lng,
  }) : impacts = impacts ?? <String>[];

  bool get hasLocation => lat != null && lng != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'no': no,
        'createdAt': createdAt.toIso8601String(),
        'location': location,
        'type': type,
        'responsibility': responsibility,
        'severity': severity,
        'description': description,
        'impacts': impacts,
        'reporter': reporter,
        'imagePath': imagePath,
        'closedImagePath': closedImagePath,
        'status': status,
        'correctiveAction': correctiveAction,
        'dueDate': dueDate?.toIso8601String(),
        'closedAt': closedAt?.toIso8601String(),
        'lat': lat,
        'lng': lng,
      };

  factory Report.fromJson(Map<String, dynamic> j) => Report(
        id: j['id'] as String,
        no: (j['no'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(j['createdAt'] as String),
        location: (j['location'] ?? '') as String,
        type: (j['type'] ?? j['category'] ?? '') as String,
        responsibility: (j['responsibility'] ?? '') as String,
        severity: (j['severity'] ?? 'Medium') as String,
        description: (j['description'] ?? '') as String,
        impacts: ((j['impacts'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        reporter: (j['reporter'] ?? '') as String,
        imagePath: j['imagePath'] as String,
        closedImagePath: j['closedImagePath'] as String?,
        status: (j['status'] ?? 'Open') as String,
        correctiveAction: (j['correctiveAction'] ?? '') as String,
        dueDate: j['dueDate'] == null
            ? null
            : DateTime.parse(j['dueDate'] as String),
        closedAt: j['closedAt'] == null
            ? null
            : DateTime.parse(j['closedAt'] as String),
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
      );

  Report copy() => Report.fromJson(toJson());
}

bool isOverdue(Report r) {
  if (r.status == 'Closed' || r.dueDate == null) return false;
  final n = DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  return r.dueDate!.isBefore(today);
}

// ═════════════════════════ التخزين المحلي ═════════════════════════

class ReportStore {
  static const _key = 'reports_v1';
  static const _counterKey = 'report_counter';

  static Future<List<Report>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List)
        .map((e) => Report.fromJson(e as Map<String, dynamic>))
        .toList();

    var counter = prefs.getInt(_counterKey) ?? 0;
    for (final r in list) {
      if (r.no > counter) counter = r.no;
    }
    final legacy = list.where((r) => r.no == 0).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    if (legacy.isNotEmpty) {
      for (final r in legacy) {
        counter++;
        r.no = counter;
      }
      await prefs.setInt(_counterKey, counter);
      await _save(list);
    }

    list.sort((a, b) {
      final c = b.createdAt.compareTo(a.createdAt);
      return c != 0 ? c : b.no.compareTo(a.no);
    });
    return list;
  }

  static Future<void> _save(List<Report> reports) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(reports.map((r) => r.toJson()).toList()));
  }

  static Future<String> copyImage(XFile f) async {
    final dir = await getApplicationDocumentsDirectory();
    final dest = '${dir.path}/img_${DateTime.now().microsecondsSinceEpoch}.jpg';
    await File(f.path).copy(dest);
    return dest;
  }

  static Future<Report> add(Report r) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await load();
    var counter = prefs.getInt(_counterKey) ?? 0;
    for (final x in list) {
      if (x.no > counter) counter = x.no;
    }
    counter++;
    r.no = counter;
    await prefs.setInt(_counterKey, counter);
    list.add(r);
    await _save(list);
    return r;
  }

  static Future<void> update(Report r) async {
    final list = await load();
    final i = list.indexWhere((x) => x.id == r.id);
    if (i >= 0) list[i] = r;
    await _save(list);
  }

  static Future<void> delete(Report r) async {
    final list = await load();
    list.removeWhere((x) => x.id == r.id);
    await _save(list);
    for (final p in [r.imagePath, r.closedImagePath]) {
      if (p == null) continue;
      try {
        final f = File(p);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }
}

// ═════════════════════════ أدوات مساعدة ═════════════════════════

String _two(int n) => n.toString().padLeft(2, '0');
String fmtDate(DateTime d) => '${d.year}/${_two(d.month)}/${_two(d.day)}';
String fmtIso(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

String mapsLink(Report r) => 'https://maps.google.com/?q=${r.lat},${r.lng}';

void snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

InputDecoration deco(String label, {String? hint, IconData? icon}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon),
    border: const OutlineInputBorder(),
    filled: true,
    fillColor: Colors.white,
  );
}

Future<XFile?> pickPhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Wrap(children: [
        ListTile(
          leading: const Icon(Icons.photo_camera),
          title: const Text('تصوير بالكاميرا'),
          onTap: () => Navigator.pop(ctx, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library),
          title: const Text('اختيار من المعرض'),
          onTap: () => Navigator.pop(ctx, ImageSource.gallery),
        ),
      ]),
    ),
  );
  if (source == null) return null;
  return ImagePicker()
      .pickImage(source: source, maxWidth: 1600, imageQuality: 80);
}

Future<String?> askText(BuildContext context, String title) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextPrompt(title: title),
  );
}

class _TextPrompt extends StatefulWidget {
  final String title;
  const _TextPrompt({required this.title});

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _c,
        autofocus: true,
        decoration: deco('الاسم'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            final t = _c.text.trim();
            Navigator.pop(context, t.isEmpty ? null : t);
          },
          child: const Text('إضافة'),
        ),
      ],
    );
  }
}

// ─────────── مشاركة / خرائط ───────────

String reportText(Report r) {
  final lines = <String>[
    'بلاغ بيئي رقم ${r.no}',
    'التاريخ: ${fmtDate(r.createdAt)}',
    'المكان: ${OptionStore.ar('location', r.location)}',
    'النوع: ${OptionStore.ar('type', r.type)}',
    if (r.responsibility.isNotEmpty)
      'المسؤول: ${OptionStore.ar('resp', r.responsibility)}',
    'الخطورة: ${arOf(kSeverities, r.severity)}',
    'الحالة: ${arOf(kStatuses, r.status)}',
    if (r.description.isNotEmpty) 'الوصف: ${r.description}',
    if (r.correctiveAction.isNotEmpty)
      'الإجراء التصحيحي: ${r.correctiveAction}',
    if (r.hasLocation) 'الموقع: ${mapsLink(r)}',
  ];
  return lines.join('\n');
}

Future<void> shareReport(BuildContext context, Report r) async {
  try {
    final files = <XFile>[XFile(r.imagePath)];
    if (r.closedImagePath != null) files.add(XFile(r.closedImagePath!));
    await Share.shareXFiles(files, text: reportText(r));
  } catch (_) {
    if (context.mounted) snack(context, 'تعذّرت المشاركة، جرّب تاني');
  }
}

Future<void> openInMaps(BuildContext context, Report r) async {
  final ok = await launchUrl(Uri.parse(mapsLink(r)),
      mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) snack(context, 'مقدرناش نفتح الخرائط');
}

// ─────────── تصدير CSV (بنفس أعمدة الشيت) ───────────

String _csvCell(String v) => '"${v.replaceAll('"', '""')}"';

Future<File> buildCsv(List<Report> list) async {
  const headers = [
    'n',
    'date',
    'location',
    'description',
    'type',
    'responsibility',
    'severity',
    'status',
    'impacts',
    'reported by',
    'corrective action',
    'due date',
    'closed date',
    'latitude',
    'longitude',
    'map link',
  ];
  final sorted = [...list]..sort((a, b) => a.no.compareTo(b.no));
  final rows = <String>[headers.map(_csvCell).join(',')];
  for (final r in sorted) {
    final cells = <String>[
      '${r.no}',
      fmtIso(r.createdAt),
      r.location,
      r.description,
      r.type,
      r.responsibility,
      r.severity,
      r.status,
      r.impacts.join(' / '),
      r.reporter,
      r.correctiveAction,
      r.dueDate == null ? '' : fmtIso(r.dueDate!),
      r.closedAt == null ? '' : fmtIso(r.closedAt!),
      r.lat?.toStringAsFixed(6) ?? '',
      r.lng?.toStringAsFixed(6) ?? '',
      r.hasLocation ? mapsLink(r) : '',
    ];
    rows.add(cells.map(_csvCell).join(','));
  }
  final dir = await getTemporaryDirectory();
  final file = File(
      '${dir.path}/eco_register_${DateTime.now().millisecondsSinceEpoch}.csv');
  await file.writeAsString('﻿${rows.join('\r\n')}');
  return file;
}

Future<void> exportCsv(BuildContext context, List<Report> list) async {
  if (list.isEmpty) {
    snack(context, 'مفيش بلاغات للتصدير');
    return;
  }
  final messenger = ScaffoldMessenger.of(context);
  try {
    final f = await buildCsv(list);
    await Share.shareXFiles(
      [XFile(f.path, mimeType: 'text/csv')],
      text: 'سجل المخالفات البيئية',
    );
  } catch (_) {
    messenger.showSnackBar(
        const SnackBar(content: Text('تعذّر إنشاء الملف، جرّب تاني')));
  }
}

// ─────────── تصدير PDF (بالصور) ───────────

Future<pw.Widget?> _pdfPhoto(String? path, String caption, pw.Font font) async {
  if (path == null) return null;
  try {
    final bytes = await File(path).readAsBytes();
    return pw.Column(children: [
      pw.Container(
        height: 190,
        alignment: pw.Alignment.center,
        child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
      ),
      pw.SizedBox(height: 2),
      pw.Text(caption,
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(font: font, fontSize: 10)),
    ]);
  } catch (_) {
    return null;
  }
}

Future<File> buildPdf(List<Report> list, String title) async {
  final regular = await PdfGoogleFonts.cairoRegular();
  final bold = await PdfGoogleFonts.cairoBold();
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );

  pw.Widget t(String text, {bool strong = false, double size = 12}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.only(top: 3),
      child: pw.Text(
        text,
        textDirection: pw.TextDirection.rtl,
        textAlign: pw.TextAlign.right,
        style: pw.TextStyle(font: strong ? bold : regular, fontSize: size),
      ),
    );
  }

  final sorted = [...list]..sort((a, b) => a.no.compareTo(b.no));
  final open = sorted.where((r) => r.status == 'Open').length;
  final prog = sorted.where((r) => r.status == 'In progress').length;
  final closed = sorted.where((r) => r.status == 'Closed').length;

  final widgets = <pw.Widget>[
    pw.Container(
      width: double.infinity,
      alignment: pw.Alignment.center,
      child: pw.Text(title,
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(font: bold, fontSize: 22)),
    ),
    pw.SizedBox(height: 4),
    pw.Container(
      width: double.infinity,
      alignment: pw.Alignment.center,
      child: pw.Text(
        'تاريخ التصدير: ${fmtDate(DateTime.now())}   |   الإجمالي: ${sorted.length}   |   مفتوح: $open   |   جاري: $prog   |   مغلق: $closed',
        textDirection: pw.TextDirection.rtl,
        style: pw.TextStyle(font: regular, fontSize: 11),
      ),
    ),
    pw.SizedBox(height: 6),
  ];

  for (final r in sorted) {
    widgets.add(pw.Divider(color: PdfColors.grey500));
    widgets.add(t(
      'بلاغ رقم ${r.no} - ${OptionStore.ar('type', r.type)}',
      strong: true,
      size: 14,
    ));

    final before = await _pdfPhoto(r.imagePath, 'قبل', regular);
    final after = await _pdfPhoto(r.closedImagePath, 'بعد المعالجة', regular);
    final photos = <pw.Widget>[];
    if (before != null) photos.add(pw.Expanded(child: before));
    if (after != null) {
      photos.add(pw.SizedBox(width: 8));
      photos.add(pw.Expanded(child: after));
    }
    if (photos.isNotEmpty) {
      widgets.add(pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        child: pw.Row(children: photos),
      ));
    }

    widgets.add(t('المكان: ${OptionStore.ar('location', r.location)}'));
    if (r.responsibility.isNotEmpty) {
      widgets.add(t('المسؤول: ${OptionStore.ar('resp', r.responsibility)}'));
    }
    widgets.add(t('التاريخ: ${fmtDate(r.createdAt)}'));
    widgets.add(t('الخطورة: ${arOf(kSeverities, r.severity)}'));
    widgets.add(t('الحالة: ${arOf(kStatuses, r.status)}'));
    if (r.description.isNotEmpty) widgets.add(t('الوصف: ${r.description}'));
    if (r.impacts.isNotEmpty) {
      widgets.add(t('التأثير: ${r.impacts.map((e) => arOf(kImpacts, e)).join(" - ")}'));
    }
    if (r.reporter.isNotEmpty) widgets.add(t('تم الرصد بواسطة: ${r.reporter}'));
    if (r.correctiveAction.isNotEmpty) {
      widgets.add(t('الإجراء التصحيحي: ${r.correctiveAction}'));
    }
    if (r.dueDate != null) {
      widgets.add(t('تاريخ الاستحقاق: ${fmtDate(r.dueDate!)}'));
    }
    if (r.closedAt != null) {
      widgets.add(t('تاريخ الإغلاق: ${fmtDate(r.closedAt!)}'));
    }
    if (r.hasLocation) {
      widgets.add(t(
          'الموقع: ${r.lat!.toStringAsFixed(5)}, ${r.lng!.toStringAsFixed(5)}'));
      widgets.add(t(mapsLink(r), size: 9));
    }
    widgets.add(pw.SizedBox(height: 6));
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => widgets,
    ),
  );

  final dir = await getTemporaryDirectory();
  final file = File(
      '${dir.path}/eco_register_${DateTime.now().millisecondsSinceEpoch}.pdf');
  await file.writeAsBytes(await doc.save());
  return file;
}

Future<void> exportPdf(
    BuildContext context, List<Report> list, String title) async {
  if (list.isEmpty) {
    snack(context, 'مفيش بلاغات للتصدير');
    return;
  }
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger
      .showSnackBar(const SnackBar(content: Text('جاري تجهيز ملف PDF...')));
  try {
    final file = await buildPdf(list, title);
    messenger.hideCurrentSnackBar();
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: title,
    );
  } catch (_) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(
        content: Text('تعذّر إنشاء الـ PDF. تأكد من الإنترنت وجرّب تاني')));
  }
}

// ═════════════════════════ عناصر واجهة مشتركة ═════════════════════════

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const _Badge(this.text, this.color, {this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  final String path;
  const _Photo(this.path);

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade300,
        child: const Center(child: Icon(Icons.broken_image, size: 36)),
      ),
    );
  }
}

/// حقل بيشبه الـ dropdown وبيفتح قايمة اختيارات.
class FieldBox extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? text;
  final VoidCallback onTap;
  final Widget? trailing;
  const FieldBox({
    super.key,
    required this.label,
    required this.icon,
    required this.text,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: trailing ?? const Icon(Icons.arrow_drop_down),
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        isEmpty: text == null || text!.isEmpty,
        child: Text(
          text ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

const String _clearToken = '__clear__';

class PickerField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String kind;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool allowAdd;
  final String? clearLabel;

  const PickerField({
    super.key,
    required this.label,
    required this.icon,
    required this.kind,
    required this.value,
    required this.onChanged,
    this.allowAdd = true,
    this.clearLabel,
  });

  Future<void> _open(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PickerSheet(
        title: label,
        kind: kind,
        value: value,
        allowAdd: allowAdd,
        clearLabel: clearLabel,
      ),
    );
    if (result == null) return;
    onChanged(result == _clearToken ? null : result);
  }

  @override
  Widget build(BuildContext context) {
    String? shown;
    if (value != null && value!.isNotEmpty) {
      shown = OptionStore.ar(kind, value!);
    }
    return FieldBox(
      label: label,
      icon: icon,
      text: shown,
      onTap: () => _open(context),
    );
  }
}

class _PickerSheet extends StatelessWidget {
  final String title;
  final String kind;
  final String? value;
  final bool allowAdd;
  final String? clearLabel;

  const _PickerSheet({
    required this.title,
    required this.kind,
    required this.value,
    required this.allowAdd,
    required this.clearLabel,
  });

  @override
  Widget build(BuildContext context) {
    final options = OptionStore.list(kind);
    final maxH = MediaQuery.of(context).size.height * 0.7;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(title,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (clearLabel != null)
                    ListTile(
                      leading: const Icon(Icons.clear),
                      title: Text(clearLabel!),
                      onTap: () => Navigator.pop(context, _clearToken),
                    ),
                  for (final o in options)
                    ListTile(
                      title: Text(o.label),
                      trailing: o.en == value
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      onTap: () => Navigator.pop(context, o.en),
                    ),
                  if (allowAdd)
                    ListTile(
                      leading: const Icon(Icons.add_circle_outline),
                      title: const Text('إضافة خيار جديد'),
                      onTap: () async {
                        final text = await askText(context, 'خيار جديد');
                        if (text == null) return;
                        final added = await OptionStore.add(kind, text);
                        if (added != null && context.mounted) {
                          Navigator.pop(context, added);
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════ التطبيق ═════════════════════════

class EcoReportApp extends StatelessWidget {
  const EcoReportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'رصد المخلفات',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2E7D32),
        scaffoldBackgroundColor: const Color(0xFFF3F7F1),
      ),
      home: const AppShell(),
    );
  }
}

class FilterResult {
  final String? type;
  final String? location;
  const FilterResult(this.type, this.location);
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  bool _loading = true;
  List<Report> _reports = [];
  String? _status;
  String? _type;
  String? _location;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ReportStore.load();
    if (!mounted) return;
    setState(() {
      _reports = r;
      _loading = false;
    });
  }

  List<Report> get _filtered => _reports.where((r) {
        if (_status != null && r.status != _status) return false;
        if (_type != null && r.type != _type) return false;
        if (_location != null && r.location != _location) return false;
        return true;
      }).toList();

  bool get _hasExtraFilter => _type != null || _location != null;

  Future<void> _openNew() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NewReportScreen()),
    );
    _load();
  }

  Future<void> _openDetails(Report r) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(report: r)),
    );
    _load();
  }

  Future<void> _openFilter() async {
    final res = await showModalBottomSheet<FilterResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(type: _type, location: _location),
    );
    if (res == null) return;
    setState(() {
      _type = res.type;
      _location = res.location;
    });
  }

  Future<void> _export(String kind) async {
    const title = 'سجل المخالفات البيئية';
    if (kind == 'pdf') {
      await exportPdf(context, _filtered, title);
    } else {
      await exportCsv(context, _filtered);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _tab,
              children: [
                ReportsTab(
                  all: _reports,
                  filtered: _filtered,
                  status: _status,
                  hasExtraFilter: _hasExtraFilter,
                  onStatus: (v) => setState(() => _status = v),
                  onFilter: _openFilter,
                  onOpen: _openDetails,
                  onExport: _export,
                ),
                MapTab(reports: _filtered, onOpen: _openDetails),
              ],
            ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: _openNew,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('تسجيل مخالفة'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'السجل',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'الخريطة',
          ),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final String? type;
  final String? location;
  const _FilterSheet({required this.type, required this.location});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _type = widget.type;
  late String? _location = widget.location;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PickerField(
              label: 'نوع المخالفة',
              icon: Icons.category_outlined,
              kind: 'type',
              value: _type,
              allowAdd: false,
              clearLabel: 'الكل',
              onChanged: (v) => setState(() => _type = v),
            ),
            const SizedBox(height: 12),
            PickerField(
              label: 'المكان',
              icon: Icons.place_outlined,
              kind: 'location',
              value: _location,
              allowAdd: false,
              clearLabel: 'الكل',
              onChanged: (v) => setState(() => _location = v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.pop(context, const FilterResult(null, null)),
                    child: const Text('مسح الفلتر'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, FilterResult(_type, _location)),
                    child: const Text('تطبيق'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════ تبويب السجل ═════════════════════════

class ReportsTab extends StatelessWidget {
  final List<Report> all;
  final List<Report> filtered;
  final String? status;
  final bool hasExtraFilter;
  final ValueChanged<String?> onStatus;
  final VoidCallback onFilter;
  final ValueChanged<Report> onOpen;
  final ValueChanged<String> onExport;

  const ReportsTab({
    super.key,
    required this.all,
    required this.filtered,
    required this.status,
    required this.hasExtraFilter,
    required this.onStatus,
    required this.onFilter,
    required this.onOpen,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final open = all.where((r) => r.status == 'Open').length;
    final prog = all.where((r) => r.status == 'In progress').length;
    final closed = all.where((r) => r.status == 'Closed').length;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
              16, MediaQuery.of(context).padding.top + 12, 16, 18),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.eco, color: Colors.white, size: 30),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'سجل المخالفات البيئية',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'تصدير',
                    icon: const Icon(Icons.ios_share, color: Colors.white),
                    onSelected: onExport,
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'pdf', child: Text('تصدير PDF (بالصور)')),
                      PopupMenuItem(
                          value: 'csv', child: Text('تصدير Excel / CSV')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Stat('الإجمالي', all.length),
                  _Stat('مفتوح', open),
                  _Stat('جاري', prog),
                  _Stat('مغلق', closed),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 56,
          child: Row(
            children: [
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: const Text('الكل'),
                        selected: status == null,
                        onSelected: (_) => onStatus(null),
                      ),
                    ),
                    for (final s in kStatuses)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(s.ar),
                          selected: status == s.en,
                          onSelected: (_) =>
                              onStatus(status == s.en ? null : s.en),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'فلترة',
                onPressed: onFilter,
                icon: Icon(
                  hasExtraFilter ? Icons.filter_alt : Icons.filter_alt_outlined,
                  color: hasExtraFilter ? Colors.green.shade800 : null,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      all.isEmpty
                          ? 'مفيش بلاغات لسه.\nاضغط "تسجيل مخالفة" وصوّر أي مخلفات في الموقع.'
                          : 'مفيش بلاغات بالفلتر ده.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _ReportCard(
                    r: filtered[i],
                    onTap: () => onOpen(filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x2EFFFFFF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Report r;
  final VoidCallback onTap;
  const _ReportCard({required this.r, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final overdue = isOverdue(r);
    return Card(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      clipBehavior: Clip.antiAlias,
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 128,
          child: Row(
            children: [
              SizedBox(width: 104, child: _Photo(r.imagePath)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('#${r.no}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              OptionStore.ar('location', r.location),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        r.description.isEmpty ? 'بدون وصف' : r.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const Spacer(),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _Badge(arOf(kStatuses, r.status),
                              statusColor(r.status)),
                          _Badge(OptionStore.ar('type', r.type),
                              const Color(0xFF455A64)),
                          if (overdue)
                            const _Badge('متأخر', Color(0xFFB71C1C),
                                icon: Icons.schedule),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 3),
                          Text(fmtDate(r.createdAt),
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 11)),
                          const Spacer(),
                          Icon(Icons.circle,
                              size: 10, color: severityColor(r.severity)),
                          const SizedBox(width: 3),
                          Text(arOf(kSeverities, r.severity),
                              style: const TextStyle(fontSize: 11)),
                          const SizedBox(width: 8),
                          Icon(
                            r.hasLocation
                                ? Icons.location_on
                                : Icons.location_off,
                            size: 16,
                            color: r.hasLocation ? Colors.green : Colors.grey,
                          ),
                        ],
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

// ═════════════════════════ تبويب الخريطة ═════════════════════════

class MapTab extends StatelessWidget {
  final List<Report> reports;
  final ValueChanged<Report> onOpen;
  const MapTab({super.key, required this.reports, required this.onOpen});

  void _preview(BuildContext context, Report r) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 90,
                  height: 90,
                  child: _Photo(r.imagePath),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '#${r.no}  ${OptionStore.ar('location', r.location)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        _Badge(arOf(kStatuses, r.status),
                            statusColor(r.status)),
                        _Badge(OptionStore.ar('type', r.type),
                            const Color(0xFF455A64)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.description.isEmpty ? 'بدون وصف' : r.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  onOpen(r);
                },
                child: const Text('التفاصيل'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final located = reports.where((r) => r.hasLocation).toList();
    if (located.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'مفيش بلاغات عليها موقع لسه.\nلما تسجّل بلاغ والـ GPS شغال هيظهر هنا على الخريطة.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    final points = located.map((r) => LatLng(r.lat!, r.lng!)).toList();
    final options = points.length == 1
        ? MapOptions(initialCenter: points.first, initialZoom: 15)
        : MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: points,
              padding: const EdgeInsets.all(60),
              maxZoom: 16,
            ),
          );

    return Stack(
      children: [
        FlutterMap(
          key: ValueKey(points.length),
          options: options,
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: kUserAgent,
            ),
            MarkerLayer(
              markers: [
                for (final r in located)
                  Marker(
                    point: LatLng(r.lat!, r.lng!),
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => _preview(context, r),
                      child: Icon(
                        Icons.location_on,
                        size: 44,
                        color: statusColor(r.status),
                      ),
                    ),
                  ),
              ],
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 6),
              ],
            ),
            child: Text(
              'خريطة البلاغات (${located.length})  🔴 مفتوح  🟠 جاري  🟢 مغلق',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════ شاشة بلاغ جديد ═════════════════════════

class NewReportScreen extends StatefulWidget {
  const NewReportScreen({super.key});

  @override
  State<NewReportScreen> createState() => _NewReportScreenState();
}

class _NewReportScreenState extends State<NewReportScreen> {
  final _descCtrl = TextEditingController();
  final _reporterCtrl = TextEditingController();
  final _actionCtrl = TextEditingController();

  XFile? _photo;
  DateTime _date = DateTime.now();
  String? _location;
  String? _type;
  String? _resp;
  String _severity = 'Medium';
  final Set<String> _impacts = {};
  DateTime? _due;

  Position? _position;
  bool _locating = false;
  bool _saving = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _loadReporter();
    _getLocation();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _reporterCtrl.dispose();
    _actionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReporter() async {
    try {
      final p = await SharedPreferences.getInstance();
      final name = p.getString('reporter_name') ?? '';
      if (mounted && _reporterCtrl.text.isEmpty) _reporterCtrl.text = name;
    } catch (_) {}
  }

  Future<void> _getLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'شغّل الـ GPS من إعدادات الموبايل';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw 'مفيش صلاحية للوصول للموقع';
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 20));
      if (mounted) setState(() => _position = pos);
    } catch (e) {
      if (mounted) {
        setState(() => _locationError =
            e is String ? e : 'مقدرناش نحدد الموقع، جرّب تاني');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _choosePhoto() async {
    final img = await pickPhoto(context);
    if (img != null && mounted) setState(() => _photo = img);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _due ?? now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (d != null) setState(() => _due = d);
  }

  Future<void> _save() async {
    if (_photo == null) {
      snack(context, 'لازم تضيف صورة للمخالفة');
      return;
    }
    if (_location == null) {
      snack(context, 'اختار المكان');
      return;
    }
    if (_type == null) {
      snack(context, 'اختار نوع المخالفة');
      return;
    }
    setState(() => _saving = true);
    try {
      final imgPath = await ReportStore.copyImage(_photo!);
      final now = DateTime.now();
      final r = Report(
        id: now.microsecondsSinceEpoch.toString(),
        no: 0,
        createdAt:
            DateTime(_date.year, _date.month, _date.day, now.hour, now.minute),
        location: _location!,
        type: _type!,
        responsibility: _resp ?? '',
        severity: _severity,
        description: _descCtrl.text.trim(),
        impacts: _impacts.toList(),
        reporter: _reporterCtrl.text.trim(),
        imagePath: imgPath,
        correctiveAction: _actionCtrl.text.trim(),
        dueDate: _due,
        lat: _position?.latitude,
        lng: _position?.longitude,
      );
      final saved = await ReportStore.add(r);
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString('reporter_name', r.reporter);
      } catch (_) {}
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      messenger.showSnackBar(
        SnackBar(content: Text('تم تسجيل البلاغ رقم ${saved.no} ✅')),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        snack(context, 'حصل خطأ أثناء الحفظ، جرّب تاني');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بلاغ جديد')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _choosePhoto,
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.green.shade200, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: _photo == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, size: 48, color: Colors.green),
                        SizedBox(height: 8),
                        Text('اضغط لإضافة صورة المخالفة *'),
                      ],
                    )
                  : Image.file(File(_photo!.path),
                      fit: BoxFit.cover, width: double.infinity),
            ),
          ),
          const SizedBox(height: 16),
          FieldBox(
            label: 'تاريخ الرصد',
            icon: Icons.event,
            text: fmtDate(_date),
            onTap: _pickDate,
            trailing: const Icon(Icons.edit_calendar),
          ),
          const SizedBox(height: 12),
          PickerField(
            label: 'المكان *',
            icon: Icons.place,
            kind: 'location',
            value: _location,
            onChanged: (v) => setState(() => _location = v),
          ),
          const SizedBox(height: 12),
          PickerField(
            label: 'نوع المخالفة *',
            icon: Icons.category,
            kind: 'type',
            value: _type,
            onChanged: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: deco(
              'الوصف',
              hint: 'مثال: وجود فلاتر أكياس خارج مخزن المخلفات الخطرة',
              icon: Icons.notes,
            ),
          ),
          const SizedBox(height: 12),
          PickerField(
            label: 'الجهة المسؤولة',
            icon: Icons.engineering,
            kind: 'resp',
            value: _resp,
            clearLabel: 'بدون تحديد',
            onChanged: (v) => setState(() => _resp = v),
          ),
          const SizedBox(height: 14),
          const Text('درجة الخطورة',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final s in kSeverities)
                ChoiceChip(
                  label: Text(s.ar),
                  selected: _severity == s.en,
                  selectedColor: severityColor(s.en).withAlpha(70),
                  onSelected: (_) => setState(() => _severity = s.en),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: _locating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(
                      _position != null
                          ? Icons.location_on
                          : Icons.location_off,
                      color: _position != null ? Colors.green : Colors.red,
                    ),
              title: Text(_locating
                  ? 'بنحدد موقعك...'
                  : _position != null
                      ? 'تم تحديد الموقع (GPS)'
                      : (_locationError ?? 'الموقع غير محدد')),
              subtitle: _position != null
                  ? Text(
                      '${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}')
                  : null,
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _locating ? null : _getLocation,
              ),
            ),
          ),
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.tune),
              title: const Text('تفاصيل إضافية (اختياري)'),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              children: [
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('التأثير البيئي',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final i in kImpacts)
                        FilterChip(
                          label: Text(i.ar),
                          selected: _impacts.contains(i.en),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _impacts.add(i.en);
                            } else {
                              _impacts.remove(i.en);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reporterCtrl,
                  decoration: deco('اسم المبلّغ', icon: Icons.person),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _actionCtrl,
                  maxLines: 2,
                  decoration: deco('الإجراء التصحيحي المقترح',
                      icon: Icons.build_circle_outlined),
                ),
                const SizedBox(height: 12),
                FieldBox(
                  label: 'تاريخ الاستحقاق للمعالجة',
                  icon: Icons.alarm,
                  text: _due == null ? null : fmtDate(_due!),
                  onTap: _pickDue,
                  trailing: _due == null
                      ? const Icon(Icons.edit_calendar)
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _due = null),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: const Text('تسجيل البلاغ'),
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════ شاشة التفاصيل ═════════════════════════

class DetailScreen extends StatefulWidget {
  final Report report;
  const DetailScreen({super.key, required this.report});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Report _r = widget.report;

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف البلاغ؟'),
        content: const Text('البلاغ هيتمسح نهائي من الموبايل.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) {
      await ReportStore.delete(_r);
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _update() async {
    final updated = await showModalBottomSheet<Report>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => UpdateSheet(report: _r),
    );
    if (updated == null) return;
    await ReportStore.update(updated);
    if (mounted) setState(() => _r = updated);
  }

  Widget _info(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label,
          style: const TextStyle(color: Colors.grey, fontSize: 12)),
      subtitle: Text(value, style: const TextStyle(fontSize: 15)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final overdue = isOverdue(r);
    return Scaffold(
      appBar: AppBar(
        title: Text('بلاغ رقم ${r.no}'),
        actions: [
          IconButton(
            tooltip: 'حذف',
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
                aspectRatio: 4 / 3, child: _Photo(r.imagePath)),
          ),
          if (r.closedImagePath != null) ...[
            const SizedBox(height: 10),
            const Text('بعد المعالجة',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                  aspectRatio: 4 / 3, child: _Photo(r.closedImagePath!)),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Badge(arOf(kStatuses, r.status), statusColor(r.status)),
              _Badge(OptionStore.ar('type', r.type), const Color(0xFF455A64)),
              _Badge('خطورة ${arOf(kSeverities, r.severity)}',
                  severityColor(r.severity)),
              if (overdue)
                const _Badge('متأخر', Color(0xFFB71C1C), icon: Icons.schedule),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  _info(Icons.place, 'المكان',
                      OptionStore.ar('location', r.location)),
                  _info(Icons.event, 'تاريخ الرصد', fmtDate(r.createdAt)),
                  _info(Icons.notes, 'الوصف', r.description),
                  _info(
                      Icons.engineering,
                      'الجهة المسؤولة',
                      r.responsibility.isEmpty
                          ? ''
                          : OptionStore.ar('resp', r.responsibility)),
                  _info(Icons.public, 'التأثير البيئي',
                      r.impacts.map((e) => arOf(kImpacts, e)).join(' - ')),
                  _info(Icons.person, 'المبلّغ', r.reporter),
                  _info(Icons.build_circle_outlined, 'الإجراء التصحيحي',
                      r.correctiveAction),
                  _info(Icons.alarm, 'تاريخ الاستحقاق',
                      r.dueDate == null ? '' : fmtDate(r.dueDate!)),
                  _info(Icons.verified, 'تاريخ الإغلاق',
                      r.closedAt == null ? '' : fmtDate(r.closedAt!)),
                  _info(
                      Icons.my_location,
                      'الإحداثيات',
                      r.hasLocation
                          ? '${r.lat!.toStringAsFixed(5)}, ${r.lng!.toStringAsFixed(5)}'
                          : 'غير مسجّلة'),
                ],
              ),
            ),
          ),
          if (r.hasLocation) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 180,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(r.lat!, r.lng!),
                    initialZoom: 16,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: kUserAgent,
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(r.lat!, r.lng!),
                          width: 44,
                          height: 44,
                          alignment: Alignment.topCenter,
                          child: Icon(Icons.location_on,
                              size: 44, color: statusColor(r.status)),
                        ),
                      ],
                    ),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _update,
            icon: const Icon(Icons.published_with_changes),
            label: const Text('تحديث الحالة / الإغلاق'),
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => shareReport(context, r),
            icon: const Icon(Icons.share),
            label: const Text('مشاركة (واتساب / إيميل)'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      exportPdf(context, [r], 'بلاغ مخالفة بيئية'),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('ملف PDF'),
                ),
              ),
              if (r.hasLocation) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => openInMaps(context, r),
                    icon: const Icon(Icons.map),
                    label: const Text('فتح في الخرائط'),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ═════════════════════════ تحديث الحالة / الإغلاق ═════════════════════════

class UpdateSheet extends StatefulWidget {
  final Report report;
  const UpdateSheet({super.key, required this.report});

  @override
  State<UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<UpdateSheet> {
  late final Report _copy = widget.report.copy();
  late final TextEditingController _action =
      TextEditingController(text: widget.report.correctiveAction);
  late String _status = widget.report.status;
  DateTime? _due;
  XFile? _newPhoto;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _due = widget.report.dueDate;
  }

  @override
  void dispose() {
    _action.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _due ?? now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (d != null) setState(() => _due = d);
  }

  Future<void> _pickAfterPhoto() async {
    final img = await pickPhoto(context);
    if (img != null && mounted) setState(() => _newPhoto = img);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      _copy.status = _status;
      _copy.correctiveAction = _action.text.trim();
      _copy.dueDate = _due;
      if (_newPhoto != null) {
        _copy.closedImagePath = await ReportStore.copyImage(_newPhoto!);
      }
      if (_status == 'Closed') {
        _copy.closedAt ??= DateTime.now();
      } else {
        _copy.closedAt = null;
      }
      if (mounted) Navigator.pop(context, _copy);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        snack(context, 'حصل خطأ أثناء الحفظ، جرّب تاني');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingAfter = _copy.closedImagePath;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('تحديث حالة البلاغ',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in kStatuses)
                    ChoiceChip(
                      label: Text(s.ar),
                      selected: _status == s.en,
                      selectedColor: statusColor(s.en).withAlpha(70),
                      onSelected: (_) => setState(() => _status = s.en),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _action,
                maxLines: 3,
                decoration: deco('الإجراء التصحيحي اللي اتعمل',
                    icon: Icons.build_circle_outlined),
              ),
              const SizedBox(height: 12),
              FieldBox(
                label: 'تاريخ الاستحقاق',
                icon: Icons.alarm,
                text: _due == null ? null : fmtDate(_due!),
                onTap: _pickDue,
                trailing: _due == null
                    ? const Icon(Icons.edit_calendar)
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _due = null),
                      ),
              ),
              if (_status == 'Closed') ...[
                const SizedBox(height: 12),
                if (_newPhoto != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 160,
                      width: double.infinity,
                      child: Image.file(File(_newPhoto!.path),
                          fit: BoxFit.cover),
                    ),
                  )
                else if (existingAfter != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 160,
                      width: double.infinity,
                      child: _Photo(existingAfter),
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickAfterPhoto,
                  icon: const Icon(Icons.add_a_photo),
                  label: Text(
                      (_newPhoto != null || existingAfter != null)
                          ? 'تغيير صورة بعد المعالجة'
                          : 'إضافة صورة بعد المعالجة'),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check),
                label: const Text('حفظ'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
