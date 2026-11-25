import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' show PdfColors, PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show PdfGoogleFonts;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

part 'config.dart';
part 'auth.dart';
part 'entry.dart';
part 'admin.dart';
part 'l10n.dart';
part 'biometric.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.load();
  await OptionStore.load();
  await Session.instance.load();
  await FactoryStore.instance.loadCache();
  runApp(const EcoReportApp());
}

const String kUserAgent = 'com.ecoreport.eco_report';

// ═════════════════════════ القوائم والاختيارات ═════════════════════════

/// اختيار بقيمتين: الإنجليزي (بيتخزن وبيتصدّر زي الشيت) والعربي (بيظهر في التطبيق).
class Opt {
  final String en;
  final String ar;
  const Opt(this.en, this.ar);
  /// الاسم المعروض حسب اللغة المختارة.
  String get text => AppSettings.instance.lang == 'en' ? en : ar;
  String get label => AppSettings.instance.lang == 'en'
      ? en
      : (en == ar ? ar : '$ar  ·  $en');
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
    if (o.en == en) return AppSettings.instance.lang == 'en' ? o.en : o.ar;
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
  DateTime updatedAt;
  String? imageUrl;
  String? closedImageUrl;
  bool remote;
  bool dirty;
  String? factoryId;

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
    DateTime? updatedAt,
    this.imageUrl,
    this.closedImageUrl,
    this.remote = false,
    this.dirty = false,
    this.factoryId,
  })  : impacts = impacts ?? <String>[],
        updatedAt = updatedAt ?? createdAt;

  bool get hasLocation => lat != null && lng != null;

  Map<String, dynamic> toServer() => {
        'id': id,
        'created_at': createdAt.toUtc().toIso8601String(),
        'location': location,
        'type': type,
        'responsibility': responsibility,
        'severity': severity,
        'description': description,
        'impacts': impacts,
        'reporter': reporter,
        'status': status,
        'corrective_action': correctiveAction,
        'due_date': dueDate?.toUtc().toIso8601String(),
        'closed_at': closedAt?.toUtc().toIso8601String(),
        'lat': lat,
        'lng': lng,
        'image_url': imageUrl,
        'closed_image_url': closedImageUrl,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'factory_id': factoryId,
      };

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
        'updatedAt': updatedAt.toIso8601String(),
        'imageUrl': imageUrl,
        'closedImageUrl': closedImageUrl,
        'remote': remote,
        'dirty': dirty,
        'factoryId': factoryId,
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
        updatedAt: j['updatedAt'] == null
            ? null
            : DateTime.parse(j['updatedAt'] as String),
        imageUrl: j['imageUrl'] as String?,
        closedImageUrl: j['closedImageUrl'] as String?,
        remote: (j['remote'] ?? false) as bool,
        dirty: (j['dirty'] ?? false) as bool,
        factoryId: j['factoryId'] as String?,
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
    final legacy = AppSettings.instance.syncActive
        ? <Report>[]
        : (list.where((r) => r.no == 0).toList()
          ..sort((a, b) => a.id.compareTo(b.id)));
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

  static Future<void> saveAll(List<Report> reports) => _save(reports);

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
    r.factoryId ??= Session.instance.activeFactoryId;
    if (AppSettings.instance.syncActive) {
      // الرقم بيتحدد من السيرفر بعد المزامنة.
      r.no = 0;
    } else {
      for (final x in list) {
        if (x.no > counter) counter = x.no;
      }
      counter++;
      r.no = counter;
      await prefs.setInt(_counterKey, counter);
    }
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

String noLabel(Report r) => r.no == 0 ? tr('جديد') : '#${r.no}';
String noText(Report r) => r.no == 0 ? tr('جديد') : trf('رقم {0}', [r.no]);

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
  );
}

Future<XFile?> pickPhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Wrap(children: [
        ListTile(
          leading: const Icon(Icons.photo_camera),
          title: Text(tr('تصوير بالكاميرا')),
          onTap: () => Navigator.pop(ctx, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library),
          title: Text(tr('اختيار من المعرض')),
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
        decoration: deco(tr('الاسم')),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('إلغاء')),
        ),
        FilledButton(
          onPressed: () {
            final t = _c.text.trim();
            Navigator.pop(context, t.isEmpty ? null : t);
          },
          child: Text(tr('إضافة')),
        ),
      ],
    );
  }
}

// ─────────── مشاركة / خرائط ───────────

String reportText(Report r) {
  final lines = <String>[
    'بلاغ بيئي ${noText(r)}',
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
    if (context.mounted) snack(context, tr('تعذّرت المشاركة، جرّب تاني'));
  }
}

Future<void> openInMaps(BuildContext context, Report r) async {
  final ok = await launchUrl(Uri.parse(mapsLink(r)),
      mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) snack(context, tr('مقدرناش نفتح الخرائط'));
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
      r.no == 0 ? '' : '${r.no}',
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
    snack(context, tr('مفيش بلاغات للتصدير'));
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
        SnackBar(content: Text(tr('تعذّر إنشاء الملف، جرّب تاني'))));
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
      'بلاغ ${noText(r)} - ${OptionStore.ar('type', r.type)}',
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
    snack(context, tr('مفيش بلاغات للتصدير'));
    return;
  }
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger
      .showSnackBar(SnackBar(content: Text(tr('جاري تجهيز ملف PDF...'))));
  try {
    final file = await buildPdf(list, title);
    messenger.hideCurrentSnackBar();
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: title,
    );
  } catch (_) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
        content: Text(tr('تعذّر إنشاء الـ PDF. تأكد من الإنترنت وجرّب تاني'))));
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
                      title: Text(tr('إضافة خيار جديد')),
                      onTap: () async {
                        final text = await askText(context, tr('خيار جديد'));
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

// ═════════════════════════ الإعدادات ═════════════════════════

int _ci(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const List<Color> seeds = [
    Color(0xFF2E7D32),
    Color(0xFF00796B),
    Color(0xFF00897B),
    Color(0xFF558B2F),
    Color(0xFF9E9D24),
    Color(0xFF1565C0),
    Color(0xFF0277BD),
    Color(0xFF283593),
    Color(0xFF3949AB),
    Color(0xFF6A1B9A),
    Color(0xFF8E24AA),
    Color(0xFFAD1457),
    Color(0xFFD81B60),
    Color(0xFFC62828),
    Color(0xFFE65100),
    Color(0xFFEF6C00),
    Color(0xFFF9A825),
    Color(0xFFFF8F00),
    Color(0xFF5D4037),
    Color(0xFF795548),
    Color(0xFF37474F),
    Color(0xFF546E7A),
    Color(0xFF212121),
    Color(0xFFB8860B),
  ];
  static const List<String> seedNames = [
    'أخضر',
    'تركواز',
    'أخضر مائي',
    'أخضر زيتي',
    'ليموني',
    'أزرق',
    'أزرق سماوي',
    'كحلي',
    'نيلي',
    'بنفسجي',
    'أرجواني',
    'وردي غامق',
    'وردي',
    'أحمر',
    'برتقالي',
    'برتقالي فاتح',
    'أصفر',
    'عنبري',
    'بني',
    'بني فاتح',
    'رمادي',
    'رمادي مزرق',
    'أسود',
    'ذهبي',
  ];
  Color customSeed = const Color(0xFF2E7D32);
  static const List<double> textScales = [0.9, 1.0, 1.15, 1.3];

  ThemeMode themeMode = ThemeMode.system;
  int seedIndex = 0;
  int cardStyle = 0; // 0 = مضغوطة، 1 = بطاقات كبيرة
  int textSize = 1;
  String lang = 'ar'; // ar | en
  bool syncEnabled = false;
  String serverUrl = '';
  String serverKey = '';
  String reporterName = '';
  DateTime? lastSync;

  Color get seed => seedIndex < 0 ? customSeed : seeds[seedIndex];
  double get textScale => textScales[textSize];

  bool get syncActive =>
      syncEnabled &&
      serverUrl.trim().isNotEmpty &&
      serverKey.trim().isNotEmpty;

  String get baseUrl {
    var u = serverUrl.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (u.isNotEmpty && !u.startsWith('http')) u = 'https://$u';
    return u;
  }

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      themeMode = ThemeMode.values[_ci(p.getInt('set_theme') ?? 0, 0, 2)];
      seedIndex = _ci(p.getInt('set_seed') ?? 0, -1, seeds.length - 1);
      customSeed = Color(p.getInt('set_seed_custom') ?? 0xFF2E7D32);
      cardStyle = _ci(p.getInt('set_cards') ?? 0, 0, 1);
      textSize = _ci(p.getInt('set_text') ?? 1, 0, textScales.length - 1);
      lang = p.getString('set_lang') == 'en' ? 'en' : 'ar';
      syncEnabled = p.getBool('set_sync') ?? false;
      serverUrl = p.getString('set_url') ?? '';
      serverKey = p.getString('set_key') ?? '';
      reporterName = p.getString('reporter_name') ?? '';
      final ls = p.getString('set_last_sync');
      lastSync = ls == null ? null : DateTime.tryParse(ls);
    } catch (_) {}
    if (serverUrl.trim().isEmpty && kDefaultServerUrl.isNotEmpty) {
      serverUrl = kDefaultServerUrl;
      syncEnabled = true;
    }
    if (serverKey.trim().isEmpty && kDefaultServerKey.isNotEmpty) {
      serverKey = kDefaultServerKey;
    }
  }

  Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('set_theme', themeMode.index);
      await p.setInt('set_seed', seedIndex);
      await p.setInt('set_seed_custom', customSeed.toARGB32());
      await p.setInt('set_cards', cardStyle);
      await p.setInt('set_text', textSize);
      await p.setString('set_lang', lang);
      await p.setBool('set_sync', syncEnabled);
      await p.setString('set_url', serverUrl);
      await p.setString('set_key', serverKey);
      await p.setString('reporter_name', reporterName);
      if (lastSync != null) {
        await p.setString('set_last_sync', lastSync!.toIso8601String());
      }
    } catch (_) {}
  }

  void _changed({bool notify = true}) {
    _persist();
    if (notify) notifyListeners();
  }

  void setThemeMode(ThemeMode m) {
    themeMode = m;
    _changed();
  }

  void setSeed(int i) {
    seedIndex = i;
    _changed();
  }

  void setCustomSeed(Color c) {
    customSeed = c;
    seedIndex = -1;
    _changed();
  }

  void setCardStyle(int i) {
    cardStyle = i;
    _changed();
  }

  void setTextSize(int i) {
    textSize = i;
    _changed();
  }

  void setLang(String v) {
    lang = v == 'en' ? 'en' : 'ar';
    _changed();
  }

  void setSyncEnabled(bool v) {
    syncEnabled = v;
    _changed();
  }

  void setServerUrl(String v) {
    final before = syncActive;
    serverUrl = v;
    _changed(notify: before != syncActive);
  }

  void setServerKey(String v) {
    final before = syncActive;
    serverKey = v;
    _changed(notify: before != syncActive);
  }

  void setReporterName(String v) {
    reporterName = v;
    _changed(notify: false);
  }

  void setLastSync(DateTime d) {
    lastSync = d;
    _changed(notify: false);
  }
}

// ═════════════════════════ المزامنة مع السيرفر (Supabase) ═════════════════════════

/// سكربت يتشغّل مرة واحدة في Supabase (SQL Editor) لإنشاء الجدول ومخزن الصور.
const String kSetupSql = r'''
-- Eco Report: one-time setup for Supabase
create table if not exists public.reports (
  id text primary key,
  report_no bigint generated always as identity,
  created_at timestamptz not null default now(),
  location text not null default '',
  type text not null default '',
  responsibility text not null default '',
  severity text not null default 'Medium',
  description text not null default '',
  impacts text[] not null default '{}',
  reporter text not null default '',
  status text not null default 'Open',
  corrective_action text not null default '',
  due_date timestamptz,
  closed_at timestamptz,
  lat double precision,
  lng double precision,
  image_url text,
  closed_image_url text,
  updated_at timestamptz not null default now()
);

alter table public.reports enable row level security;

drop policy if exists "reports_read" on public.reports;
create policy "reports_read" on public.reports
  for select to anon using (true);

drop policy if exists "reports_insert" on public.reports;
create policy "reports_insert" on public.reports
  for insert to anon with check (true);

drop policy if exists "reports_update" on public.reports;
create policy "reports_update" on public.reports
  for update to anon using (true) with check (true);

grant usage on schema public to anon;
grant select, insert, update on public.reports to anon;

insert into storage.buckets (id, name, public)
values ('report-photos', 'report-photos', true)
on conflict (id) do nothing;

drop policy if exists "photos_read" on storage.objects;
create policy "photos_read" on storage.objects
  for select to anon using (bucket_id = 'report-photos');

drop policy if exists "photos_insert" on storage.objects;
create policy "photos_insert" on storage.objects
  for insert to anon with check (bucket_id = 'report-photos');
''';

class SyncException implements Exception {
  final String message;
  SyncException(this.message);
}

class SyncResult {
  final int pushed;
  final int pulled;
  const SyncResult(this.pushed, this.pulled);
}

class SyncService {
  static bool running = false;
  static const Duration _timeout = Duration(seconds: 40);

  static String get _base => AppSettings.instance.baseUrl;

  static Map<String, String> _headers([Map<String, String>? extra]) {
    final key = AppSettings.instance.serverKey.trim();
    final tok = Session.instance.token;
    return {
      'apikey': key,
      if (tok != null)
        'Authorization': 'Bearer $tok'
      else if (key.startsWith('eyJ'))
        'Authorization': 'Bearer $key',
      ...?extra,
    };
  }

  static String _explain(int code, String what) {
    if (code == 401 || code == 403) {
      return trf('مفيش صلاحية في {0}. راجع المفتاح وسكربت الإعداد', [what]);
    }
    if (code == 404) {
      return tr('مش لاقي الجدول أو مخزن الصور. شغّل سكربت الإعداد في Supabase');
    }
    return trf('فشل {0} (كود {1})', [what, code]);
  }

  /// بيرجّع 'ok' لو الاتصال سليم، وغير كده رسالة الخطأ.
  static Future<String> testConnection() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/rest/v1/reports?select=id&limit=1'),
              headers: _headers())
          .timeout(_timeout);
      if (res.statusCode == 200) return 'ok';
      if (res.statusCode == 404) {
        return tr('الاتصال تمام لكن جدول reports مش موجود. شغّل سكربت الإعداد في Supabase');
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        return trf('المفتاح غلط أو مفيش صلاحية ({0})', [res.statusCode]);
      }
      return trf('فشل الاتصال (كود {0})', [res.statusCode]);
    } catch (_) {
      return tr('مقدرناش نوصل للسيرفر. راجع الرابط والإنترنت');
    }
  }

  static Future<SyncResult> sync() async {
    if (running) throw SyncException(tr('المزامنة شغالة بالفعل'));
    running = true;
    try {
      if (!await Session.ensureFresh()) {
        throw SyncException(tr('انتهت الجلسة، سجّل الدخول من جديد'));
      }
      var pushed = 0;
      var pulled = 0;
      final list = await ReportStore.load();

      // 1) إرسال الجديد والمعدّل
      for (final r in list) {
        if (r.remote && !r.dirty) continue;
        await _push(r);
        pushed++;
        await ReportStore.saveAll(list);
      }

      // 2) استلام بلاغات الآخرين وتحديثاتهم
      final rows = await _fetchRows();
      final byId = {for (final r in list) r.id: r};
      for (final row in rows) {
        final id = row['id'] as String;
        final local = byId[id];
        if (local == null) {
          final created = await _fromServer(row);
          if (created != null) {
            list.add(created);
            pulled++;
          }
        } else {
          local.no = (row['factory_no'] as num?)?.toInt() ?? local.no;
          local.factoryId ??= row['factory_id'] as String?;
          final remoteUpdated =
              DateTime.parse(row['updated_at'] as String).toLocal();
          if (!local.dirty && remoteUpdated.isAfter(local.updatedAt)) {
            await _applyServer(local, row);
            pulled++;
          }
        }
      }
      await ReportStore.saveAll(list);
      return SyncResult(pushed, pulled);
    } on SyncException {
      rethrow;
    } catch (_) {
      throw SyncException(tr('مفيش اتصال بالإنترنت أو السيرفر مش بيرد'));
    } finally {
      running = false;
    }
  }

  static Future<String> _upload(String localPath, String name) async {
    final bytes = await File(localPath).readAsBytes();
    final res = await http
        .post(
          Uri.parse('$_base/storage/v1/object/report-photos/$name'),
          headers: _headers({'Content-Type': 'image/jpeg'}),
          body: bytes,
        )
        .timeout(const Duration(seconds: 90));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return '$_base/storage/v1/object/public/report-photos/$name';
    }
    throw SyncException(_explain(res.statusCode, tr('رفع الصورة')));
  }

  static Future<void> _push(Report r) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    if (r.imageUrl == null) {
      r.imageUrl = await _upload(r.imagePath, '${r.id}_before_$stamp.jpg');
    }
    if (r.closedImagePath != null && r.closedImageUrl == null) {
      r.closedImageUrl =
          await _upload(r.closedImagePath!, '${r.id}_after_$stamp.jpg');
    }

    if (!r.remote) {
      final res = await http
          .post(
            Uri.parse('$_base/rest/v1/reports'),
            headers: _headers({
              'Content-Type': 'application/json',
              'Prefer': 'return=representation',
            }),
            body: jsonEncode(r.toServer()),
          )
          .timeout(_timeout);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as List;
        if (data.isNotEmpty) {
          final no = (data.first as Map)['factory_no'];
          if (no is num) r.no = no.toInt();
          final fid = (data.first as Map)['factory_id'];
          if (fid is String) r.factoryId = fid;
        }
        r.remote = true;
        r.dirty = false;
        return;
      }
      if (res.statusCode == 409) {
        // البلاغ موجود أصلاً على السيرفر (محاولة سابقة اتقطعت): نحدّثه.
        r.remote = true;
      } else {
        throw SyncException(_explain(res.statusCode, tr('إرسال البلاغ')));
      }
    }

    final res = await http
        .patch(
          Uri.parse('$_base/rest/v1/reports?id=eq.${r.id}'),
          headers: _headers({
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal',
          }),
          body: jsonEncode(r.toServer()),
        )
        .timeout(_timeout);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      r.dirty = false;
      return;
    }
    throw SyncException(_explain(res.statusCode, tr('تحديث البلاغ')));
  }

  static Future<List<Map<String, dynamic>>> _fetchRows() async {
    final res = await http
        .get(
          Uri.parse('$_base/rest/v1/reports?select=*&order=created_at.desc'),
          headers: _headers(),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw SyncException(_explain(res.statusCode, tr('تحميل البلاغات')));
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)) as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  static Future<String?> _download(String url) async {
    try {
      final res = await http.get(Uri.parse(url)).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final dir = await getApplicationDocumentsDirectory();
      final f = File(
          '${dir.path}/img_${DateTime.now().microsecondsSinceEpoch}.jpg');
      await f.writeAsBytes(res.bodyBytes);
      return f.path;
    } catch (_) {
      return null;
    }
  }

  static void _fill(Report r, Map<String, dynamic> row) {
    r.no = (row['factory_no'] as num?)?.toInt() ?? r.no;
    r.factoryId = row['factory_id'] as String?;
    r.createdAt = DateTime.parse(row['created_at'] as String).toLocal();
    r.location = (row['location'] ?? '') as String;
    r.type = (row['type'] ?? '') as String;
    r.responsibility = (row['responsibility'] ?? '') as String;
    r.severity = (row['severity'] ?? 'Medium') as String;
    r.description = (row['description'] ?? '') as String;
    r.impacts = ((row['impacts'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    r.reporter = (row['reporter'] ?? '') as String;
    r.status = (row['status'] ?? 'Open') as String;
    r.correctiveAction = (row['corrective_action'] ?? '') as String;
    r.dueDate = row['due_date'] == null
        ? null
        : DateTime.parse(row['due_date'] as String).toLocal();
    r.closedAt = row['closed_at'] == null
        ? null
        : DateTime.parse(row['closed_at'] as String).toLocal();
    r.lat = (row['lat'] as num?)?.toDouble();
    r.lng = (row['lng'] as num?)?.toDouble();
    r.updatedAt = DateTime.parse(row['updated_at'] as String).toLocal();
  }

  static Future<Report?> _fromServer(Map<String, dynamic> row) async {
    final imageUrl = row['image_url'] as String?;
    if (imageUrl == null) return null;
    final img = await _download(imageUrl);
    if (img == null) return null;

    String? closedPath;
    final closedUrl = row['closed_image_url'] as String?;
    if (closedUrl != null) closedPath = await _download(closedUrl);

    final r = Report(
      id: row['id'] as String,
      no: 0,
      createdAt: DateTime.now(),
      location: '',
      type: '',
      imagePath: img,
    );
    _fill(r, row);
    r.imageUrl = imageUrl;
    r.closedImagePath = closedPath;
    r.closedImageUrl = closedPath == null ? null : closedUrl;
    r.remote = true;
    r.dirty = false;
    return r;
  }

  static Future<void> _applyServer(
      Report local, Map<String, dynamic> row) async {
    _fill(local, row);
    final closedUrl = row['closed_image_url'] as String?;
    if (closedUrl != null && closedUrl != local.closedImageUrl) {
      final p = await _download(closedUrl);
      if (p != null) {
        local.closedImagePath = p;
        local.closedImageUrl = closedUrl;
      }
    }
  }
}

// ═════════════════════════ التطبيق ═════════════════════════

class EcoReportApp extends StatelessWidget {
  const EcoReportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final s = AppSettings.instance;
        return MaterialApp(
      title: tr('رصد المخلفات'),
      debugShowCheckedModeBanner: false,
      locale: Locale(s.lang),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _buildTheme(s.seed, Brightness.light),
      darkTheme: _buildTheme(s.seed, Brightness.dark),
      themeMode: s.themeMode,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(s.textScale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SplashScreen(),
        );
      },
    );
  }
}

ThemeData _buildTheme(Color seed, Brightness brightness) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
  );
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
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    AppSettings.instance.addListener(_onSettings);
    _load().then((_) => _syncNow());
  }

  @override
  void dispose() {
    AppSettings.instance.removeListener(_onSettings);
    super.dispose();
  }

  void _onSettings() {
    if (mounted) setState(() {});
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
    await _load();
    _syncNow();
  }

  Future<void> _openDetails(Report r) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(report: r)),
    );
    await _load();
    _syncNow();
  }

  Future<void> _syncNow({bool silent = true}) async {
    final s = AppSettings.instance;
    if (!s.syncActive || _syncing || SyncService.running) return;
    setState(() => _syncing = true);
    String msg;
    try {
      final r = await SyncService.sync();
      s.setLastSync(DateTime.now());
      msg = (r.pushed == 0 && r.pulled == 0)
          ? tr('كل حاجة محدّثة ✅')
          : trf('تمت المزامنة ✅  أُرسل {0} • وصل {1}', [r.pushed, r.pulled]);
    } on SyncException catch (e) {
      msg = trf('فشلت المزامنة: {0}', [e.message]);
    } catch (_) {
      msg = tr('فشلت المزامنة، راجع الإنترنت');
    }
    if (!mounted) return;
    setState(() => _syncing = false);
    await _load();
    if (!silent && mounted) snack(context, msg);
  }

  Future<void> _pullToRefresh() async {
    if (AppSettings.instance.syncActive) {
      await _syncNow(silent: false);
    } else {
      await _load();
    }
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
    final title = tr('سجل المخالفات البيئية');
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
                  showSync: AppSettings.instance.syncActive,
                  syncing: _syncing,
                  onSync: () => _syncNow(silent: false),
                  onRefresh: _pullToRefresh,
                ),
                MapTab(reports: _filtered, onOpen: _openDetails),
                SettingsTab(
                  syncing: _syncing,
                  onSyncNow: () => _syncNow(silent: false),
                ),
              ],
            ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: _openNew,
              icon: const Icon(Icons.add_a_photo),
              label: Text(tr('تسجيل مخالفة')),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: tr('السجل'),
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: tr('الخريطة'),
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
              label: tr('نوع المخالفة'),
              icon: Icons.category_outlined,
              kind: 'type',
              value: _type,
              allowAdd: false,
              clearLabel: tr('الكل'),
              onChanged: (v) => setState(() => _type = v),
            ),
            const SizedBox(height: 12),
            PickerField(
              label: tr('المكان'),
              icon: Icons.place_outlined,
              kind: 'location',
              value: _location,
              allowAdd: false,
              clearLabel: tr('الكل'),
              onChanged: (v) => setState(() => _location = v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.pop(context, const FilterResult(null, null)),
                    child: Text(tr('مسح الفلتر')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, FilterResult(_type, _location)),
                    child: Text(tr('تطبيق')),
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
  final bool showSync;
  final bool syncing;
  final VoidCallback onSync;
  final Future<void> Function() onRefresh;

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
    required this.showSync,
    required this.syncing,
    required this.onSync,
    required this.onRefresh,
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.lerp(AppSettings.instance.seed, Colors.black, 0.35)!,
                AppSettings.instance.seed,
              ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.eco, color: Colors.white, size: 30),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('سجل المخالفات البيئية'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (showSync)
                    syncing
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            ),
                          )
                        : IconButton(
                            tooltip: tr('مزامنة مع السيرفر'),
                            onPressed: onSync,
                            icon: const Icon(Icons.cloud_sync,
                                color: Colors.white),
                          ),
                  PopupMenuButton<String>(
                    tooltip: tr('تصدير'),
                    icon: const Icon(Icons.ios_share, color: Colors.white),
                    onSelected: onExport,
                    itemBuilder: (_) => [
                      PopupMenuItem(
                          value: 'pdf', child: Text(tr('تصدير PDF (بالصور)'))),
                      PopupMenuItem(
                          value: 'csv', child: Text(tr('تصدير Excel / CSV'))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Stat(tr('الإجمالي'), all.length),
                  _Stat(tr('مفتوح'), open),
                  _Stat(tr('جاري'), prog),
                  _Stat(tr('مغلق'), closed),
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
                        label: Text(tr('الكل')),
                        selected: status == null,
                        onSelected: (_) => onStatus(null),
                      ),
                    ),
                    for (final s in kStatuses)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(s.text),
                          selected: status == s.en,
                          onSelected: (_) =>
                              onStatus(status == s.en ? null : s.en),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: tr('فلترة'),
                onPressed: onFilter,
                icon: Icon(
                  hasExtraFilter ? Icons.filter_alt : Icons.filter_alt_outlined,
                  color:
                      hasExtraFilter ? Theme.of(context).colorScheme.primary : null,
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
                          ? tr('مفيش بلاغات لسه.\nاضغط "تسجيل مخالفة" وصوّر أي مخلفات في الموقع.')
                          : tr('مفيش بلاغات بالفلتر ده.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: onRefresh,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => AppSettings.instance.cardStyle == 1
                        ? _LargeCard(
                            r: filtered[i],
                            onTap: () => onOpen(filtered[i]),
                          )
                        : _ReportCard(
                            r: filtered[i],
                            onTap: () => onOpen(filtered[i]),
                          ),
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
                          Text(noLabel(r),
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
                        r.description.isEmpty ? tr('بدون وصف') : r.description,
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
                            _Badge(tr('متأخر'), Color(0xFFB71C1C),
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
                          if (AppSettings.instance.syncActive) ...[
                            const SizedBox(width: 6),
                            Icon(
                              r.remote && !r.dirty
                                  ? Icons.cloud_done
                                  : Icons.cloud_upload_outlined,
                              size: 16,
                              color: r.remote && !r.dirty
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ],
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

class _LargeCard extends StatelessWidget {
  final Report r;
  final VoidCallback onTap;
  const _LargeCard({required this.r, required this.onTap});

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(aspectRatio: 16 / 9, child: _Photo(r.imagePath)),
                Positioned(
                  top: 10,
                  right: 10,
                  child: _Badge(
                      arOf(kStatuses, r.status), statusColor(r.status)),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: _Badge(noLabel(r), Colors.black54),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    OptionStore.ar('location', r.location),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _Badge(OptionStore.ar('type', r.type),
                          const Color(0xFF455A64)),
                      if (overdue)
                        _Badge(tr('متأخر'), Color(0xFFB71C1C),
                            icon: Icons.schedule),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    r.description.isEmpty ? tr('بدون وصف') : r.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(fmtDate(r.createdAt),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                      const Spacer(),
                      Icon(Icons.circle,
                          size: 10, color: severityColor(r.severity)),
                      const SizedBox(width: 4),
                      Text(arOf(kSeverities, r.severity),
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 8),
                      Icon(
                        r.hasLocation ? Icons.location_on : Icons.location_off,
                        size: 18,
                        color: r.hasLocation ? Colors.green : Colors.grey,
                      ),
                      if (AppSettings.instance.syncActive) ...[
                        const SizedBox(width: 6),
                        Icon(
                          r.remote && !r.dirty
                              ? Icons.cloud_done
                              : Icons.cloud_upload_outlined,
                          size: 18,
                          color: r.remote && !r.dirty
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ],
                    ],
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

// ═════════════════════════ تبويب الإعدادات ═════════════════════════

class SettingsTab extends StatefulWidget {
  final bool syncing;
  final VoidCallback onSyncNow;
  const SettingsTab({
    super.key,
    required this.syncing,
    required this.onSyncNow,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final AppSettings s = AppSettings.instance;
  late final TextEditingController _url =
      TextEditingController(text: s.serverUrl);
  late final TextEditingController _key =
      TextEditingController(text: s.serverKey);
  late final TextEditingController _name =
      TextEditingController(text: s.reporterName);
  bool _testing = false;
  bool _testOk = false;
  String? _testMsg;

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    if (_url.text.trim().isEmpty || _key.text.trim().isEmpty) {
      setState(() {
        _testOk = false;
        _testMsg = tr('اكتب رابط السيرفر والمفتاح الأول');
      });
      return;
    }
    setState(() {
      _testing = true;
      _testMsg = null;
    });
    final msg = await SyncService.testConnection();
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testOk = msg == 'ok';
      _testMsg = msg == 'ok' ? tr('تم الاتصال بالسيرفر بنجاح ✅') : msg;
    });
  }

  Future<void> _copySql() async {
    await Clipboard.setData(const ClipboardData(text: kSetupSql));
    if (mounted) snack(context, tr('تم نسخ السكربت. الزقه في Supabase ثم Run'));
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 6),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap,
      {IconData? icon}) {
    return ChoiceChip(
      avatar: icon == null ? null : Icon(icon, size: 18),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final last = s.lastSync;
    final lastText = last == null
        ? tr('لسه ماتمتش مزامنة')
        : trf('آخر مزامنة: {0}  {1}:{2}', [fmtDate(last), _two(last.hour), _two(last.minute)]);

    return Scaffold(
      appBar: AppBar(title: Text(tr('الإعدادات'))),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          if (Session.instance.loggedIn)
            _section(tr('حسابي'), Icons.account_circle_outlined, [
              const Center(child: ProfileAvatarEditor()),
              const SizedBox(height: 12),
              Text(
                Session.instance.fullName.isEmpty
                    ? Session.instance.username
                    : Session.instance.fullName,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                Session.instance.isAdmin
                    ? trf('مدير عام • {0}', [Session.instance.username])
                    : trf('مبلّغ • {0}', [FactoryStore.instance.nameOf(Session.instance.factoryId)]),
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => logoutFlow(context),
                icon: const Icon(Icons.logout),
                label: Text(tr('تسجيل الخروج')),
              ),
            ]),
          _section(tr('اللغة'), Icons.language, [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _chip('العربية', s.lang == 'ar', () => s.setLang('ar'),
                    icon: Icons.translate),
                _chip('English', s.lang == 'en', () => s.setLang('en'),
                    icon: Icons.translate),
              ],
            ),
            FutureBuilder<bool>(
              future: Bio.hasSaved(),
              builder: (context, snap) {
                if (snap.data != true) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Bio.forget();
                      if (!context.mounted) return;
                      setState(() {});
                      snack(context, tr('تم مسح بيانات الدخول بالبصمة'));
                    },
                    icon: const Icon(Icons.fingerprint),
                    label: Text(tr('مسح بيانات الدخول بالبصمة')),
                  ),
                );
              },
            ),
          ]),
          _section(tr('المظهر'), Icons.palette_outlined, [
            _label(tr('نمط الألوان')),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _chip(tr('تلقائي'), s.themeMode == ThemeMode.system,
                    () => s.setThemeMode(ThemeMode.system),
                    icon: Icons.brightness_auto),
                _chip(tr('فاتح'), s.themeMode == ThemeMode.light,
                    () => s.setThemeMode(ThemeMode.light),
                    icon: Icons.light_mode),
                _chip(tr('داكن'), s.themeMode == ThemeMode.dark,
                    () => s.setThemeMode(ThemeMode.dark),
                    icon: Icons.dark_mode),
              ],
            ),
            _label(tr('لون التطبيق')),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < AppSettings.seeds.length; i++)
                  Tooltip(
                    message: tr(AppSettings.seedNames[i]),
                    child: GestureDetector(
                      onTap: () => s.setSeed(i),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppSettings.seeds[i],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: s.seedIndex == i
                                ? cs.onSurface
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: s.seedIndex == i
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
                Tooltip(
                  message: tr('لون مخصص'),
                  child: GestureDetector(
                    onTap: () => showCustomColorSheet(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const SweepGradient(colors: [
                          Colors.red, Colors.yellow, Colors.green,
                          Colors.cyan, Colors.blue, Colors.purple, Colors.red
                        ]),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: s.seedIndex < 0
                              ? cs.onSurface
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: Icon(
                          s.seedIndex < 0 ? Icons.check : Icons.colorize,
                          color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            _label(tr('شكل قايمة البلاغات')),
            Wrap(
              spacing: 8,
              children: [
                _chip(tr('مضغوطة'), s.cardStyle == 0, () => s.setCardStyle(0),
                    icon: Icons.view_list),
                _chip(tr('بطاقات كبيرة'), s.cardStyle == 1,
                    () => s.setCardStyle(1),
                    icon: Icons.view_agenda),
              ],
            ),
            _label(tr('حجم الخط')),
            Wrap(
              spacing: 8,
              children: [
                _chip(tr('صغير'), s.textSize == 0, () => s.setTextSize(0)),
                _chip(tr('عادي'), s.textSize == 1, () => s.setTextSize(1)),
                _chip(tr('كبير'), s.textSize == 2, () => s.setTextSize(2)),
                _chip(tr('كبير جداً'), s.textSize == 3, () => s.setTextSize(3)),
              ],
            ),
          ]),
          _section(tr('بياناتي'), Icons.person_outline, [
            TextField(
              controller: _name,
              decoration: deco(tr('اسمي (بيتكتب تلقائي في البلاغات)'),
                  icon: Icons.badge_outlined),
              onChanged: s.setReporterName,
            ),
          ]),
          if (!Session.instance.loggedIn || Session.instance.isAdmin)
          _section(tr('السيرفر والمزامنة'), Icons.cloud_outlined, [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('تفعيل المزامنة مع السيرفر')),
              subtitle: Text(
                  tr('البلاغات بتتبعت للسيرفر وتشوف بلاغات باقي المستخدمين')),
              value: s.syncEnabled,
              onChanged: s.setSyncEnabled,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              textDirection: TextDirection.ltr,
              decoration: deco(tr('رابط السيرفر (Project URL)'),
                  hint: 'https://xxxx.supabase.co', icon: Icons.link),
              onChanged: s.setServerUrl,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _key,
              textDirection: TextDirection.ltr,
              decoration: deco(tr('المفتاح (anon / publishable key)'),
                  icon: Icons.key),
              onChanged: s.setServerKey,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _testing ? null : _test,
                    icon: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.wifi_tethering),
                    label: Text(tr('اختبار الاتصال')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        (s.syncActive && !widget.syncing) ? widget.onSyncNow : null,
                    icon: const Icon(Icons.cloud_sync),
                    label: Text(tr('مزامنة الآن')),
                  ),
                ),
              ],
            ),
            if (_testMsg != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _testMsg!,
                  style: TextStyle(
                    color: _testOk ? Colors.green : cs.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(lastText,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _copySql,
              icon: const Icon(Icons.copy),
              label: Text(tr('نسخ سكربت إعداد قاعدة البيانات')),
            ),
            const SizedBox(height: 8),
            Text(
              tr('ملاحظة: البلاغ اللي اتبعت للسيرفر مبيتمسحش (سجل رسمي)، بس بيتقفل من "تحديث الحالة". رقم البلاغ بيتحدد من السيرفر.'),
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ]),
          _section(tr('عن التطبيق'), Icons.info_outline, [
            Text(tr('رصد المخلفات البيئية')),
            SizedBox(height: 4),
            Text(tr('الإصدار 2.0.0'),
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
          const SizedBox(height: 20),
        ],
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
                      '${noLabel(r)}  ${OptionStore.ar('location', r.location)}',
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
                      r.description.isEmpty ? tr('بدون وصف') : r.description,
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
                child: Text(tr('التفاصيل')),
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
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            tr('مفيش بلاغات عليها موقع لسه.\nلما تسجّل بلاغ والـ GPS شغال هيظهر هنا على الخريطة.'),
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
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 6),
              ],
            ),
            child: Text(
              trf('خريطة البلاغات ({0})  🔴 مفتوح  🟠 جاري  🟢 مغلق', [located.length]),
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
    if (_reporterCtrl.text.isEmpty) {
      _reporterCtrl.text = AppSettings.instance.reporterName;
    }
  }

  Future<void> _getLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw tr('شغّل الـ GPS من إعدادات الموبايل');
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw tr('مفيش صلاحية للوصول للموقع');
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 20));
      if (mounted) setState(() => _position = pos);
    } catch (e) {
      if (mounted) {
        setState(() => _locationError =
            e is String ? e : tr('مقدرناش نحدد الموقع، جرّب تاني'));
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
      snack(context, tr('لازم تضيف صورة للمخالفة'));
      return;
    }
    if (_location == null) {
      snack(context, tr('اختار المكان'));
      return;
    }
    if (_type == null) {
      snack(context, tr('اختار نوع المخالفة'));
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
        updatedAt: now,
      );
      final saved = await ReportStore.add(r);
      if (r.reporter.isNotEmpty) {
        AppSettings.instance.setReporterName(r.reporter);
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(saved.no == 0
              ? tr('تم تسجيل البلاغ ✅')
              : trf('تم تسجيل البلاغ رقم {0} ✅', [saved.no])),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        snack(context, tr('حصل خطأ أثناء الحفظ، جرّب تاني'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('بلاغ جديد'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _choosePhoto,
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withAlpha(110),
                    width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: _photo == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, size: 48, color: Colors.green),
                        SizedBox(height: 8),
                        Text(tr('اضغط لإضافة صورة المخالفة *')),
                      ],
                    )
                  : Image.file(File(_photo!.path),
                      fit: BoxFit.cover, width: double.infinity),
            ),
          ),
          const SizedBox(height: 16),
          FieldBox(
            label: tr('تاريخ الرصد'),
            icon: Icons.event,
            text: fmtDate(_date),
            onTap: _pickDate,
            trailing: const Icon(Icons.edit_calendar),
          ),
          const SizedBox(height: 12),
          PickerField(
            label: tr('المكان *'),
            icon: Icons.place,
            kind: 'location',
            value: _location,
            onChanged: (v) => setState(() => _location = v),
          ),
          const SizedBox(height: 12),
          PickerField(
            label: tr('نوع المخالفة *'),
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
              tr('الوصف'),
              hint: tr('مثال: وجود فلاتر أكياس خارج مخزن المخلفات الخطرة'),
              icon: Icons.notes,
            ),
          ),
          const SizedBox(height: 12),
          PickerField(
            label: tr('الجهة المسؤولة'),
            icon: Icons.engineering,
            kind: 'resp',
            value: _resp,
            clearLabel: tr('بدون تحديد'),
            onChanged: (v) => setState(() => _resp = v),
          ),
          const SizedBox(height: 14),
          Text(tr('درجة الخطورة'),
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final s in kSeverities)
                ChoiceChip(
                  label: Text(s.text),
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
                  ? tr('بنحدد موقعك...')
                  : _position != null
                      ? tr('تم تحديد الموقع (GPS)')
                      : (_locationError ?? tr('الموقع غير محدد'))),
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
              title: Text(tr('تفاصيل إضافية (اختياري)')),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(tr('التأثير البيئي'),
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
                          label: Text(i.text),
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
                  decoration: deco(tr('اسم المبلّغ'), icon: Icons.person),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _actionCtrl,
                  maxLines: 2,
                  decoration: deco(tr('الإجراء التصحيحي المقترح'),
                      icon: Icons.build_circle_outlined),
                ),
                const SizedBox(height: 12),
                FieldBox(
                  label: tr('تاريخ الاستحقاق للمعالجة'),
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
            label: Text(tr('تسجيل البلاغ')),
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
        title: Text(tr('حذف البلاغ؟')),
        content: Text(tr('البلاغ هيتمسح نهائي من الموبايل.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('إلغاء'))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('حذف'))),
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
        title: Text(trf('بلاغ {0}', [noText(r)])),
        actions: [
          // البلاغ اللي اتبعت للسيرفر مبيتمسحش (سجل رسمي)، بس بيتقفل.
          if (!r.remote)
            IconButton(
              tooltip: tr('حذف'),
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
            Text(tr('بعد المعالجة'),
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
              _Badge(trf('خطورة {0}', [arOf(kSeverities, r.severity)]),
                  severityColor(r.severity)),
              if (overdue)
                _Badge(tr('متأخر'), Color(0xFFB71C1C), icon: Icons.schedule),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  _info(Icons.place, tr('المكان'),
                      OptionStore.ar('location', r.location)),
                  _info(Icons.event, tr('تاريخ الرصد'), fmtDate(r.createdAt)),
                  _info(Icons.notes, tr('الوصف'), r.description),
                  _info(
                      Icons.engineering,
                      tr('الجهة المسؤولة'),
                      r.responsibility.isEmpty
                          ? ''
                          : OptionStore.ar('resp', r.responsibility)),
                  _info(Icons.public, tr('التأثير البيئي'),
                      r.impacts.map((e) => arOf(kImpacts, e)).join(' - ')),
                  _info(Icons.person, tr('المبلّغ'), r.reporter),
                  _info(Icons.build_circle_outlined, tr('الإجراء التصحيحي'),
                      r.correctiveAction),
                  _info(Icons.alarm, tr('تاريخ الاستحقاق'),
                      r.dueDate == null ? '' : fmtDate(r.dueDate!)),
                  _info(Icons.verified, tr('تاريخ الإغلاق'),
                      r.closedAt == null ? '' : fmtDate(r.closedAt!)),
                  _info(
                      Icons.my_location,
                      tr('الإحداثيات'),
                      r.hasLocation
                          ? '${r.lat!.toStringAsFixed(5)}, ${r.lng!.toStringAsFixed(5)}'
                          : tr('غير مسجّلة')),
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
            label: Text(tr('تحديث الحالة / الإغلاق')),
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => shareReport(context, r),
            icon: const Icon(Icons.share),
            label: Text(tr('مشاركة (واتساب / إيميل)')),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      exportPdf(context, [r], tr('بلاغ مخالفة بيئية')),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(tr('ملف PDF')),
                ),
              ),
              if (r.hasLocation) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => openInMaps(context, r),
                    icon: const Icon(Icons.map),
                    label: Text(tr('فتح في الخرائط')),
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
      _copy.dirty = true;
      _copy.updatedAt = DateTime.now();
      if (_newPhoto != null) {
        _copy.closedImagePath = await ReportStore.copyImage(_newPhoto!);
        _copy.closedImageUrl = null;
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
        snack(context, tr('حصل خطأ أثناء الحفظ، جرّب تاني'));
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
              Text(tr('تحديث حالة البلاغ'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in kStatuses)
                    ChoiceChip(
                      label: Text(s.text),
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
                decoration: deco(tr('الإجراء التصحيحي اللي اتعمل'),
                    icon: Icons.build_circle_outlined),
              ),
              const SizedBox(height: 12),
              FieldBox(
                label: tr('تاريخ الاستحقاق'),
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
                          ? tr('تغيير صورة بعد المعالجة')
                          : tr('إضافة صورة بعد المعالجة')),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check),
                label: Text(tr('حفظ')),
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


// ===== الصورة الشخصية (محفوظة على الجهاز) =====
class AvatarStore extends ChangeNotifier {
  AvatarStore._();
  static final AvatarStore instance = AvatarStore._();
  Uint8List? _bytes;
  String? _uid;

  Uint8List? get bytes => _bytes;

  Future<void> load() async {
    final uid = Session.instance.userId;
    if (uid == _uid && _bytes != null) return;
    _uid = uid;
    _bytes = null;
    if (uid != null) {
      try {
        final p = await SharedPreferences.getInstance();
        final s = p.getString('avatar_$uid');
        if (s != null) _bytes = base64Decode(s);
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> set(Uint8List? b) async {
    final uid = Session.instance.userId;
    if (uid == null) return;
    final p = await SharedPreferences.getInstance();
    if (b == null) {
      await p.remove('avatar_$uid');
    } else {
      await p.setString('avatar_$uid', base64Encode(b));
    }
    _uid = uid;
    _bytes = b;
    notifyListeners();
  }
}

class UserAvatar extends StatelessWidget {
  final double radius;
  const UserAvatar({super.key, this.radius = 28});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: AvatarStore.instance,
      builder: (_, __) {
        final b = AvatarStore.instance.bytes;
        final name = Session.instance.fullName.isEmpty
            ? Session.instance.username
            : Session.instance.fullName;
        final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
        return CircleAvatar(
          radius: radius,
          backgroundColor: cs.primaryContainer,
          foregroundColor: cs.onPrimaryContainer,
          backgroundImage: b == null ? null : MemoryImage(b),
          child: b == null
              ? Text(initial,
                  style: TextStyle(
                      fontSize: radius * 0.9, fontWeight: FontWeight.bold))
              : null,
        );
      },
    );
  }
}

class ProfileAvatarEditor extends StatefulWidget {
  const ProfileAvatarEditor({super.key});
  @override
  State<ProfileAvatarEditor> createState() => _ProfileAvatarEditorState();
}

class _ProfileAvatarEditorState extends State<ProfileAvatarEditor> {
  @override
  void initState() {
    super.initState();
    AvatarStore.instance.load();
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final f = await ImagePicker()
          .pickImage(source: src, maxWidth: 512, maxHeight: 512, imageQuality: 80);
      if (f == null) return;
      await AvatarStore.instance.set(await f.readAsBytes());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('تعذّر اختيار الصورة'))));
      }
    }
  }

  void _menu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(tr('اختيار من المعرض')),
            onTap: () {
              Navigator.pop(ctx);
              _pick(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(tr('التقاط صورة')),
            onTap: () {
              Navigator.pop(ctx);
              _pick(ImageSource.camera);
            },
          ),
          if (AvatarStore.instance.bytes != null)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(tr('حذف الصورة')),
              onTap: () {
                Navigator.pop(ctx);
                AvatarStore.instance.set(null);
              },
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _menu,
      child: Stack(children: [
        const UserAvatar(radius: 44),
        PositionedDirectional(
          end: 0,
          bottom: 0,
          child: CircleAvatar(
            radius: 14,
            backgroundColor: cs.primary,
            child: Icon(Icons.edit, size: 15, color: cs.onPrimary),
          ),
        ),
      ]),
    );
  }
}

// ===== منتقي لون مخصص =====
void showCustomColorSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _CustomColorSheet(),
  );
}

class _CustomColorSheet extends StatefulWidget {
  const _CustomColorSheet();
  @override
  State<_CustomColorSheet> createState() => _CustomColorSheetState();
}

class _CustomColorSheetState extends State<_CustomColorSheet> {
  late HSVColor hsv;
  @override
  void initState() {
    super.initState();
    final c = AppSettings.instance.seed;
    hsv = HSVColor.fromColor(c);
    if (hsv.saturation < 0.2) hsv = hsv.withSaturation(0.6);
    if (hsv.value < 0.3) hsv = hsv.withValue(0.6);
  }

  void _upd(HSVColor h) {
    setState(() => hsv = h);
    AppSettings.instance.setCustomSeed(h.toColor());
  }

  @override
  Widget build(BuildContext context) {
    final c = hsv.toColor();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Text(tr('لون مخصص'),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Text(tr('درجة اللون')),
          Slider(
              value: hsv.hue,
              min: 0,
              max: 359,
              activeColor: HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
              onChanged: (v) => _upd(hsv.withHue(v))),
          Text(tr('التشبّع')),
          Slider(
              value: hsv.saturation,
              onChanged: (v) => _upd(hsv.withSaturation(v))),
          Text(tr('الإضاءة')),
          Slider(
              value: hsv.value.clamp(0.2, 1.0),
              min: 0.2,
              max: 1,
              onChanged: (v) => _upd(hsv.withValue(v))),
          const SizedBox(height: 8),
          FilledButton(
              onPressed: () => Navigator.pop(context), child: Text(tr('تم'))),
        ]),
      ),
    );
  }
}
