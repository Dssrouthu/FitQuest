import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth_gate_screen.dart';
import '../edit_profile_screen.dart';
import '../../services/api_service.dart';
import '../../services/analytics_service.dart';
import '../../main.dart';
import 'quest_screen.dart';
import 'shop_screen.dart';
import 'leaderboard_screen.dart';
import 'war_room_screen.dart';
import 'recruit_workout_screen.dart';
import 'recruit_meal_screen.dart';
import 'water_tracker_screen.dart';
import 'step_counter_screen.dart';
import 'pose_coach_screen.dart';
import 'body_scan_screen.dart';
import 'super_coach_services_screen.dart';
import 'transformations_screen.dart';
import 'tdee_screen.dart';
import 'ai_coach_inbox_screen.dart';
import 'pose_playback_screen.dart';
import '../../services/ai_coach_service.dart';
import 'guild_hub_screen.dart';

class RecruitDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String password;

  const RecruitDashboard(
      {super.key, required this.userData, required this.password});

  @override
  State<RecruitDashboard> createState() => _RecruitDashboardState();
}

class _RecruitDashboardState extends State<RecruitDashboard> {
  late Map<String, dynamic> _userData;

  // Activity data for calendar dots
  Map<String, dynamic> _todayActivity = {};
  int _unreadAICount = 0;

  @override
  void initState() {
    super.initState();
    _userData = Map<String, dynamic>.from(widget.userData);
    _loadActivity();
    _loadAIMessages();
  }

  void _openProfile() async {
    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(
        userData: _userData, password: widget.password)),
    );
    if (updated != null && mounted) {
      setState(() => _userData = updated);
    }
  }

  Future<void> _loadActivity() async {
    try {
      final data = await AnalyticsService.fetchTodayActivity(
          _userData['username'] ?? '', widget.password);
      if (mounted) setState(() => _todayActivity = data);
    } catch (_) {}
  }

  Future<void> _loadAIMessages() async {
    try {
      final msgs = await AICoachService.fetchMessages(
          _userData['username'] ?? '', widget.password);
      if (mounted) {
        setState(() {
          _unreadAICount = msgs.where((m) => m['is_read'] == false).length;
        });
      }
    } catch (_) {}
  }

  void _logout(BuildContext context) async {
    await ApiService.clearSession();
    if (context.mounted) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const AuthGateScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = _userData['username'] ?? 'Athlete';
    final xp       = _userData['xp']    ?? 0;
    final coins    = _userData['coins'] ?? 0;
    final level    = _userData['level'] ?? 1;
    final goal     = _userData['goal']?.toString() ?? 'General Fitness';

    final xpInLevel  = xp % 500;
    final xpProgress = xpInLevel / 500.0;

    return Scaffold(
      backgroundColor: FQColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, username, level, xp, coins, goal, xpProgress, _userData['player_class']),
            // Calendar strip
            _CalendarStrip(
              todayActivity: _todayActivity,
              userData: _userData,
              password: widget.password,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.90,
                  children: [
                    _menuCard(
                      context: context,
                      icon: Icons.military_tech_outlined,
                      title: 'MY QUESTS',
                      subtitle: 'Complete for XP & coins',
                      color: FQColors.purple,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => RecruitQuestScreen(
                                  userData: _userData,
                                  password: widget.password))),
                    ),
                    _menuCard(
                      context: context,
                      icon: Icons.storefront_outlined,
                      title: 'THE SHOP',
                      subtitle: 'Spend your coins',
                      color: FQColors.gold,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => RecruitShopScreen(
                                  userData: _userData,
                                  password: widget.password))),
                    ),
                    _menuCard(
                      context: context,
                      icon: Icons.fitness_center,
                      title: 'MY WORKOUTS',
                      subtitle: 'Your training programs',
                      color: FQColors.cyan,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => RecruitWorkoutScreen(
                                  userData: _userData,
                                  password: widget.password))),
                    ),
                    _menuCard(
                      context: context,
                      icon: Icons.restaurant_outlined,
                      title: 'MY MEALS',
                      subtitle: 'Your nutrition plan',
                      color: FQColors.green,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => RecruitMealScreen(
                                  userData: _userData,
                                  password: widget.password))),
                    ),
                    _menuCard(
                      context: context,
                      icon: Icons.shield_outlined,
                      title: 'GUILD HUB',
                      subtitle: 'Squad Boss Raids',
                      color: FQColors.cyan,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => GuildHubScreen(
                                  userData: _userData,
                                  password: widget.password))),
                    ),
                    _menuCard(
                      context: context,
                      icon: Icons.leaderboard_outlined,
                      title: 'LEADERBOARD',
                      subtitle: 'Team rankings',
                      color: FQColors.cyan,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => LeaderboardScreen(
                                  userData: _userData,
                                  password: widget.password))),
                    ),
                    _menuCard(
                      context: context,
                      icon: Icons.forum_outlined,
                      title: 'THE WAR ROOM',
                      subtitle: 'Chat with your coach',
                      color: FQColors.purple,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => RecruitWarRoomScreen(
                                  userData: _userData,
                                  password: widget.password))),
                    ),
                    _menuCard(
                      context: context,
                      icon: Icons.water_drop_outlined,
                      title: 'WATER TRACKER',
                      subtitle: 'Stay hydrated',
                      color: FQColors.cyan,
                      onTap: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => WaterTrackerScreen(
                                    userData: _userData,
                                    password: widget.password)));
                        _loadActivity();
                      },
                    ),
                    _menuCard(
                      context: context,
                      icon: Icons.directions_walk_outlined,
                      title: 'STEP COUNTER',
                      subtitle: 'Track your movement',
                      color: FQColors.green,
                      onTap: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => StepCounterScreen(
                                    userData: _userData,
                                    password: widget.password)));
                        _loadActivity();
                      },
                    ),
                    _menuCard(
                      context: context,
                      icon: Icons.accessibility_new_outlined,
                      title: 'POSE COACH',
                      subtitle: 'Live form correction',
                      color: FQColors.purple,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PoseCoachScreen())),
                    ),
                    _menuCard(
                      context: context,
                      icon: Icons.camera_outlined,
                      title: 'BODY SCAN',
                      subtitle: 'AI physique analysis',
                      color: FQColors.gold,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => BodyScanScreen(
                                  userData: _userData,
                                  password: widget.password))),
                    ),
                    _menuCard(
                      context: context,
                      icon: Icons.workspace_premium_outlined,
                      title: 'SC SERVICES',
                      subtitle: 'Premium coach services',
                      color: FQColors.gold,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => SuperCoachServicesScreen(
                                  userData: _userData,
                                  password: widget.password))),
                    ),
                    _menuCard(
                      context: context,
                      icon: Icons.insights_outlined,
                      title: 'MY PROGRESS',
                      subtitle: 'Progress timeline & analytics',
                      color: FQColors.green,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => TransformationsScreen(
                                  userData: _userData,
                                  password: widget.password))),
                    ),
                    _menuCard(
                      context: context,
                      icon: Icons.calculate_outlined,
                      title: 'TDEE CALC',
                      subtitle: 'Calories & macros',
                      color: FQColors.gold,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => TDEEScreen(
                                  userData: _userData,
                                  username: _userData['username'] ?? '',
                                  password: widget.password))),
                    ),
                    _menuCard(
                      context: context,
                      icon: Icons.play_circle_outline,
                      title: 'PLAYBACK',
                      subtitle: 'Review latest session',
                      color: FQColors.purple,
                      onTap: () async {
                        try {
                          final logs = await AnalyticsService.fetchMySetLogs(
                              _userData['username'], widget.password);
                          final latestWithVideo = logs.firstWhere(
                              (l) => l['video_url'] != null && l['pose_data'] != null,
                              orElse: () => null);
                          
                          if (latestWithVideo != null && mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PosePlaybackScreen(
                                  videoUrl: latestWithVideo['video_url'],
                                  poseData: jsonDecode(latestWithVideo['pose_data']),
                                ),
                              ),
                            );
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('No recorded sessions found.'))
                              );
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error loading playback: $e'))
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String username, int level, int xp,
      int coins, String goal, double xpProgress, String? playerClass) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: FQColors.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(
            onTap: _openProfile,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FQColors.cyan.withOpacity(0.12),
                border: Border.all(color: FQColors.cyan.withOpacity(0.35)),
              ),
              child: const Icon(Icons.person_outline,
                  color: FQColors.cyan, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ATHLETE HQ',
                  style: GoogleFonts.rajdhani(
                      color: FQColors.muted, fontSize: 11, letterSpacing: 3)),
              Text(username.toUpperCase(),
                  style: GoogleFonts.rajdhani(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
            ]),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: FQColors.gold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: FQColors.gold.withOpacity(0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.monetization_on_outlined,
                  color: FQColors.gold, size: 14),
              const SizedBox(width: 4),
              Text('$coins',
                  style: GoogleFonts.rajdhani(
                      color: FQColors.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ]),
          ),
          IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.auto_awesome_outlined, color: Colors.purpleAccent),
                  if (_unreadAICount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                        child: Text(
                          '$_unreadAICount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AICoachInboxScreen(
                      userData: _userData,
                      password: widget.password,
                    ),
                  ),
                );
                _loadAIMessages();
              }),
          const SizedBox(width: 4),
          IconButton(
              icon: const Icon(Icons.logout, color: FQColors.muted),
              onPressed: () => _logout(context)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: FQColors.gold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star, color: FQColors.gold, size: 12),
              const SizedBox(width: 4),
              Text('LEVEL $level',
                  style: GoogleFonts.rajdhani(
                      color: FQColors.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ]),
          ),
          if (playerClass != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: FQColors.cyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: FQColors.cyan.withOpacity(0.3)),
              ),
              child: Text(playerClass.toUpperCase(),
                  style: GoogleFonts.rajdhani(
                      color: FQColors.cyan,
                      fontWeight: FontWeight.bold,
                      fontSize: 11)),
            ),
          ],
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${xp % 500} / 500 XP',
                  style: const TextStyle(
                      color: FQColors.muted, fontSize: 10)),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: xpProgress,
                  backgroundColor: FQColors.border,
                  color: FQColors.gold,
                  minHeight: 5,
                ),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          goalBadge(goal),
        ]),
      ]),
    );
  }

  Widget _menuCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: FQColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        padding: const EdgeInsets.all(18),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: GoogleFonts.rajdhani(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: FQColors.muted, fontSize: 11)),
                ]),
              ],
            ),
            if (badge != null)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: FQColors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(badge,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Calendar Strip ─────────────────────────────────────────────────────────────
class _CalendarStrip extends StatefulWidget {
  final Map<String, dynamic> todayActivity;
  final Map<String, dynamic> userData;
  final String password;

  const _CalendarStrip({
    required this.todayActivity,
    required this.userData,
    required this.password,
  });

  @override
  State<_CalendarStrip> createState() => _CalendarStripState();
}

class _CalendarStripState extends State<_CalendarStrip> {
  final _scrollController = ScrollController();
  Map<String, dynamic> _monthlySummary = {};
  bool _loadingSummary = false;

  @override
  void initState() {
    super.initState();
    _loadSummary();
    // Auto-scroll to today (last item) after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadSummary() async {
    setState(() => _loadingSummary = true);
    try {
      final now = DateTime.now();
      final data = await AnalyticsService.fetchDailySummary(
          widget.userData['username'], widget.password, now.year, now.month);
      if (mounted) setState(() => _monthlySummary = data);
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingSummary = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showDayDetails(DateTime date) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DayDetailsSheet(
        date: date,
        userData: widget.userData,
        password: widget.password,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(14, (i) => now.subtract(Duration(days: 13 - i)));
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      height: 94,
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: FQColors.border))),
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: days.length,
        itemBuilder: (_, i) {
          final day = days[i];
          final isToday = i == 13;
          final dayLabel = dayLabels[day.weekday - 1];
          final dateStr =
              '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
          final dayData = _monthlySummary[dateStr];
          final allDone = dayData != null && dayData['all_quests_completed'] == true;

          return GestureDetector(
            onTap: () => _showDayDetails(day),
            child: Container(
              width: 52,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: isToday
                    ? FQColors.cyan.withOpacity(0.08)
                    : FQColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isToday
                      ? FQColors.cyan.withOpacity(0.5)
                      : FQColors.border,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(dayLabel,
                          style: TextStyle(
                              color: isToday ? FQColors.cyan : FQColors.muted,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('${day.day}',
                          style: TextStyle(
                              color: isToday ? Colors.white : FQColors.muted,
                              fontSize: 15,
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                      const SizedBox(height: 4),
                      if (allDone)
                        const Icon(Icons.check_circle,
                            color: FQColors.green, size: 14)
                      else
                        const SizedBox(height: 14),
                    ],
                  ),
                  if (isToday)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                            color: FQColors.cyan, shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DayDetailsSheet extends StatefulWidget {
  final DateTime date;
  final Map<String, dynamic> userData;
  final String password;

  const _DayDetailsSheet({
    required this.date,
    required this.userData,
    required this.password,
  });

  @override
  State<_DayDetailsSheet> createState() => _DayDetailsSheetState();
}

class _DayDetailsSheetState extends State<_DayDetailsSheet> {
  List<dynamic> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dateStr =
          '${widget.date.year}-${widget.date.month.toString().padLeft(2, '0')}-${widget.date.day.toString().padLeft(2, '0')}';
      final logs = await AnalyticsService.fetchMySetLogsForDate(
          widget.userData['username'], widget.password, dateStr);
      if (mounted) setState(() { _logs = logs; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${widget.date.day} ${_monthName(widget.date.month)} ${widget.date.year}';

    return Container(
      decoration: const BoxDecoration(
        color: FQColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: FQColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
              color: FQColors.muted.withOpacity(0.35),
              borderRadius: BorderRadius.circular(2)),
        ),
        Text('ACTIVITY HISTORY',
            style: GoogleFonts.rajdhani(
                color: FQColors.muted, fontSize: 11, letterSpacing: 3)),
        Text(dateStr.toUpperCase(),
            style: GoogleFonts.rajdhani(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        if (_loading)
          const Center(child: CircularProgressIndicator(color: FQColors.cyan))
        else if (_logs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(children: [
              Icon(Icons.history, color: FQColors.muted.withOpacity(0.3), size: 48),
              const SizedBox(height: 12),
              const Text('No workout logs found for this day',
                  style: TextStyle(color: FQColors.muted)),
            ]),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _logs.length,
              itemBuilder: (_, i) {
                final log = _logs[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FQColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: FQColors.border),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: FQColors.cyan.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.fitness_center,
                          color: FQColors.cyan, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(log['exercise_name'] ?? 'Exercise',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        Text(
                            'Set ${log['set_number']} · ${log['set_type'] ?? 'Regular'}',
                            style: const TextStyle(
                                color: FQColors.muted, fontSize: 11)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${log['reps']} REPS',
                          style: GoogleFonts.rajdhani(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      if (log['weight_kg'] != null)
                        Text('${log['weight_kg']} KG',
                            style: const TextStyle(
                                color: FQColors.gold,
                                fontWeight: FontWeight.bold,
                                fontSize: 11)),
                    ]),
                  ]),
                );
              },
            ),
          ),
      ]),
    );
  }

  String _monthName(int m) {
    const names = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return names[m];
  }
}
