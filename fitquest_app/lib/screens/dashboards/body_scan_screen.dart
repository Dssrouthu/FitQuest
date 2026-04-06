import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../main.dart';
import '../../services/analytics_service.dart';
import '../../services/api_service.dart';

class BodyScanScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String password;

  const BodyScanScreen(
      {super.key, required this.userData, required this.password});

  @override
  State<BodyScanScreen> createState() => _BodyScanScreenState();
}

class _BodyScanScreenState extends State<BodyScanScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<dynamic> _entries = [];
  List<dynamic> _gallery = [];
  bool _loading = true;
  bool _showNew = false;

  String get _username => widget.userData['username'] ?? '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await AnalyticsService.fetchBodyProgress(
          _username, widget.password);
      final gallery = await AnalyticsService.fetchPhotoGallery(
          _username, widget.password);
      setState(() {
        _entries = data;
        _gallery = gallery;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _delete(int id) async {
    try {
      await AnalyticsService.deleteBodyProgress(
          _username, widget.password, id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: FQColors.red));
      }
    }
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: FQColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.delete_outline, color: FQColors.red, size: 20),
          const SizedBox(width: 8),
          Text('DELETE SCAN',
              style: GoogleFonts.rajdhani(
                  color: FQColors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
        ]),
        content: const Text('Delete this scan entry? Cannot be undone.',
            style: TextStyle(color: FQColors.muted, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL',
                style: GoogleFonts.rajdhani(color: FQColors.muted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _delete(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: FQColors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('DELETE',
                style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showNew) {
      return Scaffold(
        backgroundColor: FQColors.bg,
        appBar: AppBar(
          backgroundColor: FQColors.surface,
          foregroundColor: Colors.white,
          title: Text('NEW BODY SCAN',
              style: GoogleFonts.rajdhani(
                  fontWeight: FontWeight.bold, letterSpacing: 2)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _showNew = false),
          ),
        ),
        body: _NewEntryView(
          username: _username,
          password: widget.password,
          onDone: () {
            setState(() => _showNew = false);
            _load();
          },
          onCancel: () => setState(() => _showNew = false),
        ),
      );
    }

    return Scaffold(
      backgroundColor: FQColors.bg,
      appBar: AppBar(
        backgroundColor: FQColors.surface,
        foregroundColor: Colors.white,
        title: Text('BODY SCAN',
            style: GoogleFonts.rajdhani(
                fontWeight: FontWeight.bold, letterSpacing: 2)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: FQColors.gold,
          labelColor: FQColors.gold,
          unselectedLabelColor: FQColors.muted,
          labelStyle: GoogleFonts.rajdhani(
              fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
          tabs: const [
            Tab(text: 'HISTORY'),
            Tab(text: 'GALLERY'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: FQColors.gold,
        foregroundColor: Colors.black,
        onPressed: () => setState(() => _showNew = true),
        child: const Icon(Icons.add_a_photo_outlined),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildHistory(),
          _buildGallery(),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: FQColors.gold));
    }
    if (_entries.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: FQColors.gold.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(color: FQColors.gold.withOpacity(0.2)),
            ),
            child: const Icon(Icons.camera_outlined,
                color: FQColors.gold, size: 40),
          ),
          const SizedBox(height: 20),
          Text('No scans yet',
              style: GoogleFonts.rajdhani(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Tap + to take your first body scan',
              style: TextStyle(color: FQColors.muted, fontSize: 13)),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _entries.length,
      itemBuilder: (_, i) {
        final e = _entries[i] as Map<String, dynamic>;
        final fat = e['body_fat_estimate'];
        final analysis = e['ai_analysis'] as String? ?? '';
        final photoUrl = e['photo_front_url'] as String?;

        return Dismissible(
          key: Key('entry_${e['id']}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: FQColors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_outline, color: FQColors.red),
          ),
          onDismissed: (_) => _delete(e['id']),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: FQColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: FQColors.gold.withOpacity(0.2)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                Row(children: [
                  if (photoUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: photoUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 40,
                          height: 40,
                          color: FQColors.card,
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 40,
                          height: 40,
                          color: FQColors.card,
                          child: const Icon(Icons.image_not_supported,
                              color: FQColors.muted, size: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(e['date'] ?? '',
                      style: GoogleFonts.rajdhani(
                          color: FQColors.muted,
                          fontSize: 12,
                          letterSpacing: 1)),
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  if (fat != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: FQColors.gold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: FQColors.gold.withOpacity(0.3)),
                      ),
                      child: Text(
                          '${(fat as num).toStringAsFixed(1)}% body fat',
                          style: GoogleFonts.rajdhani(
                              color: FQColors.gold,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _confirmDelete(e['id'] as int),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: FQColors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline,
                          color: FQColors.red, size: 16),
                    ),
                  ),
                ]),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 12, children: [
                if (e['weight_kg'] != null)
                  _chip('${e['weight_kg']}kg', Icons.monitor_weight_outlined),
                if (e['waist_cm'] != null)
                  _chip('${e['waist_cm']}cm waist', Icons.straighten),
                if (e['neck_cm'] != null)
                  _chip('${e['neck_cm']}cm neck', Icons.straighten),
                if (e['hips_cm'] != null)
                  _chip('${e['hips_cm']}cm hips', Icons.straighten),
                if (e['chest_cm'] != null)
                  _chip('${e['chest_cm']}cm chest', Icons.straighten),
              ]),
              if (analysis.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(color: FQColors.border),
                const SizedBox(height: 8),
                Text(
                  analysis.length > 200
                      ? '${analysis.substring(0, 200)}...'
                      : analysis,
                  style: const TextStyle(
                      color: FQColors.muted, fontSize: 12, height: 1.5),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }

  Widget _buildGallery() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: FQColors.gold));
    }
    if (_gallery.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.photo_library_outlined,
              color: FQColors.muted, size: 48),
          const SizedBox(height: 16),
          Text('No photos yet',
              style: GoogleFonts.rajdhani(
                  color: FQColors.muted, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Photos appear after body scan with camera',
              style: TextStyle(color: FQColors.muted, fontSize: 12)),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _gallery.length,
      itemBuilder: (_, i) {
        final group = _gallery[i] as Map<String, dynamic>;
        final dateStr = group['date'] as String? ?? '';
        final entries = group['entries'] as List? ?? [];

        return Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(dateStr,
                style: GoogleFonts.rajdhani(
                    color: FQColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
          ),
          for (final entryData in entries)
            ...(entryData['photos'] as List? ?? []).map((photo) {
              final photoMap = photo as Map<String, dynamic>;
              final entryId = entryData['id'] as int?;
              return GestureDetector(
                onTap: () => _viewPhoto(photoMap['url'] as String),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: FQColors.gold.withOpacity(0.2)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(fit: StackFit.expand, children: [
                      CachedNetworkImage(
                        imageUrl: photoMap['url'] as String,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: FQColors.surface),
                        errorWidget: (_, __, ___) => Container(
                          color: FQColors.surface,
                          child: const Icon(Icons.broken_image,
                              color: FQColors.muted),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                              (photoMap['type'] as String? ?? '')
                                  .toUpperCase(),
                              style: const TextStyle(
                                  color: FQColors.gold,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                      if (entryId != null)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: GestureDetector(
                            onTap: () => _confirmDelete(entryId),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.65),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.delete_outline,
                                  color: FQColors.red, size: 14),
                            ),
                          ),
                        ),
                    ]),
                  ),
                ),
              );
            }).toList(),
          const Divider(color: FQColors.border),
        ]);
      },
    );
  }

  void _viewPhoto(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: url,
                placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: FQColors.gold)),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.broken_image, color: FQColors.muted),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: FQColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FQColors.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: FQColors.muted, size: 12),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: FQColors.muted, fontSize: 11)),
      ]),
    );
  }
}

// ── New Entry View ────────────────────────────────────────────────────────────
class _NewEntryView extends StatefulWidget {
  final String username;
  final String password;
  final VoidCallback onDone;
  final VoidCallback onCancel;

  const _NewEntryView({
    required this.username,
    required this.password,
    required this.onDone,
    required this.onCancel,
  });

  @override
  State<_NewEntryView> createState() => _NewEntryViewState();
}

class _NewEntryViewState extends State<_NewEntryView> {
  int _step = 0;
  bool _submitting = false;
  // Per-field unit toggles: false = metric, true = imperial
  final Map<String, bool> _fieldImperial = {
    'weight': false,
    'waist': false,
    'neck': false,
    'hips': false,
    'chest': false,
    'arms': false,
    'thighs': false,
  };

  final _weightCtrl = TextEditingController();
  final _waistCtrl = TextEditingController();
  final _neckCtrl = TextEditingController();
  final _hipsCtrl = TextEditingController();
  final _chestCtrl = TextEditingController();
  final _armsCtrl = TextEditingController();
  final _thighsCtrl = TextEditingController();
  final _manualBfCtrl = TextEditingController();

  File? _frontPhoto;
  File? _sidePhoto;
  File? _backPhoto;

  String? _aiAnalysis;
  double? _bodyFat;
  bool _aiAvailable = false;

  final _picker = ImagePicker();

  @override
  void dispose() {
    _weightCtrl.dispose();
    _waistCtrl.dispose();
    _neckCtrl.dispose();
    _hipsCtrl.dispose();
    _chestCtrl.dispose();
    _armsCtrl.dispose();
    _thighsCtrl.dispose();
    _manualBfCtrl.dispose();
    super.dispose();
  }

  // Convert input values to metric before sending (per-field units)
  double? _toKg(String v, String fieldKey) {
    final d = double.tryParse(v);
    if (d == null) return null;
    return (_fieldImperial[fieldKey] ?? false) ? d * 0.453592 : d; // lbs → kg
  }

  double? _toCm(String v, String fieldKey) {
    final d = double.tryParse(v);
    if (d == null) return null;
    return (_fieldImperial[fieldKey] ?? false) ? d * 2.54 : d; // inches → cm
  }

  Future<void> _pickPhoto(Function(File) onPicked, ImageSource source) async {
    final xf = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 75);
    if (xf != null && mounted) onPicked(File(xf.path));
  }

  Future<void> _submitToServer({bool photosOnly = false}) async {
    setState(() { _submitting = true; _step = 2; });
    try {
      final auth = 'Basic ' +
          base64Encode(utf8.encode('${widget.username}:${widget.password}'));

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/analytics/body-progress/'),
      );
      request.headers['Authorization'] = auth;

      // Convert and add measurements (per-field units)
      final wkg = _toKg(_weightCtrl.text, 'weight');
      if (wkg != null) request.fields['weight_kg'] = wkg.toStringAsFixed(2);
      final waist = _toCm(_waistCtrl.text, 'waist');
      if (waist != null) request.fields['waist_cm'] = waist.toStringAsFixed(1);
      final neck = _toCm(_neckCtrl.text, 'neck');
      if (neck != null) request.fields['neck_cm'] = neck.toStringAsFixed(1);
      final hips = _toCm(_hipsCtrl.text, 'hips');
      if (hips != null) request.fields['hips_cm'] = hips.toStringAsFixed(1);
      final chest = _toCm(_chestCtrl.text, 'chest');
      if (chest != null) request.fields['chest_cm'] = chest.toStringAsFixed(1);
      final arms = _toCm(_armsCtrl.text, 'arms');
      if (arms != null) request.fields['arms_cm'] = arms.toStringAsFixed(1);
      final thighs = _toCm(_thighsCtrl.text, 'thighs');
      if (thighs != null) request.fields['thighs_cm'] = thighs.toStringAsFixed(1);
      if (_manualBfCtrl.text.isNotEmpty)
        request.fields['manual_body_fat'] = _manualBfCtrl.text;

      // Add photos
      if (!photosOnly) {
        if (_frontPhoto != null)
          request.files.add(await http.MultipartFile.fromPath(
              'photo_front', _frontPhoto!.path, filename: 'front.jpg'));
        if (_sidePhoto != null)
          request.files.add(await http.MultipartFile.fromPath(
              'photo_side', _sidePhoto!.path, filename: 'side.jpg'));
        if (_backPhoto != null)
          request.files.add(await http.MultipartFile.fromPath(
              'photo_back', _backPhoto!.path, filename: 'back.jpg'));
      }

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 201) {
        final result = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          _aiAnalysis = result['ai_analysis'] as String? ?? '';
          _aiAvailable = _aiAnalysis!.isNotEmpty;
          _bodyFat = result['body_fat_estimate'] != null
              ? (result['body_fat_estimate'] as num).toDouble()
              : null;
          _submitting = false;
        });
      } else {
        throw Exception('Server error ${resp.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: FQColors.red));
        setState(() { _submitting = false; _step = 1; });
      }
    }
  }

  Future<void> _analyze() => _submitToServer();
  Future<void> _saveMeasurementsOnly() => _submitToServer(photosOnly: true);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_step == 0) _buildMeasurements(),
        if (_step == 1) _buildPhotos(),
        if (_step == 2) _buildAnalysis(),
      ]),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 16),
        child: Text(text,
            style: GoogleFonts.rajdhani(
                color: FQColors.gold,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
      );

  Widget _tf(TextEditingController ctrl, String hint) =>
      TextField(
        controller: ctrl,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: FQColors.muted, fontSize: 13)),
      );

  // Per-field unit toggle: renders TextField + tappable unit badge
  Widget _tfWithUnit(
    TextEditingController ctrl,
    String hintMetric,
    String hintImperial,
    String fieldKey,
    String unitA,   // metric unit label
    String unitB,   // imperial unit label
  ) {
    final isImperial = _fieldImperial[fieldKey] ?? false;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: isImperial ? hintImperial : hintMetric,
              hintStyle: const TextStyle(color: FQColors.muted, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => setState(() => _fieldImperial[fieldKey] = !isImperial),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: FQColors.gold.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: FQColors.gold.withOpacity(0.35)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(unitA,
                  style: TextStyle(
                      color: !isImperial ? FQColors.gold : FQColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
              const Text(' / ',
                  style: TextStyle(color: FQColors.border, fontSize: 11)),
              Text(unitB,
                  style: TextStyle(
                      color: isImperial ? FQColors.gold : FQColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildMeasurements() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FQColors.gold.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FQColors.gold.withOpacity(0.2)),
        ),
        child: const Text(
          'Step 1: Enter your measurements. Tap the unit badge to switch units per field.',
          style: TextStyle(color: FQColors.muted, fontSize: 13),
        ),
      ),
      _label('WEIGHT'),
      _tfWithUnit(_weightCtrl, 'e.g. 75', 'e.g. 165', 'weight', 'kg', 'lbs'),
      _label('WAIST'),
      _tfWithUnit(_waistCtrl, 'e.g. 82', 'e.g. 32', 'waist', 'cm', 'in'),
      _label('NECK'),
      _tfWithUnit(_neckCtrl, 'e.g. 38', 'e.g. 15', 'neck', 'cm', 'in'),
      _label('HIPS (Req. for female BF%)'),
      _tfWithUnit(_hipsCtrl, 'e.g. 95', 'e.g. 38', 'hips', 'cm', 'in'),
      _label('CHEST'),
      _tfWithUnit(_chestCtrl, 'e.g. 100', 'e.g. 40', 'chest', 'cm', 'in'),
      _label('ARMS'),
      _tfWithUnit(_armsCtrl, 'e.g. 33', 'e.g. 13', 'arms', 'cm', 'in'),
      _label('THIGHS'),
      _tfWithUnit(_thighsCtrl, 'e.g. 56', 'e.g. 22', 'thighs', 'cm', 'in'),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () => setState(() => _step = 1),
          style: ElevatedButton.styleFrom(
            backgroundColor: FQColors.gold,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('NEXT: TAKE PHOTOS',
              style: GoogleFonts.rajdhani(
                  fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: _saveMeasurementsOnly,
          child: Text('SAVE MEASUREMENTS ONLY (skip photos)',
              style: GoogleFonts.rajdhani(
                  color: FQColors.muted, fontSize: 13)),
        ),
      ),
    ]);
  }

  Widget _buildPhotos() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FQColors.gold.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FQColors.gold.withOpacity(0.2)),
        ),
        child: const Text(
          'Step 2: Capture or select front, side, and back photos\nfor AI body analysis (optional — skip any)',
          style: TextStyle(color: FQColors.muted, fontSize: 13),
        ),
      ),
      const SizedBox(height: 16),
      _photoSlot('FRONT PHOTO', _frontPhoto,
          onCamera: () => _pickPhoto((f) => setState(() => _frontPhoto = f), ImageSource.camera),
          onGallery: () => _pickPhoto((f) => setState(() => _frontPhoto = f), ImageSource.gallery),
          onRemove: () => setState(() => _frontPhoto = null)),
      const SizedBox(height: 12),
      _photoSlot('SIDE PHOTO', _sidePhoto,
          onCamera: () => _pickPhoto((f) => setState(() => _sidePhoto = f), ImageSource.camera),
          onGallery: () => _pickPhoto((f) => setState(() => _sidePhoto = f), ImageSource.gallery),
          onRemove: () => setState(() => _sidePhoto = null)),
      const SizedBox(height: 12),
      _photoSlot('BACK PHOTO', _backPhoto,
          onCamera: () => _pickPhoto((f) => setState(() => _backPhoto = f), ImageSource.camera),
          onGallery: () => _pickPhoto((f) => setState(() => _backPhoto = f), ImageSource.gallery),
          onRemove: () => setState(() => _backPhoto = null)),
      const SizedBox(height: 24),
      _label('MANUAL BODY FAT % (optional)'),
      _tf(_manualBfCtrl, 'e.g. 18.5 — used if AI unavailable'),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _analyze,
          icon: const Icon(Icons.auto_awesome),
          label: Text('ANALYZE',
              style: GoogleFonts.rajdhani(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 2)),
          style: ElevatedButton.styleFrom(
            backgroundColor: FQColors.gold,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: _saveMeasurementsOnly,
          child: Text('SAVE MEASUREMENTS ONLY (skip photos)',
              style: GoogleFonts.rajdhani(
                  color: FQColors.muted, fontSize: 13)),
        ),
      ),
    ]);
  }

  Widget _photoSlot(String label, File? file,
      {required VoidCallback onCamera,
      required VoidCallback onGallery,
      required VoidCallback onRemove}) {
    return Container(
      decoration: BoxDecoration(
        color: FQColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: file != null
                ? FQColors.gold.withOpacity(0.5)
                : FQColors.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label,
              style: GoogleFonts.rajdhani(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const Spacer(),
          if (file != null)
            GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: FQColors.red.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: FQColors.red, size: 14),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        if (file != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(file,
                height: 100, width: double.infinity, fit: BoxFit.cover),
          )
        else
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: FQColors.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: FQColors.border),
            ),
            child: const Center(
              child: Icon(Icons.camera_alt_outlined,
                  color: FQColors.muted, size: 28),
            ),
          ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onCamera,
              icon: const Icon(Icons.camera_alt, size: 14),
              label: Text(file != null ? '↺ Retake' : 'Camera'),
              style: OutlinedButton.styleFrom(
                foregroundColor: FQColors.gold,
                side: const BorderSide(color: FQColors.border),
                padding: const EdgeInsets.symmetric(vertical: 6),
                textStyle: GoogleFonts.rajdhani(fontSize: 11),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onGallery,
              icon: const Icon(Icons.photo_library_outlined, size: 14),
              label: const Text('Gallery'),
              style: OutlinedButton.styleFrom(
                foregroundColor: FQColors.gold,
                side: const BorderSide(color: FQColors.border),
                padding: const EdgeInsets.symmetric(vertical: 6),
                textStyle: GoogleFonts.rajdhani(fontSize: 11),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildAnalysis() {
    if (_submitting) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Column(children: [
          const CircularProgressIndicator(color: FQColors.gold),
          const SizedBox(height: 24),
          Text('AI is analyzing your physique...',
              style:
                  GoogleFonts.rajdhani(color: FQColors.muted, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('This may take a moment',
              style: TextStyle(color: FQColors.muted, fontSize: 12)),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_bodyFat != null)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: FQColors.gold.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FQColors.gold.withOpacity(0.4)),
          ),
          child: Column(children: [
            Text('ESTIMATED BODY FAT',
                style: GoogleFonts.rajdhani(
                    color: FQColors.muted, fontSize: 11, letterSpacing: 2)),
            const SizedBox(height: 4),
            Text('${_bodyFat!.toStringAsFixed(1)}%',
                style: GoogleFonts.rajdhani(
                    color: FQColors.gold,
                    fontSize: 40,
                    fontWeight: FontWeight.bold)),
            if (!_aiAvailable)
              Text('(manually entered)',
                  style: const TextStyle(
                      color: FQColors.muted, fontSize: 11)),
          ]),
        ),
      const SizedBox(height: 16),
      if (_aiAnalysis != null && _aiAnalysis!.isNotEmpty) ...[
        Text('AI ANALYSIS',
            style: GoogleFonts.rajdhani(
                color: FQColors.gold,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FQColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FQColors.border),
          ),
          child: Text(_aiAnalysis!,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, height: 1.6)),
        ),
      ] else if (_bodyFat == null) ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FQColors.muted.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FQColors.border),
          ),
          child: const Text(
            'AI analysis unavailable (API key not configured or no photos provided). Entry saved with measurements.',
            style: TextStyle(color: FQColors.muted, fontSize: 13, height: 1.5),
          ),
        ),
      ],
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: widget.onDone,
          style: ElevatedButton.styleFrom(
            backgroundColor: FQColors.gold,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('DONE',
              style: GoogleFonts.rajdhani(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 2)),
        ),
      ),
    ]);
  }
}
