import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../main.dart';
import '../../services/analytics_service.dart';
import 'body_scan_screen.dart';
import 'recruit_analytics_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// TRANSFORMATIONS SCREEN — Body progress timeline for recruit (self) or coach view
// ══════════════════════════════════════════════════════════════════════════════
class TransformationsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String password;
  final int? athleteId;           // null = self-view (recruit)
  final String? athleteUsername;  // display name for coach view

  const TransformationsScreen({
    super.key,
    required this.userData,
    required this.password,
    this.athleteId,
    this.athleteUsername,
  });

  @override
  State<TransformationsScreen> createState() => _TransformationsScreenState();
}

class _TransformationsScreenState extends State<TransformationsScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _bodyProgress = [];
  List<dynamic> _setLogs      = [];
  Map<String, dynamic> _muscleVolume = {};

  bool get _isSelfView => widget.athleteId == null;

  String get _username => widget.userData['username'] ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (_isSelfView) {
        final data = await AnalyticsService.fetchMyTransformations(
            _username, widget.password);
        setState(() {
          _bodyProgress  = data['body_progress'] as List? ?? [];
          _setLogs       = data['set_logs'] as List? ?? [];
          _muscleVolume  = data['user_stats']?['muscle_volume'] ?? {};
          _loading       = false;
        });
      } else {
        // For coach view, we might not have muscle volume easily yet
        final results = await Future.wait([
          AnalyticsService.fetchAthleteBodyProgress(
              _username, widget.password, widget.athleteId!),
          AnalyticsService.fetchAthleteSetLogs(
              _username, widget.password, widget.athleteId!),
        ]);
        setState(() {
          _bodyProgress = results[0];
          _setLogs      = results[1];
          _loading      = false;
        });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  double? _deltaWeight() {
    if (_bodyProgress.length < 2) return null;
    final latest = (_bodyProgress.first['weight_kg'] as num?)?.toDouble();
    final oldest = (_bodyProgress.last['weight_kg'] as num?)?.toDouble();
    if (latest == null || oldest == null) return null;
    return latest - oldest;
  }

  double? _deltaBf() {
    if (_bodyProgress.length < 2) return null;
    final latest = (_bodyProgress.first['body_fat_estimate'] as num?)?.toDouble();
    final oldest = (_bodyProgress.last['body_fat_estimate'] as num?)?.toDouble();
    if (latest == null || oldest == null) return null;
    return latest - oldest;
  }

  List<dynamic> _setsForDate(String dateStr) {
    return _setLogs.where((s) => (s['date'] as String? ?? '') == dateStr).toList();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isSelfView
        ? 'TRANSFORMATIONS'
        : '${widget.athleteUsername?.toUpperCase() ?? 'ATHLETE'}\'S TRANSFORMATIONS';

    return Scaffold(
      backgroundColor: FQColors.bg,
      appBar: AppBar(
        backgroundColor: FQColors.surface,
        foregroundColor: Colors.white,
        title: Text(title,
            style: GoogleFonts.rajdhani(
                fontWeight: FontWeight.bold, letterSpacing: 2)),
        actions: [
          if (_isSelfView)
            IconButton(
              icon: const Icon(Icons.bar_chart_outlined, size: 20),
              tooltip: 'Analytics',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => RecruitAnalyticsScreen(
                        userData: widget.userData,
                        password: widget.password)),
              ),
            ),
          IconButton(
              icon: const Icon(Icons.refresh, size: 20), onPressed: _load),
        ],
      ),
      floatingActionButton: _isSelfView
          ? FloatingActionButton(
              backgroundColor: FQColors.cyan,
              foregroundColor: Colors.black,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => BodyScanScreen(
                        userData: widget.userData, password: widget.password)),
              ).then((_) => _load()),
              child: const Icon(Icons.add),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FQColors.cyan))
          : _error != null
              ? _errorState()
              : _bodyProgress.isEmpty && _muscleVolume.isEmpty
                  ? _emptyState()
                  : Column(children: [
                      _summaryStrip(),
                      const Divider(height: 1, color: FQColors.border),
                      if (_isSelfView) _buildAnvilSection(),
                      Expanded(child: _timeline()),
                    ]),
    );
  }

  Widget _buildAnvilSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FQColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FQColors.cyan.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.auto_fix_high, color: FQColors.cyan, size: 18),
          const SizedBox(width: 10),
          Text('THE ANVIL — BIOMETRIC STATS',
              style: GoogleFonts.rajdhani(
                  color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2)),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          height: 200,
          child: RadarChart(
            RadarChartData(
              radarShape: RadarShape.polygon,
              dataSets: [
                RadarDataSet(
                  fillColor: FQColors.cyan.withOpacity(0.2),
                  borderColor: FQColors.cyan,
                  entryRadius: 3,
                  dataEntries: [
                    RadarEntry(value: (_muscleVolume['Chest'] ?? 0).toDouble()),
                    RadarEntry(value: (_muscleVolume['Back'] ?? 0).toDouble()),
                    RadarEntry(value: (_muscleVolume['Legs'] ?? 0).toDouble()),
                    RadarEntry(value: (_muscleVolume['Arms'] ?? 0).toDouble()),
                    RadarEntry(value: (_muscleVolume['Shoulders'] ?? 0).toDouble()),
                    RadarEntry(value: (_muscleVolume['Core'] ?? 0).toDouble()),
                  ],
                ),
              ],
              getTitle: (index, angle) {
                const labels = ['Chest', 'Back', 'Legs', 'Arms', 'Shoulders', 'Core'];
                return RadarChartTitle(text: labels[index], angle: angle);
              },
              radarBorderData: const BorderSide(color: Colors.white10),
              tickBorderData: const BorderSide(color: Colors.white10),
              gridBorderData: const BorderSide(color: Colors.white10, width: 1),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Center(child: Text('Shape generated from your cumulative lifting volume', style: TextStyle(color: FQColors.muted, fontSize: 10))),
      ]),
    );
  }

  Widget _summaryStrip() {
    final deltaW   = _deltaWeight();
    final deltaBf  = _deltaBf();
    final setCount = _setLogs.length;

    return Container(
      color: FQColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _summaryChip(
            icon: Icons.scale_outlined,
            label: 'Δ Weight',
            value: deltaW == null
                ? '--'
                : '${deltaW >= 0 ? '+' : ''}${deltaW.toStringAsFixed(1)}kg',
            color: deltaW == null
                ? FQColors.muted
                : deltaW < 0
                    ? FQColors.green
                    : FQColors.red,
          ),
          const SizedBox(width: 10),
          _summaryChip(
            icon: Icons.percent,
            label: 'Δ Body Fat',
            value: deltaBf == null
                ? '--'
                : '${deltaBf >= 0 ? '+' : ''}${deltaBf.toStringAsFixed(1)}%',
            color: deltaBf == null
                ? FQColors.muted
                : deltaBf < 0
                    ? FQColors.green
                    : FQColors.red,
          ),
          const SizedBox(width: 10),
          _summaryChip(
            icon: Icons.fitness_center,
            label: 'Sets Logged',
            value: '$setCount',
            color: FQColors.cyan,
          ),
          const SizedBox(width: 10),
          _summaryChip(
            icon: Icons.camera_alt_outlined,
            label: 'Scans',
            value: '${_bodyProgress.length}',
            color: FQColors.purple,
          ),
        ]),
      ),
    );
  }

  Widget _summaryChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.rajdhani(
                color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: FQColors.muted, fontSize: 10)),
      ]),
    );
  }

  Widget _timeline() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _bodyProgress.length,
      itemBuilder: (_, i) {
        final entry = _bodyProgress[i] as Map<String, dynamic>;
        // Previous entry (for delta calculation)
        final prevEntry = i + 1 < _bodyProgress.length
            ? _bodyProgress[i + 1] as Map<String, dynamic>
            : null;
        return _timelineCard(entry, prevEntry);
      },
    );
  }

  Widget _timelineCard(
      Map<String, dynamic> entry, Map<String, dynamic>? prevEntry) {
    final dateStr   = entry['date'] as String? ?? '';
    final weightKg  = (entry['weight_kg'] as num?)?.toDouble();
    final waistCm   = (entry['waist_cm'] as num?)?.toDouble();
    final chestCm   = (entry['chest_cm'] as num?)?.toDouble();
    final armsCm    = (entry['arms_cm'] as num?)?.toDouble();
    final thighsCm  = (entry['thighs_cm'] as num?)?.toDouble();
    final bf        = (entry['body_fat_estimate'] as num?)?.toDouble();
    final aiText    = entry['ai_analysis'] as String? ?? '';
    final frontUrl  = entry['photo_front_url'] as String?;
    final sideUrl   = entry['photo_side_url'] as String?;
    final backUrl   = entry['photo_back_url'] as String?;

    // Weight delta vs previous entry
    double? weightDelta;
    if (prevEntry != null && weightKg != null) {
      final prevWeight = (prevEntry['weight_kg'] as num?)?.toDouble();
      if (prevWeight != null) weightDelta = weightKg - prevWeight;
    }

    // Set logs for this date
    final setsForDay = _setsForDate(dateStr);

    return _TimelineEntryCard(
      dateStr: dateStr,
      weightKg: weightKg,
      waistCm: waistCm,
      chestCm: chestCm,
      armsCm: armsCm,
      thighsCm: thighsCm,
      bf: bf,
      aiText: aiText,
      frontUrl: frontUrl,
      sideUrl: sideUrl,
      backUrl: backUrl,
      weightDelta: weightDelta,
      setsForDay: setsForDay,
    );
  }

  Widget _emptyState() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.timeline_outlined,
              size: 64, color: FQColors.muted.withOpacity(0.4)),
          const SizedBox(height: 20),
          Text(
            _isSelfView ? 'No transformations yet' : 'No body scans yet',
            style: GoogleFonts.rajdhani(
                color: FQColors.muted, fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            _isSelfView
                ? 'Start your journey with your first body scan'
                : 'The athlete has not logged any body scans',
            style: const TextStyle(
                color: FQColors.muted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          if (_isSelfView) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => BodyScanScreen(
                        userData: widget.userData, password: widget.password)),
              ).then((_) => _load()),
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text('START BODY SCAN',
                  style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: FQColors.cyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ]),
      );

  Widget _errorState() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 48, color: FQColors.red),
          const SizedBox(height: 12),
          const Text('Failed to load data',
              style: TextStyle(color: FQColors.muted)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(
                backgroundColor: FQColors.cyan, foregroundColor: Colors.black),
            child: const Text('RETRY'),
          ),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// TIMELINE ENTRY CARD
// ══════════════════════════════════════════════════════════════════════════════
class _TimelineEntryCard extends StatefulWidget {
  final String dateStr;
  final double? weightKg, waistCm, chestCm, armsCm, thighsCm, bf, weightDelta;
  final String aiText;
  final String? frontUrl, sideUrl, backUrl;
  final List<dynamic> setsForDay;

  const _TimelineEntryCard({
    required this.dateStr,
    required this.weightKg,
    required this.waistCm,
    required this.chestCm,
    required this.armsCm,
    required this.thighsCm,
    required this.bf,
    required this.aiText,
    required this.frontUrl,
    required this.sideUrl,
    required this.backUrl,
    required this.weightDelta,
    required this.setsForDay,
  });

  @override
  State<_TimelineEntryCard> createState() => _TimelineEntryCardState();
}

class _TimelineEntryCardState extends State<_TimelineEntryCard> {
  bool _aiExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: FQColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FQColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Date header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: FQColors.border))),
          child: Row(children: [
            const Icon(Icons.calendar_today, color: FQColors.gold, size: 14),
            const SizedBox(width: 8),
            Text(widget.dateStr,
                style: GoogleFonts.rajdhani(
                    color: FQColors.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 1)),
            if (widget.weightDelta != null) ...[
              const Spacer(),
              _deltaBadge(widget.weightDelta!),
            ],
          ]),
        ),

        // Photos row
        if (widget.frontUrl != null ||
            widget.sideUrl != null ||
            widget.backUrl != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              _photoThumbnail(widget.frontUrl, 'FRONT', context),
              const SizedBox(width: 8),
              _photoThumbnail(widget.sideUrl, 'SIDE', context),
              const SizedBox(width: 8),
              _photoThumbnail(widget.backUrl, 'BACK', context),
            ]),
          ),

        // Measurements chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            if (widget.weightKg != null)
              _chip('${widget.weightKg!.toStringAsFixed(1)}kg', FQColors.cyan,
                  Icons.scale_outlined),
            if (widget.waistCm != null)
              _chip('Waist: ${widget.waistCm!.toStringAsFixed(0)}cm',
                  FQColors.muted, Icons.straighten),
            if (widget.chestCm != null)
              _chip('Chest: ${widget.chestCm!.toStringAsFixed(0)}cm',
                  FQColors.muted, Icons.straighten),
            if (widget.armsCm != null)
              _chip('Arms: ${widget.armsCm!.toStringAsFixed(0)}cm',
                  FQColors.muted, Icons.straighten),
            if (widget.thighsCm != null)
              _chip('Thighs: ${widget.thighsCm!.toStringAsFixed(0)}cm',
                  FQColors.muted, Icons.straighten),
            if (widget.bf != null)
              _chip('${widget.bf!.toStringAsFixed(1)}% BF', FQColors.purple,
                  Icons.percent),
          ]),
        ),

        // AI Analysis
        if (widget.aiText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.psychology_outlined,
                    color: FQColors.purple, size: 13),
                const SizedBox(width: 6),
                Text('AI ANALYSIS',
                    style: GoogleFonts.rajdhani(
                        color: FQColors.purple,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
              ]),
              const SizedBox(height: 4),
              Text(
                widget.aiText,
                maxLines: _aiExpanded ? null : 2,
                overflow: _aiExpanded ? null : TextOverflow.ellipsis,
                style: const TextStyle(
                    color: FQColors.muted, fontSize: 11, height: 1.5),
              ),
              GestureDetector(
                onTap: () => setState(() => _aiExpanded = !_aiExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    _aiExpanded ? 'COLLAPSE' : 'READ MORE',
                    style: const TextStyle(
                        color: FQColors.purple,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ]),
          ),

        // Sets that day
        if (widget.setsForDay.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.fitness_center,
                    color: FQColors.green, size: 13),
                const SizedBox(width: 6),
                Text('WORKOUTS TODAY',
                    style: GoogleFonts.rajdhani(
                        color: FQColors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
              ]),
              const SizedBox(height: 4),
              ...widget.setsForDay.take(5).map((s) {
                final ex  = s['exercise_name'] ?? '';
                final reps = s['reps'] ?? 0;
                final wkg  = s['weight_kg'];
                final wStr = wkg != null ? ' @ ${wkg}kg' : '';
                return Text('$ex × $reps$wStr',
                    style: const TextStyle(
                        color: FQColors.muted, fontSize: 11));
              }),
              if (widget.setsForDay.length > 5)
                Text('+${widget.setsForDay.length - 5} more sets',
                    style: const TextStyle(
                        color: FQColors.muted, fontSize: 10)),
            ]),
          ),

        const SizedBox(height: 12),
      ]),
    );
  }

  Widget _deltaBadge(double delta) {
    final isLoss = delta < 0;
    final color  = isLoss ? FQColors.green : FQColors.red;
    final sign   = isLoss ? '' : '+';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text('$sign${delta.toStringAsFixed(1)}kg',
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _photoThumbnail(String? url, String label, BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: url != null
            ? () => _viewFullscreen(context, url, label)
            : null,
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            color: FQColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: FQColors.border),
          ),
          child: url != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(url, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              color: FQColors.muted,
                              size: 28)),
                      Positioned(
                        bottom: 4, left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          color: Colors.black.withOpacity(0.6),
                          child: Text(label,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 8)),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.image_not_supported_outlined,
                      color: FQColors.muted, size: 22),
                  const SizedBox(height: 4),
                  Text(label,
                      style: const TextStyle(
                          color: FQColors.muted, fontSize: 9)),
                ]),
        ),
      ),
    );
  }

  void _viewFullscreen(BuildContext context, String url, String label) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain,
                  width: double.infinity, height: double.infinity),
            ),
            Positioned(
              top: 16, right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ]),
      );
}
