import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const EcoReportApp());

const List<String> kCategories = [
  'مخلفات منزلية',
  'مخلفات بناء وهدم',
  'حرق مخلفات',
  'صرف / تلوث مياه',
  'مخلفات خطرة / طبية',
  'مخلفات حيوانية',
  'أخرى',
];

class Report {
  final String id;
  final String category;
  final String description;
  final double? lat;
  final double? lng;
  final String imagePath;
  final DateTime createdAt;

  Report({
    required this.id,
    required this.category,
    required this.description,
    required this.imagePath,
    required this.createdAt,
    this.lat,
    this.lng,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'description': description,
        'lat': lat,
        'lng': lng,
        'imagePath': imagePath,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Report.fromJson(Map<String, dynamic> j) => Report(
        id: j['id'] as String,
        category: j['category'] as String,
        description: (j['description'] ?? '') as String,
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        imagePath: j['imagePath'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class ReportStore {
  static const _key = 'reports_v1';

  static Future<List<Report>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List)
        .map((e) => Report.fromJson(e as Map<String, dynamic>))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static Future<void> _save(List<Report> reports) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(reports.map((r) => r.toJson()).toList()));
  }

  static Future<void> add({
    required XFile photo,
    required String category,
    required String description,
    double? lat,
    double? lng,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final dest = '${dir.path}/report_$id.jpg';
    await File(photo.path).copy(dest);

    final reports = await load();
    reports.add(Report(
      id: id,
      category: category,
      description: description,
      imagePath: dest,
      createdAt: DateTime.now(),
      lat: lat,
      lng: lng,
    ));
    await _save(reports);
  }

  static Future<void> delete(Report r) async {
    final reports = await load();
    reports.removeWhere((x) => x.id == r.id);
    await _save(reports);
    final f = File(r.imagePath);
    if (await f.exists()) await f.delete();
  }
}

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
      ),
      home: const HomeScreen(),
    );
  }
}

String fmtDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}/${two(d.month)}/${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Report>> _future = ReportStore.load();

  void _refresh() => setState(() => _future = ReportStore.load());

  Future<void> _openNew() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NewReportScreen()),
    );
    if (saved == true) _refresh();
  }

  Future<void> _openDetails(Report r) async {
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(report: r)),
    );
    if (deleted == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('رصد المخلفات البيئية')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNew,
        icon: const Icon(Icons.add_a_photo),
        label: const Text('تسجيل مخالفة'),
      ),
      body: FutureBuilder<List<Report>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final reports = snap.data ?? [];
          if (reports.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'مفيش بلاغات لسه.\nاضغط "تسجيل مخالفة" وصوّر أي مخلفات في الموقع.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 90, top: 8),
            itemCount: reports.length,
            itemBuilder: (_, i) {
              final r = reports[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(8),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(r.imagePath),
                        width: 64, height: 64, fit: BoxFit.cover),
                  ),
                  title: Text(r.category),
                  subtitle: Text(
                    '${r.description.isEmpty ? 'بدون وصف' : r.description}\n${fmtDate(r.createdAt)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  trailing: r.lat != null
                      ? const Icon(Icons.location_on, color: Colors.green)
                      : const Icon(Icons.location_off, color: Colors.grey),
                  onTap: () => _openDetails(r),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class NewReportScreen extends StatefulWidget {
  const NewReportScreen({super.key});

  @override
  State<NewReportScreen> createState() => _NewReportScreenState();
}

class _NewReportScreenState extends State<NewReportScreen> {
  final _picker = ImagePicker();
  final _descCtrl = TextEditingController();
  XFile? _photo;
  String _category = kCategories.first;
  Position? _position;
  bool _locating = false;
  bool _saving = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
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

  Future<void> _pick(ImageSource source) async {
    final img = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (img != null) setState(() => _photo = img);
  }

  void _showSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('تصوير بالكاميرا'),
            onTap: () {
              Navigator.pop(context);
              _pick(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('اختيار من المعرض'),
            onTap: () {
              Navigator.pop(context);
              _pick(ImageSource.gallery);
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (_photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لازم تضيف صورة للمخالفة الأول')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ReportStore.add(
        photo: _photo!,
        category: _category,
        description: _descCtrl.text.trim(),
        lat: _position?.latitude,
        lng: _position?.longitude,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل البلاغ ✅')),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حصل خطأ أثناء الحفظ، جرّب تاني')),
        );
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
            onTap: _showSourceSheet,
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade400),
              ),
              clipBehavior: Clip.antiAlias,
              child: _photo == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, size: 48),
                        SizedBox(height: 8),
                        Text('اضغط لإضافة صورة المخالفة'),
                      ],
                    )
                  : Image.file(File(_photo!.path),
                      fit: BoxFit.cover, width: double.infinity),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(
              labelText: 'نوع المخالفة',
              border: OutlineInputBorder(),
            ),
            items: kCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'وصف (اختياري)',
              hintText: 'مثال: أكوام زبالة جنب السور من أسبوع',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: _locating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(
                      _position != null ? Icons.location_on : Icons.location_off,
                      color: _position != null ? Colors.green : Colors.red,
                    ),
              title: Text(_locating
                  ? 'بنحدد موقعك...'
                  : _position != null
                      ? 'تم تحديد الموقع'
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
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: const Text('تسجيل البلاغ'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
        ],
      ),
    );
  }
}

class DetailScreen extends StatelessWidget {
  final Report report;
  const DetailScreen({super.key, required this.report});

  Future<void> _confirmDelete(BuildContext context) async {
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
      await ReportStore.delete(report);
      if (context.mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = report;
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل البلاغ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(r.imagePath), fit: BoxFit.cover),
          ),
          const SizedBox(height: 16),
          Text(r.category, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(r.description.isEmpty ? 'بدون وصف' : r.description),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.access_time),
            title: Text(fmtDate(r.createdAt)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.location_on),
            title: Text(r.lat != null
                ? '${r.lat!.toStringAsFixed(5)}, ${r.lng!.toStringAsFixed(5)}'
                : 'الموقع غير مسجّل'),
          ),
        ],
      ),
    );
  }
}
