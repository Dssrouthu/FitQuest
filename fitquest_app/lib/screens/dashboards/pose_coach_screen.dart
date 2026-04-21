import 'dart:convert';
import 'dart:async';
import 'dart:math';
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
  _Exercise('lunge', 'Lunge', 'Legs', Icons.directions_walk,
      difficulty: 'Intermediate',
      cameraPlacement: 'Place phone at hip height on the side, ~2m away.',
      steps: ['Step forward with one leg', 'Lower hips until both knees are bent at 90 degrees', 'Push back up to starting position', 'Keep front knee over ankle'],
      restTime: 60),
  _Exercise('jumping_jacks', 'Jumping Jacks', 'Full Body', Icons.bolt,
      difficulty: 'Beginner',
      cameraPlacement: 'Place phone ~3m away, full body visible.',
      steps: ['Start with feet together, arms at sides', 'Jump legs out and swing arms overhead', 'Jump back to starting position', 'Maintain a steady rhythm'],
      restTime: 45),
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
  final Set<String> _mistakesInSet = {}; 

  // Audio (Bard's Tavern & Loot Drops)
  final AudioPlayer _ambientPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  bool _isAmbientPlaying = false;

  // Voice Runes (Speech to Text)
  final stt.SpeechToText _speech = stt.SpeechToText();
  String _voiceNote = '';

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

  void _toggleCamera() {
    setState(() {
      _cameraDirection = (_cameraDirection == CameraLensDirection.front)
          ? CameraLensDirection.back
          : CameraLensDirection.front;
      _cameraReady = false;
    });
    _initCamera();
  }

  double _getAngle(PoseLandmark first, PoseLandmark mid, PoseLandmark last) {
    double radians = atan2(last.y - mid.y, last.x - mid.x) -
                     atan2(first.y - mid.y, first.x - mid.x);
    double angle = (radians * 180.0 / pi).abs();
    if (angle > 180.0) angle = 360.0 - angle;
    return angle;
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordingStartTime = DateTime.now();
      _recordedPoseData.clear();
      _repCount = 0;
      _mistakesInSet.clear();
      _hint = 'RECORDING... GO!';
      _voiceNote = '';
    });
    _startListening();
  }

  void _stopRecording() {
    _stopListening();
    setState(() {
      _isRecording = false;
      _hint = 'SESSION COMPLETE';
    });
    _saveSetLog();
  }

  void _startListening() async {
    try {
      bool available = await _speech.initialize();
      if (available) {
        _speech.listen(onResult: (val) {
          if (mounted) setState(() => _voiceNote = val.recognizedWords);
        });
      }
    } catch (e) {
      debugPrint("STT error: $e");
    }
  }

  void _stopListening() {
    _speech.stop();
  }

  Future<void> _saveSetLog() async {
    if (widget.userData == null) return;
    try {
      await AnalyticsService.logWorkoutSet(
        widget.userData!['username'],
        widget.password!,
        _selectedExercise!.name,
        'Pose Coach Session',
        _repCount,
        weightKg: 0,
        poseData: jsonEncode(_recordedPoseData),
        mistakes: _mistakesInSet.join(', '),
        voiceNote: _voiceNote,
        xpMultiplier: _calculateXPMultiplier(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Battle Logged! XP Awarded.')),
        );
      }
    } catch (e) {
      debugPrint("Save log error: $e");
    }
  }

  double _calculateXPMultiplier() {
    // Battle Rhythm implementation: closer to 2-1-2 tempo = higher multiplier
    // For now, base 1.2 if any reps done, 1.0 otherwise.
    return _repCount > 0 ? 1.2 : 1.0;
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

      if (_isRecording && poses.isNotEmpty) {
        final pose = poses.first;
        final ex = _selectedExercise!.id;
        final landmarks = pose.landmarks;

        // Record pose data for ghost duel
        Map<String, dynamic> frame = {};
        landmarks.forEach((type, landmark) {
          frame[type.name] = [landmark.x, landmark.y];
        });
        _recordedPoseData.add({
          't': DateTime.now().difference(_recordingStartTime!).inMilliseconds,
          'p': frame
        });

        // ── Rep Counting Logic ──
        try {
          if (ex == 'squat') {
            final leftKnee = _getAngle(landmarks[PoseLandmarkType.leftHip]!, landmarks[PoseLandmarkType.leftKnee]!, landmarks[PoseLandmarkType.leftAnkle]!);
            final rightKnee = _getAngle(landmarks[PoseLandmarkType.rightHip]!, landmarks[PoseLandmarkType.rightKnee]!, landmarks[PoseLandmarkType.rightAnkle]!);
            double avgKnee = (leftKnee + rightKnee) / 2;

            if (avgKnee < 90) { // Down phase
              if (!_inDownPhase) {
                _inDownPhase = true;
                _phase = 'down';
                _hint = 'HOLD...';
              }
            } else if (avgKnee > 160) { // Up phase
              if (_inDownPhase) {
                _repCount++;
                _inDownPhase = false;
                _phase = 'up';
                _hint = 'REP $_repCount!';
                _sfxPlayer.play(AssetSource('audio/loot_drop.mp3'));
              }
            }
          } 
          else if (ex == 'pushup') {
            final leftElbow = _getAngle(landmarks[PoseLandmarkType.leftShoulder]!, landmarks[PoseLandmarkType.leftElbow]!, landmarks[PoseLandmarkType.leftWrist]!);
            final rightElbow = _getAngle(landmarks[PoseLandmarkType.rightShoulder]!, landmarks[PoseLandmarkType.rightElbow]!, landmarks[PoseLandmarkType.rightWrist]!);
            double avgElbow = (leftElbow + rightElbow) / 2;

            if (avgElbow < 80) {
              if (!_inDownPhase) { _inDownPhase = true; _phase = 'down'; _hint = 'PUSH!'; }
            } else if (avgElbow > 150) {
              if (_inDownPhase) {
                _repCount++; _inDownPhase = false; _phase = 'up'; _hint = 'REP $_repCount!';
                _sfxPlayer.play(AssetSource('audio/loot_drop.mp3'));
              }
            }
          }
          else if (ex == 'lunge') {
            final leftKnee = _getAngle(landmarks[PoseLandmarkType.leftHip]!, landmarks[PoseLandmarkType.leftKnee]!, landmarks[PoseLandmarkType.leftAnkle]!);
            final rightKnee = _getAngle(landmarks[PoseLandmarkType.rightHip]!, landmarks[PoseLandmarkType.rightKnee]!, landmarks[PoseLandmarkType.rightAnkle]!);
            
            if (leftKnee < 100 || rightKnee < 100) {
              if (!_inDownPhase) { _inDownPhase = true; _phase = 'down'; }
            } else if (leftKnee > 150 && rightKnee > 150) {
              if (_inDownPhase) {
                _repCount++; _inDownPhase = false; _phase = 'up'; _hint = 'REP $_repCount!';
                _sfxPlayer.play(AssetSource('audio/loot_drop.mp3'));
              }
            }
          }
          else if (ex == 'jumping_jacks') {
            final leftShoulder = _getAngle(landmarks[PoseLandmarkType.leftHip]!, landmarks[PoseLandmarkType.leftShoulder]!, landmarks[PoseLandmarkType.leftElbow]!);
            final rightShoulder = _getAngle(landmarks[PoseLandmarkType.rightHip]!, landmarks[PoseLandmarkType.rightShoulder]!, landmarks[PoseLandmarkType.rightElbow]!);
            
            if (leftShoulder > 140 && rightShoulder > 140) {
              if (!_inDownPhase) { _inDownPhase = true; _phase = 'up'; }
            } else if (leftShoulder < 40 && rightShoulder < 40) {
              if (_inDownPhase) {
                _repCount++; _inDownPhase = false; _phase = 'down'; _hint = 'REP $_repCount!';
                _sfxPlayer.play(AssetSource('audio/loot_drop.mp3'));
              }
            }
          }
        } catch (e) {
          // Landmarks missing in frame
        }
      }
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
      _inDownPhase = false;
      _phase = '';
      _recordedPoseData.clear();
      _mistakesInSet.clear();
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
            icon: Icon(Icons.switch_camera, color: Colors.white),
            onPressed: _toggleCamera,
          ),
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

          // Battle Rhythm Visualizer (Pulse)
          if (_isRecording)
            Positioned(
              top: 100, right: 20,
              child: _BattleRhythmIndicator(phase: _phase),
            ),
          
          Positioned(
            bottom: 40, left: 0, right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_hint, style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, backgroundColor: Colors.black54)),
                const SizedBox(height: 20),
                if (_cameraReady)
                  GestureDetector(
                    onTap: _isRecording ? _stopRecording : _startRecording,
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        color: _isRecording ? Colors.red.withOpacity(0.5) : Colors.transparent,
                      ),
                      child: Center(
                        child: Container(
                          width: _isRecording ? 30 : 60, height: _isRecording ? 30 : 60,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(_isRecording ? 5 : 30),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if (_voiceNote.isNotEmpty)
            Positioned(
              top: 60, left: 20, right: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.black54,
                child: Text('Voice Rune: "$_voiceNote"', style: const TextStyle(color: FQColors.gold, fontSize: 12, fontStyle: FontStyle.italic)),
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

class _BattleRhythmIndicator extends StatefulWidget {
  final String phase;
  const _BattleRhythmIndicator({required this.phase});
  @override
  State<_BattleRhythmIndicator> createState() => _BattleRhythmIndicatorState();
}

class _BattleRhythmIndicatorState extends State<_BattleRhythmIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    Color color = widget.phase == 'down' ? FQColors.cyan : FQColors.purple;
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.2).animate(_controller),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 3),
          boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10)],
        ),
        child: Text(widget.phase.toUpperCase(), style: GoogleFonts.rajdhani(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }
}
