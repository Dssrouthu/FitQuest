import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../main.dart';
import '../../services/analytics_service.dart';

// ── Exercise definitions ──────────────────────────────────────────────────────
class _Exercise {
  final String id;
  final String name;
  final String muscle;
  final IconData icon;
  final String difficulty;
  final String cameraPlacement;
  final List<String> steps;
  final bool isPlank; // hold timer instead of rep counter
  final int restTime; // default rest in seconds

  const _Exercise(
    this.id, this.name, this.muscle, this.icon, {
    this.difficulty = 'Intermediate',
    this.cameraPlacement = 'Place phone ~2m away, full body visible.',
    this.steps = const [],
    this.isPlank = false,
    this.restTime = 60,
  });
}

const _exercises = [
  _Exercise('squat', 'Squat', 'Legs', Icons.accessibility_new,
      difficulty: 'Beginner',
      cameraPlacement: 'Place phone at hip height, ~2m in front. Full body visible.',
      steps: ['Feet shoulder-width apart', 'Lower until thighs parallel to floor', 'Drive through heels to stand', 'Keep chest up throughout'],
      restTime: 90),
  _Exercise('pushup', 'Push-up', 'Chest', Icons.fitness_center,
      difficulty: 'Beginner',
      cameraPlacement: 'Place phone at shoulder height on the side, ~1.5m away.',
      steps: ['Hands shoulder-width apart', 'Keep body straight (plank position)', 'Lower chest to floor', 'Push back up to full extension'],
      restTime: 60),
  _Exercise('plank', 'Plank', 'Core', Icons.horizontal_rule,
      difficulty: 'Beginner',
      cameraPlacement: 'Place phone at ground level on the side, ~2m away.',
      steps: ['Forearms on ground, elbows under shoulders', 'Body straight from head to heels', 'Engage core and glutes', 'Hold position'],
      isPlank: true,
      restTime: 60),
];

class PoseCoachScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final String? password;

  const PoseCoachScreen({super.key, this.userData, this.password});

  @override
  State<PoseCoachScreen> createState() => _PoseCoachScreenState();
}

class _PoseCoachScreenState extends State<PoseCoachScreen> with TickerProviderStateMixin {
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  List<Pose> _poses = [];
  bool _cameraReady = false;
  bool _isDetecting = false;
  String _hint = 'TAP START to begin';
  _Exercise? _selectedExercise;
  CameraLensDirection _cameraDirection = CameraLensDirection.front;

  // Recording & Pose Data
  bool _isRecording = false;
  final List<Map<String, dynamic>> _recordedPoseData = [];
  DateTime? _recordingStartTime;

  // Rep counter state
  int _repCount = 0;
  bool _inDownPhase = false;
  String _phase = '';
  Set<String> _mistakesInSet = {}; 

  // Audio (Bard's Tavern & Loot Drops)
  final AudioPlayer _ambientPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  bool _isAmbientPlaying = false;

  // Battle Rhythm (Rest Timer)
  bool _isResting = false;
  int _restSecondsRemaining = 0;
  Timer? _restTimer;

  // Voice Runes (Speech to Text)
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _voiceNote = '';

  // Plank hold timer
  int _plankSeconds = 0;
  Timer? _plankTimer;

  // Ghost Duel State
  List<dynamic> _ghostPoseData = [];
  String? _ghostUsername;
  bool _isGhostDuel = false;

  @override
  void initState() {
    super.initState();
    _poseDetector = PoseDetector(options: PoseDetectorOptions());
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetector?.close();
    _ambientPlayer.dispose();
    _sfxPlayer.dispose();
    _restTimer?.cancel();
    _plankTimer?.cancel();
    super.dispose();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == _cameraDirection,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(camera, ResolutionPreset.medium, enableAudio: false);
    await _cameraController!.initialize();
    if (!mounted) return;

    setState(() => _cameraReady = true);

    _cameraController!.startImageStream((image) {
      if (_isDetecting) return;
      _isDetecting = true;
      _processImage(image);
    });
  }

  Future<void> _processImage(CameraImage image) async {
    if (_poseDetector == null) return;
    
    final inputImage = InputImage.fromBytes(
      bytes: image.planes[0].bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation270deg,
        format: InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );

    final poses = await _poseDetector!.processImage(inputImage);
    
    if (mounted) {
      setState(() {
        _poses = poses;
        _isDetecting = false;
      });
    }
  }

  void _playAmbient(bool loop) async {
    // await _ambientPlayer.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);
    setState(() => _isAmbientPlaying = true);
  }

  void _stopAmbient() async {
    await _ambientPlayer.stop();
    setState(() => _isAmbientPlaying = false);
  }

  void _selectExercise(_Exercise ex) async {
    final start = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExerciseTipSheet(exercise: ex),
    );
    if (start != true || !mounted) return;

    final duelId = await _promptGhostDuel();

    setState(() {
      _selectedExercise = ex;
      _repCount = 0;
      _plankSeconds = 0;
      _inDownPhase = false;
      _phase = '';
      _recordedPoseData.clear();
      _mistakesInSet.clear();
      _isResting = false;
      _isGhostDuel = duelId != null;
    });

    if (duelId != null) {
      _loadGhostData(duelId);
    }

    _initCamera();
    _playAmbient(false);
  }

  Future<int?> _promptGhostDuel() async {
    return showDialog<int>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          backgroundColor: FQColors.surface,
          title: Text('GHOST DUEL?', style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Enter a Set ID to duel a Guildmate\'s "Ghost Skeleton".', style: TextStyle(color: FQColors.muted, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: 'Set ID (e.g. 42)', hintStyle: TextStyle(color: Colors.white24)),
              keyboardType: TextInputType.number,
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('SOLO', style: TextStyle(color: FQColors.muted))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)), child: const Text('DUEL!')),
          ],
        );
      }
    );
  }

  void _loadGhostData(int setId) async {
    try {
      final data = await AnalyticsService.fetchGhostDuelData(widget.userData!['username'], widget.password!, setId);
      setState(() {
        _ghostPoseData = jsonDecode(data['pose_data']);
        _ghostUsername = data['username'];
      });
    } catch (e) {
      debugPrint("Ghost load error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedExercise == null) return _buildExerciseSelector();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: FQColors.surface,
        foregroundColor: Colors.white,
        title: Text(_isGhostDuel ? 'DUEL: VS ${_ghostUsername?.toUpperCase()}' : 'POSE COACH', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.music_note, color: _isAmbientPlaying ? FQColors.purple : Colors.white), 
            onPressed: () => _isAmbientPlaying ? _stopAmbient() : _playAmbient(false)
          ),
          IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedExercise = null)),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_cameraReady && _cameraController != null) CameraPreview(_cameraController!),
          
          if (_poses.isNotEmpty && _cameraController != null)
            CustomPaint(
              painter: _PosePainter(
                poses: _poses,
                imageSize: Size(
                  _cameraController!.value.previewSize?.height ?? 1,
                  _cameraController!.value.previewSize?.width ?? 1,
                ),
                screenSize: MediaQuery.of(context).size,
                ghostPoseData: _isRecording && _isGhostDuel ? _ghostPoseData : null,
                currentTimestampMs: _isRecording ? DateTime.now().difference(_recordingStartTime!).inMilliseconds : 0,
              ),
            ),
          
          Positioned(
            bottom: 40, left: 0, right: 0,
            child: Center(
              child: Text(_hint, style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, backgroundColor: Colors.black54)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseSelector() {
    return Scaffold(
      backgroundColor: FQColors.bg,
      appBar: AppBar(title: Text('CHOOSE YOUR BATTLE', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold))),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _exercises.length,
        itemBuilder: (_, i) => ListTile(
          title: Text(_exercises[i].name, style: const TextStyle(color: Colors.white)),
          leading: Icon(_exercises[i].icon, color: FQColors.cyan),
          subtitle: Text(_exercises[i].muscle, style: const TextStyle(color: FQColors.muted)),
          onTap: () => _selectExercise(_exercises[i]),
        ),
      ),
    );
  }
}

class _ExerciseTipSheet extends StatelessWidget {
  final _Exercise exercise;
  const _ExerciseTipSheet({required this.exercise});
  @override
  Widget build(BuildContext context) { 
    return Container(
      height: 400, 
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: FQColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))), 
      child: Column(children: [
        Text(exercise.name.toUpperCase(), style: GoogleFonts.rajdhani(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 10),
        Text(exercise.cameraPlacement, style: const TextStyle(color: FQColors.cyan, fontSize: 13), textAlign: TextAlign.center),
        const Spacer(),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true), 
          style: ElevatedButton.styleFrom(backgroundColor: FQColors.cyan, foregroundColor: Colors.black),
          child: const Text('START SESSION')
        )
      ])
    ); 
  }
}

class _PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final Size screenSize;
  final List<dynamic>? ghostPoseData;
  final int currentTimestampMs;

  _PosePainter({
    required this.poses,
    required this.imageSize,
    required this.screenSize,
    this.ghostPoseData,
    this.currentTimestampMs = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final jointPaint = Paint()..color = FQColors.purple..strokeWidth = 6..style = PaintingStyle.fill;
    final bonePaint = Paint()..color = FQColors.purple.withOpacity(0.7)..strokeWidth = 3..style = PaintingStyle.stroke;

    for (final pose in poses) {
      for (final landmark in pose.landmarks.values) {
        final x = landmark.x / imageSize.width * screenSize.width;
        final y = landmark.y / imageSize.height * screenSize.height;
        canvas.drawCircle(Offset(x, y), 5, jointPaint);
      }

      void drawLine(PoseLandmarkType a, PoseLandmarkType b) {
        final lmA = pose.landmarks[a];
        final lmB = pose.landmarks[b];
        if (lmA == null || lmB == null) return;
        canvas.drawLine(
          Offset(lmA.x / imageSize.width * screenSize.width, lmA.y / imageSize.height * screenSize.height),
          Offset(lmB.x / imageSize.width * screenSize.width, lmB.y / imageSize.height * screenSize.height),
          bonePaint,
        );
      }
      
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
      drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
      drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
      drawLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
      drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
      drawLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
      drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
      drawLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
      drawLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
      drawLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
    }

    if (ghostPoseData != null && ghostPoseData!.isNotEmpty) {
      final ghostJointPaint = Paint()..color = FQColors.cyan.withOpacity(0.5)..strokeWidth = 4;
      final ghostBonePaint = Paint()..color = FQColors.cyan.withOpacity(0.3)..strokeWidth = 2..style = PaintingStyle.stroke;

      var ghostFrame = ghostPoseData!.first;
      for (var f in ghostPoseData!) {
        if (f['t'] <= currentTimestampMs) {
          ghostFrame = f;
        } else {
          break;
        }
      }

      final Map<String, dynamic> landmarks = ghostFrame['p'];
      
      void drawGhostLine(String a, String b) {
        if (landmarks[a] == null || landmarks[b] == null) return;
        final pA = landmarks[a];
        final pB = landmarks[b];
        canvas.drawLine(
          Offset(pA[0] / imageSize.width * screenSize.width, pA[1] / imageSize.height * screenSize.height),
          Offset(pB[0] / imageSize.width * screenSize.width, pB[1] / imageSize.height * screenSize.height),
          ghostBonePaint,
        );
      }

      landmarks.forEach((name, pos) {
        final x = pos[0] / imageSize.width * screenSize.width;
        final y = pos[1] / imageSize.height * screenSize.height;
        canvas.drawCircle(Offset(x, y), 3, ghostJointPaint);
      });

      drawGhostLine('leftShoulder', 'rightShoulder');
      drawGhostLine('leftShoulder', 'leftHip');
      drawGhostLine('rightShoulder', 'rightHip');
      drawGhostLine('leftHip', 'rightHip');
      drawGhostLine('leftShoulder', 'leftElbow');
      drawGhostLine('leftElbow', 'leftWrist');
      drawGhostLine('rightShoulder', 'rightElbow');
      drawGhostLine('rightElbow', 'rightWrist');
      drawGhostLine('leftHip', 'leftKnee');
      drawGhostLine('leftKnee', 'leftAnkle');
      drawGhostLine('rightHip', 'rightKnee');
      drawGhostLine('rightKnee', 'rightAnkle');
    }
  }

  @override
  bool shouldRepaint(covariant _PosePainter oldDelegate) => true;
}
